# Performance Analysis Report

**Date:** 2026-01-20
**Codebase:** ShadowWhisper - P2P Ephemeral Chat Application

---

## Executive Summary

This analysis identifies **18 performance issues** across the codebase, categorized by severity and impact. The most critical issues involve unnecessary widget re-renders, inefficient list operations in state management, and unoptimized message handling that could degrade performance with increased message volume.

---

## Critical Issues (High Impact)

### 1. Full List Recreation on State Updates
**Location:** `lib/features/room/providers/room_provider.dart:417-422, 440-448, 472-481, 555-560`

**Problem:** Every participant update creates a new list via `.map(...).toList()`, causing O(n) memory allocation even for single-field updates.

```dart
// Current implementation - creates new list for every participant
final updatedParticipants = state!.participants.map((p) {
  if (p.peerId == peerId) {
    return p.copyWith(isTyping: isTyping);
  }
  return p;
}).toList();
```

**Impact:** With max 20 participants, every typing indicator update allocates a new 20-element list.

**Recommendation:** Use immutable list libraries (e.g., `built_collection`) or implement targeted updates with index-based modification.

---

### 2. N+1-like Pattern in Timeout Checking
**Location:** `lib/features/room/providers/room_provider.dart:494-528`

**Problem:** `checkAndRemoveTimedOutParticipants()` iterates all participants, then for each timed-out one calls `markMessagesAsRemoved()` which iterates ALL messages.

```dart
// O(p) iteration over participants
for (final participant in state!.participants) {
  if (participant.hasTimedOut) { ... }
}

// Then O(m) for each timed out participant
for (int i = 0; i < timedOutPeerIds.length; i++) {
  _ref.read(messagesProvider.notifier).markMessagesAsRemoved(timedOutPeerIds[i]);
  // ^^^ This iterates ALL messages
}
```

**Impact:** O(p × m) complexity where p = participants, m = messages. Degrades as chat history grows.

**Recommendation:** Batch the operations or maintain an index of messages by sender for O(1) lookups.

---

### 3. Message Operations Recreate Entire List
**Location:** `lib/features/room/providers/room_provider.dart:816-851`

**Problem:** `markMessagesAsRemoved()`, `addReaction()`, and `markAsSeen()` all create new lists by mapping over ALL messages.

```dart
// addReaction - maps ALL messages to update ONE
state = state.map((m) {
  if (m.messageId == messageId) {
    return m.copyWith(reactions: updatedReactions);
  }
  return m;
}).toList();
```

**Impact:** Every reaction/seen update is O(m) instead of O(1).

**Recommendation:**
- Use a Map<String, ChatMessage> keyed by messageId for O(1) lookups
- Consider using `List.of()` with spread for single insertions

---

### 4. Timer Causing Frequent State Reads
**Location:** `lib/features/chat/presentation/chat_screen.dart:56-68`

**Problem:** 1-second timer reads room state every tick regardless of whether any participants are disconnected.

```dart
_timeoutCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  _checkTimedOutParticipants();
});

void _checkTimedOutParticipants() {
  // Reads state EVERY second
  final removedPeerIds = ref.read(roomProvider.notifier).checkAndRemoveTimedOutParticipants();
}
```

**Impact:** Unnecessary CPU cycles when no participants are in disconnected state.

**Recommendation:** Only start timer when participants disconnect; stop when none remain disconnected.

---

## High Priority Issues (Medium-High Impact)

### 5. Overly Broad Provider Watching
**Location:** `lib/features/chat/presentation/widgets/typing_indicator.dart:15-16`

**Problem:** Watches entire `participantsProvider` when only typing status is needed.

```dart
final participants = ref.watch(participantsProvider);  // Rebuilds on ANY participant change
final currentPeerId = ref.watch(currentPeerIdProvider);
```

**Impact:** Widget rebuilds when participants join/leave/change names, not just typing status.

**Recommendation:** Create a selective provider:
```dart
final typingParticipantsProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider);
  final currentPeerId = ref.watch(currentPeerIdProvider);
  return participants.where((p) => p.isTyping && p.peerId != currentPeerId).toList();
});
```

