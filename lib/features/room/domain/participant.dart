import 'package:flutter/foundation.dart';

/// Timeout period for disconnected participants in seconds.
const int participantTimeoutSeconds = 30;

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
  final DateTime? disconnectedAt;

  const Participant({
    required this.peerId,
    required this.displayName,
    required this.joinedAt,
    required this.lastSeen,
    this.isTyping = false,
    this.isCreator = false,
    this.isOnline = true,
    this.disconnectedAt,
  });

  /// Check if the participant is in disconnected state (not yet timed out)
  bool get isDisconnected => disconnectedAt != null && !isOnline;

  /// Get remaining seconds before timeout (0 if not disconnected or already timed out)
  int get timeoutRemainingSeconds {
    if (disconnectedAt == null) return 0;
    final elapsed = DateTime.now().difference(disconnectedAt!);
    final remaining = participantTimeoutSeconds - elapsed.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if the participant has timed out (should be removed)
  bool get hasTimedOut {
    if (disconnectedAt == null) return false;
    final elapsed = DateTime.now().difference(disconnectedAt!);
    return elapsed.inSeconds >= participantTimeoutSeconds;
  }

  Participant copyWith({
    String? peerId,
    String? displayName,
    DateTime? joinedAt,
    DateTime? lastSeen,
    bool? isTyping,
    bool? isCreator,
    bool? isOnline,
    DateTime? disconnectedAt,
    bool clearDisconnectedAt = false,
  }) {
    return Participant(
      peerId: peerId ?? this.peerId,
      displayName: displayName ?? this.displayName,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isTyping: isTyping ?? this.isTyping,
      isCreator: isCreator ?? this.isCreator,
      isOnline: isOnline ?? this.isOnline,
      disconnectedAt: clearDisconnectedAt ? null : (disconnectedAt ?? this.disconnectedAt),
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
