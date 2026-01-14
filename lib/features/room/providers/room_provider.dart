import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/room.dart';
import '../domain/participant.dart';
import '../domain/chat_message.dart';
import '../domain/room_notification.dart';

const _uuid = Uuid();

/// Result of attempting to join a room
enum JoinResult {
  success,
  reconnected, // Successful reconnection within grace period
  pending, // In approval mode, waiting for creator approval
  kicked,
  roomFull,
  notFound,
}

/// Generates a random anonymous name for a participant
String _generateAnonymousName() {
  const adjectives = [
    'Anonymous', 'Silent', 'Shadow', 'Phantom', 'Mystic',
    'Hidden', 'Veiled', 'Masked', 'Secret', 'Covert',
    'Stealth', 'Ghostly', 'Twilight', 'Midnight', 'Obscure',
  ];
  const animals = [
    'Fox', 'Wolf', 'Owl', 'Raven', 'Panther',
    'Hawk', 'Bear', 'Tiger', 'Falcon', 'Serpent',
    'Lynx', 'Jaguar', 'Eagle', 'Viper', 'Phoenix',
  ];
  final random = DateTime.now().millisecondsSinceEpoch;
  final adjective = adjectives[random % adjectives.length];
  final animal = animals[(random ~/ 17) % animals.length];
  return '$adjective $animal';
}

/// Generates a unique peer ID
String _generatePeerId() {
  return _uuid.v4();
}

/// Current user's peer ID provider
final currentPeerIdProvider = StateProvider<String>((ref) {
  return _generatePeerId();
});

/// Current user's display name provider
final currentDisplayNameProvider = StateProvider<String>((ref) {
  return _generateAnonymousName();
});

/// Room state notifier provider
final roomProvider = StateNotifierProvider<RoomNotifier, Room?>((ref) {
  return RoomNotifier(ref);
});

/// Chat messages provider
final messagesProvider = StateNotifierProvider<MessagesNotifier, List<ChatMessage>>((ref) {
  return MessagesNotifier();
});

/// Room notifications provider
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<RoomNotification>>((ref) {
  return NotificationsNotifier();
});

/// Disconnected sessions provider - tracks sessions that can be reclaimed
final disconnectedSessionsProvider = StateNotifierProvider<DisconnectedSessionsNotifier, List<DisconnectedSession>>((ref) {
  return DisconnectedSessionsNotifier();
});

/// Whether current user is the room creator
final isCreatorProvider = Provider<bool>((ref) {
  final room = ref.watch(roomProvider);
  final currentPeerId = ref.watch(currentPeerIdProvider);
  return room?.creatorPeerId == currentPeerId;
});

/// List of participants in the room
final participantsProvider = Provider<List<Participant>>((ref) {
  final room = ref.watch(roomProvider);
  return room?.participants ?? [];
});

/// Participant count
final participantCountProvider = Provider<int>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.length;
});

/// Pending join requests
final pendingJoinRequestsProvider = Provider<List<JoinRequest>>((ref) {
  final room = ref.watch(roomProvider);
  return room?.pendingJoinRequests ?? [];
});

/// Pending request count
final pendingRequestCountProvider = Provider<int>((ref) {
  final requests = ref.watch(pendingJoinRequestsProvider);
  return requests.length;
});

/// Room state notifier
class RoomNotifier extends StateNotifier<Room?> {
  final Ref _ref;

  RoomNotifier(this._ref) : super(null);

  /// Create a new room
  void createRoom({
    required String roomName,
    required String roomCode,
    required bool approvalMode,
  }) {
    final peerId = _ref.read(currentPeerIdProvider);
    final displayName = _ref.read(currentDisplayNameProvider);

    final creator = Participant(
      peerId: peerId,
      displayName: displayName,
      joinedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isCreator: true,
      isOnline: true,
    );

    state = Room(
      swarmId: _uuid.v4(),
      roomName: roomName,
      roomCode: roomCode,
      approvalMode: approvalMode,
      creatorPeerId: peerId,
      participants: [creator],
      kickedPeerIds: [],
      createdAt: DateTime.now(),
    );
  }