---

### 6. Regex Compilation in Build Method
**Location:** `lib/features/chat/presentation/widgets/message_list.dart:161-165`

**Problem:** `_isEmojiOnly` getter compiles a new RegExp on every access.

```dart
bool get _isEmojiOnly {
  final emojiRegex = RegExp(  // Compiled on EVERY call
    r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\s]+$',
    unicode: true,
  );
  return emojiRegex.hasMatch(message.content);
}
```

**Impact:** Regex compilation is expensive; called for every message bubble on every rebuild.

**Recommendation:** Make the RegExp a static const:
```dart
static final _emojiRegex = RegExp(
  r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\s]+$',
  unicode: true,
);
```

---

### 7. Message Filtering on Every Build
**Location:** `lib/features/chat/presentation/widgets/message_list.dart:61, 94-115`

**Problem:** `_collapseConsecutiveRemovedMessages()` runs on every build even when messages haven't changed.

```dart
@override
Widget build(BuildContext context) {
  final messages = ref.watch(messagesProvider);
  // ...
  final filteredMessages = _collapseConsecutiveRemovedMessages(messages);  // Every build!
}
```

**Impact:** O(m) filtering operation on every rebuild.

**Recommendation:** Memoize the filtered result or move to a derived provider:
```dart
final filteredMessagesProvider = Provider<List<ChatMessage>>((ref) {
  final messages = ref.watch(messagesProvider);
  return _collapseConsecutiveRemovedMessages(messages);
});
```

---

### 8. O(n) Participant Lookups
**Location:** `lib/features/room/providers/room_provider.dart:342, 432, 464, 548, 633, 667, 715`

**Problem:** Multiple `firstWhere` and `indexWhere` calls for participant lookups.

```dart
final participant = state!.participants.firstWhere(
  (p) => p.peerId == peerId,
  orElse: () => throw Exception('Participant not found'),
);
```

**Impact:** O(n) for each lookup. With frequent typing indicator updates, this adds up.

**Recommendation:** Maintain a `Map<String, Participant>` alongside the list, or use a Map as the primary data structure.

---

## Medium Priority Issues

### 9. setState on Every Keystroke
**Location:** `lib/features/chat/presentation/widgets/chat_input.dart:47-49`

**Problem:** `_onTextChanged` calls `setState` on every text change.

```dart
void _onTextChanged() {
  setState(() {});  // Full rebuild on every keystroke
  // ...
}
```

**Impact:** Rebuilds entire ChatInput widget on every keystroke.

**Recommendation:** Only call setState when specific UI elements need updating (e.g., character counter crossing thresholds).

---

### 10. Emoji Picker Category Iteration
**Location:** `lib/features/chat/presentation/widgets/chat_input.dart:356-376, 531-548`

**Problem:** `_filteredCategories` getter and `_buildSearchResults()` iterate all emoji categories on every access.

```dart
List<MapEntry<String, List<String>>> get _filteredCategories {
  // Creates new list on every access
  for (final category in _emojiCategories.values) {
    for (final emoji in category) { ... }
  }
}
```

**Impact:** ~400 emojis iterated on every rebuild during search.

**Recommendation:** Cache the flattened emoji list as a static field.

---

### 11. No Typing Indicator Debouncing
**Location:** `lib/core/networking/p2p_manager.dart:141-150`

**Problem:** Typing indicators are sent immediately without debouncing.

```dart
void sendTypingIndicator(bool isTyping) {
  if (_localPeerId == null) return;
  final message = P2PMessage.typing(...);
  _broadcast(message);  // Sent immediately to ALL peers
}
```

**Impact:** Every keystroke sends N WebRTC messages (N = peer count).

**Recommendation:** Debounce typing indicators (e.g., 300ms) and batch stop indicators.

---

### 12. Disconnected Countdown Computed Multiple Times
**Location:** `lib/features/chat/presentation/widgets/participant_drawer.dart:264, 381`

**Problem:** `participant.timeoutRemainingSeconds` computes elapsed time on every access.

```dart
final remainingSeconds = participant.timeoutRemainingSeconds;  // Computed here
// ...
'Disconnected - will be removed in ${remainingSeconds}s'  // Used again
```

