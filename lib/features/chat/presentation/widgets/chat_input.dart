import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/networking/p2p_provider.dart';
import '../../../room/providers/room_provider.dart';

const _uuid = Uuid();

/// Chat input widget with message field, emoji picker, and send button.
///
/// Features:
/// - 500 character limit with counter
/// - Emoji picker integration
/// - Send on Enter key
/// - Disabled state during sending
class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  bool _wasTyping = false;
  static const int _maxLength = 500;
  int _lastCharCount = 0; // Track char count for optimized setState - PERF FIX 3.2

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Clear typing status when disposing
    _setTypingStatus(false);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Only call setState when UI actually needs updating - PERF FIX 3.2
    final currentLength = _controller.text.length;
    final isEmpty = currentLength == 0;
    final wasEmpty = _lastCharCount == 0;

    // Check if character counter color would change (thresholds: 50, 0)
    final needsCounterUpdate =
        (_lastCharCount >= 50 && currentLength < 50) ||
        (_lastCharCount < 50 && currentLength >= 50) ||
        (_lastCharCount > 0 && currentLength <= 0) ||
        (_lastCharCount <= 0 && currentLength > 0) ||
        (_lastCharCount <= _maxLength && currentLength > _maxLength) ||
        (_lastCharCount > _maxLength && currentLength <= _maxLength);

    // Check if send button state would change (empty <-> non-empty)
    final needsButtonUpdate = isEmpty != wasEmpty;

    _lastCharCount = currentLength;

    // Only setState when UI elements need updating
    if (needsCounterUpdate || needsButtonUpdate) {
      setState(() {});
    }

    // Update typing status
    final isTyping = !isEmpty;
    if (isTyping != _wasTyping) {
      _wasTyping = isTyping;
      _setTypingStatus(isTyping);
    }
  }

  void _setTypingStatus(bool isTyping) {
    final peerId = ref.read(currentPeerIdProvider);
    ref.read(roomProvider.notifier).setTyping(peerId, isTyping);
    ref.read(p2pProvider.notifier).sendTypingIndicator(isTyping);
  }

  bool get _canSend {
    final text = _controller.text.trim();
    return text.isNotEmpty && text.length <= _maxLength && !_isSending;
  }

  int get _remainingChars => _maxLength - _controller.text.length;

  Future<void> _sendMessage() async {
    if (!_canSend) return;

    final content = _controller.text.trim();

    setState(() {
      _isSending = true;
    });

    // Get current user info from providers
    final peerId = ref.read(currentPeerIdProvider);
    final displayName = ref.read(currentDisplayNameProvider);
    final messageId = _uuid.v4();

    // Add message to the local messages provider
    ref.read(messagesProvider.notifier).addMessage(
      senderPeerId: peerId,
      senderDisplayName: displayName,
      content: content,
    );

    // Send message via P2P to other participants
    ref.read(p2pProvider.notifier).sendChatMessage(
      messageId: messageId,
      content: content,
    );

    _controller.clear();

    // Clear typing status since message was sent
    _wasTyping = false;
    _setTypingStatus(false);

    setState(() {
      _isSending = false;
    });

    _focusNode.requestFocus();
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _EmojiPickerSheet(
        onEmojiSelected: (emoji) {
          _insertEmoji(emoji);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final text = _controller.text;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity( 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Character counter using ValueListenableBuilder for efficient updates - PERF FIX 3.2
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                final remaining = _maxLength - value.text.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    '$remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: remaining < 50
                              ? (remaining < 0
                                  ? AppColors.error
                                  : AppColors.warning)
                              : AppColors.textSecondary,
                        ),
                  ),
                );
              },
            ),

            // Input row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji picker button
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: _showEmojiPicker,
                  color: AppColors.textSecondary,
                  tooltip: 'Emoji',
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: _maxLength,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null, // Hide default counter
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _canSend ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    onPressed: _canSend ? _sendMessage : null,
                    color: _canSend
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Emoji picker bottom sheet with categorized emojis and search functionality.
class _EmojiPickerSheet extends StatefulWidget {
  final void Function(String emoji) onEmojiSelected;

  const _EmojiPickerSheet({required this.onEmojiSelected});

  @override
  State<_EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<_EmojiPickerSheet> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;