  /// Join an existing room
  /// Returns a JoinResult indicating success or the reason for failure
  JoinResult joinRoom({
    required String roomCode,
    required String roomName,
  }) {
    // First, check if there's a valid disconnected session for this room code
    final disconnectedSession = _ref.read(disconnectedSessionsProvider.notifier).findValidSession(roomCode);

    if (disconnectedSession != null && disconnectedSession.isWithinGracePeriod) {
      // Restore the previous session
      return _reconnectWithSession(disconnectedSession, roomName);
    }

    final peerId = _ref.read(currentPeerIdProvider);
    final displayName = _ref.read(currentDisplayNameProvider);

    // Check if user was kicked from this room
    if (state != null && state!.isKicked(peerId)) {
      return JoinResult.kicked;
    }

    // Check if room is full
    if (state != null && state!.isFull) {
      return JoinResult.roomFull;
    }

    // Check if approval mode is enabled
    if (state != null && state!.approvalMode) {
      // Add to pending requests instead of joining directly
      final joinRequest = JoinRequest(
        peerId: peerId,
        displayName: displayName,
        requestedAt: DateTime.now(),
      );

      state = state!.copyWith(
        pendingJoinRequests: [...state!.pendingJoinRequests, joinRequest],
      );

      // Notify creator about new request
      _ref.read(notificationsProvider.notifier).addNotification(
        type: RoomNotificationType.joinRequestReceived,
        message: '$displayName is requesting to join',
        peerId: peerId,
      );

      return JoinResult.pending;
    }

    final participant = Participant(
      peerId: peerId,
      displayName: displayName,
      joinedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isCreator: false,
      isOnline: true,
    );

    if (state == null) {
      // Create room state for joining (in real P2P, this would sync from network)
      state = Room(
        swarmId: _uuid.v4(),
        roomName: roomName,
        roomCode: roomCode,
        approvalMode: false,
        creatorPeerId: '', // Would be synced from network
        participants: [participant],
        kickedPeerIds: [],
        createdAt: DateTime.now(),
      );
    } else {
      // Add participant to existing room
      state = state!.copyWith(
        participants: [...state!.participants, participant],
      );
    }

    // Add join notification
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantJoined,
      message: '$displayName joined the room',
      peerId: peerId,
    );

