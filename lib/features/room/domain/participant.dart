import 'package:flutter/foundation.dart';

/// Represents a participant in a chat room.
@immutable
class Participant {
  final String peerId;
  final String displayName;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isTyping;
  final bool isCreator;
  final bool isOnline;

  const Participant({
    required this.peerId,
    required this.displayName,
    required this.joinedAt,
    required this.lastSeen,
    this.isTyping = false,
    this.isCreator = false,
    this.isOnline = true,
  });

  Participant copyWith({
    String? peerId,
    String? displayName,
    DateTime? joinedAt,
    DateTime? lastSeen,
    bool? isTyping,
    bool? isCreator,
    bool? isOnline,
  }) {
    return Participant(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isTyping: isTyping ?? this.isTyping,
      isCreator: isCreator ?? this.isCreator,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Participant && other.peerId == peerId;
  }

  @override
  int get hashCode => peerId.hashCode;
}