  static const _emojiCategories = {
    'Recent': [
      '😀', '👍', '❤️', '🔥', '😂', '😍', '🎉', '💯',
    ],
    'Smileys': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '😊',
      '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😋', '😛', '😜',
      '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐',
      '😑', '😶', '🫥', '😏', '😒', '🙄', '😬', '😮‍💨', '🤥', '😌',
      '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧',
      '🥵', '🥶', '🥴', '😵', '😵‍💫', '🤯', '🤠', '🥳', '🥸', '😎',
    ],
    'Gestures': [
      '👍', '👎', '👊', '✊', '🤛', '🤜', '👏', '🙌', '👐', '🤲',
      '🤝', '🙏', '✌️', '🤞', '🤟', '🤘', '👌', '🤌', '🤏', '👈',
      '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤙',
      '💪', '🦾', '🖕', '✍️', '🤳', '💅', '🦵', '🦶', '👂', '🦻',
      '👃', '👀', '👁️', '👅', '👄', '💋', '🫦', '🦷', '🦴', '🫀',
    ],
    'Hearts': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❤️‍🔥', '❤️‍🩹', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
      '💟', '♥️', '🫶', '💑', '💏', '👩‍❤️‍👨', '👨‍❤️‍👨', '👩‍❤️‍👩', '💌', '💐',
    ],
    'Objects': [
      '🔥', '✨', '⭐', '🌟', '💫', '🎉', '🎊', '🎈', '🎁', '🏆',
      '🥇', '🥈', '🥉', '🎯', '🎮', '🎲', '🎪', '🎭', '🎨', '🎬',
      '🎤', '🎧', '🎵', '🎶', '🎸', '🎹', '🎺', '🥁', '🎻', '🎷',
      '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💽', '💾', '💿', '📀',
      '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️', '📟', '📠',
    ],
    'Faces': [
      '😢', '😭', '😤', '😠', '😡', '🤬', '😈', '👿', '💀', '☠️',
      '😱', '😨', '😰', '😥', '😓', '🤥', '😶', '😑', '😬', '🙄',
      '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵',
      '🤐', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳',
      '🥵', '🥶', '😶‍🌫️', '😱', '😨', '😰', '😥', '😢', '😭', '😱',
    ],
    'Animals': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐻‍❄️', '🐨',
      '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
      '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
      '🐺', '🐗', '🐴', '🦄', '🐝', '🪱', '🐛', '🦋', '🐌', '🐞',
    ],
    'Food': [
      '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐', '🍈',
      '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦',
      '🌭', '🍔', '🍟', '🍕', '🌮', '🌯', '🥙', '🧆', '🥚', '🍳',
      '🥘', '🍲', '🥣', '🥗', '🍿', '🧈', '🧂', '🥫', '🍱', '🍘',
    ],
    'Nature': [
      '🌸', '💮', '🏵️', '🌹', '🥀', '🌺', '🌻', '🌼', '🌷', '🌱',
      '🪴', '🌲', '🌳', '🌴', '🌵', '🌾', '🌿', '☘️', '🍀', '🍁',
      '🍂', '🍃', '🪺', '🪹', '🍄', '🌰', '🦀', '🦞', '🦐', '🦑',
      '🌍', '🌎', '🌏', '🌐', '🪐', '💫', '⭐', '🌟', '✨', '⚡',
    ],
    'Symbols': [
      '💯', '💢', '💥', '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️',
      '🗨️', '🗯️', '💭', '💤', '🔴', '🟠', '🟡', '🟢', '🔵', '🟣',
      '⚫', '⚪', '🟤', '🔶', '🔷', '🔸', '🔹', '🔺', '🔻', '💠',
      '✅', '❌', '❓', '❗', '💲', '⚠️', '🚫', '♻️', '✔️', '➕',
    ],
  };

  static const _categoryIcons = {
    'Recent': Icons.access_time,
    'Smileys': Icons.emoji_emotions,
    'Gestures': Icons.waving_hand,
    'Hearts': Icons.favorite,
    'Objects': Icons.category,
    'Faces': Icons.face,
    'Animals': Icons.pets,
    'Food': Icons.restaurant,
    'Nature': Icons.nature,
    'Symbols': Icons.tag,
  };

  // Cached set of all emojis for search - avoids iterating all categories on every build - PERF FIX 1.4
  static final Set<String> _allEmojisCache = _emojiCategories.values
      .expand((emojis) => emojis)
      .toSet();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, List<String>>> get _filteredCategories {
    if (_searchQuery.isEmpty) {
      return _emojiCategories.entries.toList();
    }

    // When searching, show all matching emojis in a single "Results" category
    final matchingEmojis = <String>[];
    for (final category in _emojiCategories.values) {
      for (final emoji in category) {
        if (!matchingEmojis.contains(emoji)) {
          matchingEmojis.add(emoji);
        }
      }
    }

    if (matchingEmojis.isEmpty) {
      return [];
    }

    return [MapEntry('Search Results', matchingEmojis)];
  }

  @override
  Widget build(BuildContext context) {
    final categories = _emojiCategories.keys.toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 450),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity( 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search emoji...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Category tabs (only show when not searching)
          if (_searchQuery.isEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = index == _selectedCategoryIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity( 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 1)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _categoryIcons[category] ?? Icons.emoji_emotions,
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Emoji grid
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildCategoryEmojis(categories[_selectedCategoryIndex])
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryEmojis(String category) {
    final emojis = _emojiCategories[category] ?? [];
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return _buildEmojiButton(emojis[index]);
      },
    );
  }

  Widget _buildSearchResults() {
    // Use cached set instead of creating new one on every build - PERF FIX 1.4
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: _allEmojisCache.length,
      itemBuilder: (context, index) {
        return _buildEmojiButton(_allEmojisCache.elementAt(index));
      },
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return InkWell(
      onTap: () => widget.onEmojiSelected(emoji),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