    return JoinResult.success;
  }

  /// Reconnect using a saved disconnected session
  JoinResult _reconnectWithSession(DisconnectedSession session, String roomName) {
    // Restore the previous peer ID and display name
    _ref.read(currentPeerIdProvider.notifier).state = session.peerId;
    _ref.read(currentDisplayNameProvider.notifier).state = session.displayName;

    // Check if user was kicked from this room (double check with restored peerId)
    if (state != null && state!.isKicked(session.peerId)) {
      // Remove the session since they're kicked
      _ref.read(disconnectedSessionsProvider.notifier).removeSession(session.peerId);
      return JoinResult.kicked;
    }

    // Check if room is full
    if (state != null && state!.isFull) {
      return JoinResult.roomFull;
    }

    final participant = Participant(
      peerId: session.peerId,
      displayName: session.displayName,
      joinedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isCreator: session.wasCreator,
      isOnline: true,
    );

    if (state == null) {
      // Create room state for reconnection (in real P2P, this would sync from network)
      state = Room(
        swarmId: _uuid.v4(),
        roomName: roomName,
        roomCode: session.roomCode,
        approvalMode: false,
        creatorPeerId: session.wasCreator ? session.peerId : '',
        participants: [participant],
        kickedPeerIds: [],
        createdAt: DateTime.now(),
      );
    } else {
      // Restore creatorPeerId if reconnecting as creator
      final updatedCreatorPeerId = session.wasCreator ? session.peerId : state!.creatorPeerId;

      // Add participant to existing room
      state = state!.copyWith(
        participants: [...state!.participants, participant],
        creatorPeerId: updatedCreatorPeerId,
      );
    }

    // Remove the session from disconnected list
    _ref.read(disconnectedSessionsProvider.notifier).removeSession(session.peerId);

    // Add reconnection notification
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantJoined,
      message: '${session.displayName} reconnected',
      peerId: session.peerId,
    );

    return JoinResult.reconnected;
  }

  /// Add a simulated participant (for testing)
  /// Returns false if room is full
  bool addSimulatedParticipant(String displayName) {
    if (state == null) return false;

    // Check if room is full
    if (state!.isFull) return false;

    final participant = Participant(
      peerId: _uuid.v4(),
      displayName: displayName,
      joinedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isCreator: false,
      isOnline: true,
    );

    state = state!.copyWith(
      participants: [...state!.participants, participant],
    );

    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantJoined,
      message: '$displayName joined the room',
      peerId: participant.peerId,
    );

    return true;
  }

  /// Kick a participant (creator only)
  bool kickParticipant(String peerId) {
    if (state == null) return false;

    final currentPeerId = _ref.read(currentPeerIdProvider);

    // Only creator can kick
    if (state!.creatorPeerId != currentPeerId) return false;

    // Cannot kick self
    if (peerId == currentPeerId) return false;

    // Find the participant to get their name
    final participant = state!.participants.firstWhere(
      (p) => p.peerId == peerId,
      orElse: () => throw Exception('Participant not found'),
    );

    // Remove participant and add to kicked list
    final updatedParticipants = state!.participants
        .where((p) => p.peerId != peerId)
        .toList();

    state = state!.copyWith(
      participants: updatedParticipants,
      kickedPeerIds: [...state!.kickedPeerIds, peerId],
    );

    // Add kick notification
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantKicked,
      message: '${participant.displayName} was removed',
      peerId: peerId,
    );

    // Mark all messages from kicked user as removed
    _ref.read(messagesProvider.notifier).markMessagesAsRemoved(peerId);

    return true;
  }

  /// Leave the room
  /// Set saveSession to true to allow reconnection within grace period
  void leaveRoom({bool saveSession = true}) {
    if (state == null) return;

    final currentPeerId = _ref.read(currentPeerIdProvider);
    final displayName = _ref.read(currentDisplayNameProvider);
    final wasCreator = state!.creatorPeerId == currentPeerId;
    final roomCode = state!.roomCode;

    // Save session for potential reconnection (if not kicked)
    if (saveSession && !state!.isKicked(currentPeerId)) {
      _ref.read(disconnectedSessionsProvider.notifier).addSession(
        peerId: currentPeerId,
        displayName: displayName,
        roomCode: roomCode,
        wasCreator: wasCreator,
      );
    }

    // Mark messages as removed
    _ref.read(messagesProvider.notifier).markMessagesAsRemoved(currentPeerId);

    // Add leave notification
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantLeft,
      message: '$displayName left the room',
      peerId: currentPeerId,
    );

    // Remove participant
    final updatedParticipants = state!.participants
        .where((p) => p.peerId != currentPeerId)
        .toList();

    if (updatedParticipants.isEmpty) {
      // Room ends when all participants leave
      state = null;
    } else {
      state = state!.copyWith(participants: updatedParticipants);
    }
  }

  /// Update participant typing status
  void setTyping(String peerId, bool isTyping) {
    if (state == null) return;

    final updatedParticipants = state!.participants.map((p) {
      if (p.peerId == peerId) {
        return p.copyWith(isTyping: isTyping);
      }
      return p;
    }).toList();

    state = state!.copyWith(participants: updatedParticipants);
  }

  /// Update display name
  void updateDisplayName(String peerId, String newName) {
    if (state == null) return;

    final participant = state!.participants.firstWhere(
      (p) => p.peerId == peerId,
      orElse: () => throw Exception('Participant not found'),
    );

    final oldName = participant.displayName;

    final updatedParticipants = state!.participants.map((p) {
      if (p.peerId == peerId) {
        return p.copyWith(displayName: newName);
      }
      return p;
    }).toList();

    state = state!.copyWith(participants: updatedParticipants);

    // Also update the current display name provider if it's the current user
    final currentPeerId = _ref.read(currentPeerIdProvider);
    if (peerId == currentPeerId) {
      _ref.read(currentDisplayNameProvider.notifier).state = newName;
    }

    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.displayNameChanged,
      message: '$oldName is now $newName',
      peerId: peerId,
    );
  }

  /// Check if a peer ID is kicked from the room
  bool isPeerKicked(String peerId) {
    return state?.isKicked(peerId) ?? false;
  }

  /// Approve a pending join request (creator only)
  bool approveJoinRequest(String peerId) {
    if (state == null) return false;

    final currentPeerId = _ref.read(currentPeerIdProvider);

    // Only creator can approve
    if (state!.creatorPeerId != currentPeerId) return false;

    // Find the pending request
    final requestIndex = state!.pendingJoinRequests
        .indexWhere((r) => r.peerId == peerId);
    if (requestIndex == -1) return false;

    // Check if room is now full
    if (state!.isFull) return false;

    final request = state!.pendingJoinRequests[requestIndex];

    // Create participant from request
    final participant = Participant(
      peerId: request.peerId,
      displayName: request.displayName,
      joinedAt: DateTime.now(),
      lastSeen: DateTime.now(),
      isCreator: false,
      isOnline: true,
    );

    // Remove from pending and add to participants
    final updatedRequests = [...state!.pendingJoinRequests]
      ..removeAt(requestIndex);

    state = state!.copyWith(
      participants: [...state!.participants, participant],
      pendingJoinRequests: updatedRequests,
    );

    // Add join notification
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.participantJoined,
      message: '${request.displayName} joined the room',
      peerId: peerId,
    );

    return true;
  }

  /// Reject a pending join request (creator only)
  bool rejectJoinRequest(String peerId) {
    if (state == null) return false;

    final currentPeerId = _ref.read(currentPeerIdProvider);

    // Only creator can reject
    if (state!.creatorPeerId != currentPeerId) return false;

    // Find and remove the pending request
    final requestIndex = state!.pendingJoinRequests
        .indexWhere((r) => r.peerId == peerId);
    if (requestIndex == -1) return false;

    final request = state!.pendingJoinRequests[requestIndex];

    final updatedRequests = [...state!.pendingJoinRequests]
      ..removeAt(requestIndex);

    state = state!.copyWith(
      pendingJoinRequests: updatedRequests,
    );

    // Add notification about rejection
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.joinRequestRejected,
      message: '${request.displayName} was denied entry',
      peerId: peerId,
    );

    return true;
  }

  /// Add simulated pending request (for testing)
  bool addSimulatedJoinRequest(String displayName) {
    if (state == null) return false;
    if (!state!.approvalMode) return false;

    final joinRequest = JoinRequest(
      peerId: _uuid.v4(),
      displayName: displayName,
      requestedAt: DateTime.now(),
    );

    state = state!.copyWith(
      pendingJoinRequests: [...state!.pendingJoinRequests, joinRequest],
    );

    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.joinRequestReceived,
      message: '$displayName is requesting to join',
      peerId: joinRequest.peerId,
    );

    return true;
  }

  /// End the room (creator only)
  /// This immediately terminates the room for all participants
  bool endRoom() {
    if (state == null) return false;

    final currentPeerId = _ref.read(currentPeerIdProvider);

    // Only creator can end the room
    if (state!.creatorPeerId != currentPeerId) return false;

    // Add notification about room ending
    _ref.read(notificationsProvider.notifier).addNotification(
      type: RoomNotificationType.roomExpired,
      message: 'Room has been ended by the creator',
      peerId: currentPeerId,
    );

    // Clear all room state
    state = null;
    _ref.read(messagesProvider.notifier).clearMessages();

    return true;
  }

  /// Clear room state
  void clearRoom() {
    state = null;
    _ref.read(messagesProvider.notifier).clearMessages();
    _ref.read(notificationsProvider.notifier).clearNotifications();
  }
}

