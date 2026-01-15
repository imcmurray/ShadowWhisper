/// P2P message types for ShadowWhisper.
///
/// These messages are sent directly between peers over WebRTC data channels.

enum P2PMessageType {
  // Connection management
  hello,
  goodbye,
  heartbeat,

  // Room state
  roomState,
  participantJoin,
  participantLeave,
  participantKick,

  // Chat
  chatMessage,
  typingStart,
  typingStop,
  messageReaction,
  messageSeen,

  // Admin (approval mode)
  joinRequest,
  joinApprove,
  joinReject,
}

/// A message sent between peers.
class P2PMessage {
  final P2PMessageType type;
  final String senderId;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  P2PMessage({
    required this.type,
    required this.senderId,
    DateTime? timestamp,
    this.payload = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  factory P2PMessage.fromJson(Map<String, dynamic> json) {
    return P2PMessage(
      type: P2PMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => P2PMessageType.hello,
      ),
      senderId: json['senderId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload: json['payload'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
    };
  }

  /// Create a hello message for initial handshake.
  factory P2PMessage.hello({
    required String senderId,
    required String displayName,
    String? roomName,
    bool isCreator = false,
  }) {
    return P2PMessage(
      type: P2PMessageType.hello,
      senderId: senderId,
      payload: {
        'displayName': displayName,
        if (roomName != null) 'roomName': roomName,
        'isCreator': isCreator,
      },
    );
  }

  /// Create a chat message.
  factory P2PMessage.chat({
    required String senderId,
    required String messageId,
    required String content,
    required String displayName,
  }) {
    return P2PMessage(
      type: P2PMessageType.chatMessage,
      senderId: senderId,
      payload: {
        'messageId': messageId,
        'content': content,
        'displayName': displayName,
      },
    );
  }

  /// Create a typing indicator message.
  factory P2PMessage.typing({
    required String senderId,
    required bool isTyping,
  }) {
    return P2PMessage(
      type: isTyping ? P2PMessageType.typingStart : P2PMessageType.typingStop,
      senderId: senderId,
    );
  }

  /// Create a heartbeat message.
  factory P2PMessage.heartbeat({required String senderId}) {
    return P2PMessage(
      type: P2PMessageType.heartbeat,
      senderId: senderId,
    );
  }

  /// Create a goodbye message.
  factory P2PMessage.goodbye({required String senderId}) {
    return P2PMessage(
      type: P2PMessageType.goodbye,
      senderId: senderId,
    );
  }
}