**Impact:** DateTime computation on every widget build.

**Recommendation:** Cache the value in a local variable (already partially done, but getter is still computed).

---

## Lower Priority Issues

### 13. Broadcast Without Batching
**Location:** `lib/core/networking/p2p_manager.dart:387-390`

**Problem:** `_broadcast()` loops synchronously through all peers.

```dart
void _broadcast(P2PMessage message) {
  for (final peer in _peers.values) {
    peer.sendMessage(message);
  }
}
```

**Recommendation:** Consider using `Future.wait()` for parallel sends if order doesn't matter.

---

### 14. Object Allocation in Build Methods
**Location:** Various widget files

**Problem:** `BoxDecoration`, `EdgeInsets`, `TextStyle` objects created in build methods.

**Recommendation:** Use `const` constructors where possible; extract repeated decorations to static fields.

---

### 15. Derived Provider Creates New List
**Location:** `lib/features/room/providers/room_provider.dart:105-108`

**Problem:** `disconnectedParticipantsProvider` filters and creates new list on every access.

```dart
final disconnectedParticipantsProvider = Provider<List<Participant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.where((p) => p.isDisconnected).toList();  // New list every time
});
```

**Recommendation:** This is actually fine for Riverpod (it handles equality), but could use `select` for finer granularity.

---

### 16. Missing Message Index by Sender
**Location:** `lib/features/room/providers/room_provider.dart`

**Problem:** No indexed data structure for looking up messages by sender.

**Impact:** `markMessagesAsRemoved(peerId)` must scan all messages.

**Recommendation:** Maintain a `Map<String, Set<String>>` mapping peerId to messageIds.

---

### 17. Stream Controllers Lifecycle
**Location:** `lib/core/networking/p2p_manager.dart:23-24`

**Problem:** Broadcast stream controllers may accumulate listeners if not properly managed.

```dart
final _messageController = StreamController<P2PMessage>.broadcast();
final _connectionStateController = StreamController<P2PConnectionEvent>.broadcast();
```

**Recommendation:** Ensure `dispose()` is always called; consider using `StreamController.broadcast(sync: true)` for synchronous delivery.

---

### 18. firstWhere with orElse Exception
**Location:** `lib/features/room/providers/room_provider.dart:342-345, 548-551`

**Problem:** Using exceptions for control flow.

```dart
final participant = state!.participants.firstWhere(
  (p) => p.peerId == peerId,
  orElse: () => throw Exception('Participant not found'),
);
```

**Recommendation:** Use `firstWhereOrNull` extension or check existence first.

---

## Recommendations Summary

### Quick Wins (Low effort, High impact)
1. Make emoji regex a static const
2. Create `typingParticipantsProvider` for selective rebuilds
3. Debounce typing indicators (300ms)
4. Cache filtered messages in a provider

### Medium Effort Improvements
1. Use Map<String, Participant> for O(1) lookups
2. Use Map<String, ChatMessage> for message operations
3. Conditional timer for timeout checking
4. Memoize expensive computations in build methods

### Architecture Improvements (Higher effort)
1. Consider `freezed` + `built_collection` for immutable collections
2. Implement message indexing by sender
3. Add WebRTC message batching layer
4. Use Riverpod `select` for fine-grained subscriptions

---

## Performance Metrics to Monitor

1. **Widget rebuild count** - Use `debugPrintRebuildDirtyWidgets`
2. **Frame rendering time** - Should be <16ms for 60fps
3. **Memory allocation** - Profile with DevTools
4. **Message throughput** - Messages/second with N participants
5. **Typing latency** - Time from keystroke to indicator display on peers

---

## Conclusion

The codebase has a solid architecture but contains several performance anti-patterns common in Flutter/Riverpod applications. The most impactful improvements would be:

1. **Selective provider watching** - Reduce unnecessary rebuilds
2. **Indexed data structures** - O(1) vs O(n) lookups
3. **Debouncing** - Reduce network traffic and state updates
4. **Memoization** - Cache expensive computations

These optimizations would significantly improve performance, especially as room participant count and message volume increase.