/// Messages notifier
class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  MessagesNotifier() : super([]);

  /// Add a new message
  void addMessage({
    required String senderPeerId,
    required String senderDisplayName,
    required String content,
  }) {
    final message = ChatMessage(
      messageId: _uuid.v4(),
      senderPeerId: senderPeerId,
      senderDisplayName: senderDisplayName,
      content: content,
      timestamp: DateTime.now(),
    );

    state = [...state, message];
  }

  /// Mark messages from a peer as removed (when they leave or get kicked)
  void markMessagesAsRemoved(String peerId) {
    state = state.map((m) {
      if (m.senderPeerId == peerId) {
        return m.copyWith(isRemoved: true);
      }
      return m;
    }).toList();
  }

  /// Add a reaction to a message
  void addReaction(String messageId, String emoji, String peerId) {
    state = state.map((m) {
      if (m.messageId == messageId) {
        final updatedReactions = Map<String, List<String>>.from(m.reactions);
        if (updatedReactions.containsKey(emoji)) {
          if (!updatedReactions[emoji]!.contains(peerId)) {
            updatedReactions[emoji] = [...updatedReactions[emoji]!, peerId];
          }
        } else {
          updatedReactions[emoji] = [peerId];
        }
        return m.copyWith(reactions: updatedReactions);
      }
      return m;
    }).toList();
  }

  /// Mark message as seen
  void markAsSeen(String messageId, String peerId) {
    state = state.map((m) {
      if (m.messageId == messageId && !m.seenBy.contains(peerId)) {
        return m.copyWith(seenBy: [...m.seenBy, peerId]);
      }
      return m;
    }).toList();
  }

  /// Clear all messages
  void clearMessages() {
    state = [];
  }
}

