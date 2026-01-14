import 'package:flutter/foundation.dart';

/// Represents a chat message in a room.
@immutable
class ChatMessage {
  final String messageId;
  final String senderPeerId;
  final String senderDisplayName;
  final String content;
  final DateTime timestamp;
  final Map<String, List<String>> reactions; // emoji -> list of peerIds
  final List<String> seenBy;
  final List<String> deliveredTo;
  final bool isRemoved; // True if sender left the room

  const ChatMessage({
    required this.messageId,
    required this.senderPeerId,
    required this.senderDisplayName,
    required this.content,
    required this.timestamp,
    this.reactions = const {},
    this.seenBy = const [],
    this.deliveredTo = const [],
    this.isRemoved = false,
  });

  ChatMessage copyWith({
    String? messageId,
    String? senderPeerId,
    String? senderDisplayName,
    String? content,
    DateTime? timestamp,
    Map<String, List<String>>? reactions,
    List<String>? seenBy,
    List<String>? deliveredTo,
    bool? isRemoved,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderPeerId: senderPeerId ?? this.senderPeerId,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      reactions: reactions ?? this.reactions,
      seenBy: seenBy ?? this.seenBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.messageId == messageId;
  }

  @override
  int get hashCode => messageId.hashCode;
}