/// Notifications notifier
class NotificationsNotifier extends StateNotifier<List<RoomNotification>> {
  NotificationsNotifier() : super([]);

  /// Add a notification
  void addNotification({
    required RoomNotificationType type,
    required String message,
    String? peerId,
  }) {
    final notification = RoomNotification(
      id: _uuid.v4(),
      type: type,
      message: message,
      timestamp: DateTime.now(),
      peerId: peerId,
    );

    state = [...state, notification];
  }

  /// Clear notifications
  void clearNotifications() {
    state = [];
  }
}

/// Disconnected sessions notifier - manages sessions in the reconnection grace period
class DisconnectedSessionsNotifier extends StateNotifier<List<DisconnectedSession>> {
  DisconnectedSessionsNotifier() : super([]);

  /// Add a disconnected session
  void addSession({
    required String peerId,
    required String displayName,
    required String roomCode,
    bool wasCreator = false,
  }) {
    // Remove any existing session for this peer
    state = state.where((s) => s.peerId != peerId).toList();

    final session = DisconnectedSession(
      peerId: peerId,
      displayName: displayName,
      roomCode: roomCode,
      disconnectedAt: DateTime.now(),
      wasCreator: wasCreator,
    );

    state = [...state, session];
  }

  /// Find a valid session for the given room code
  /// Returns null if no valid session exists or grace period has expired
  DisconnectedSession? findValidSession(String roomCode) {
    // Clean up expired sessions first
    _cleanupExpiredSessions();

    try {
      return state.firstWhere(
        (s) => s.roomCode == roomCode && s.isWithinGracePeriod,
      );
    } catch (_) {
      return null;
    }
  }

  /// Remove a session after successful reconnection
  void removeSession(String peerId) {
    state = state.where((s) => s.peerId != peerId).toList();
  }

  /// Clean up expired sessions
  void _cleanupExpiredSessions() {
    state = state.where((s) => s.isWithinGracePeriod).toList();
  }

  /// Clear all sessions
  void clearSessions() {
    state = [];
  }
}
