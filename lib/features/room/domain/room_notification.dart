import 'package:flutter/foundation.dart';

/// Types of room notifications
enum RoomNotificationType {
  participantJoined,
  participantLeft,
  participantKicked,
  roomExpired,
  displayNameChanged,
  joinRequestReceived,
  joinRequestRejected,
}

/// Represents a system notification in a room.
@immutable
class RoomNotification {
  final String id;
  final RoomNotificationType type;
  final String message;
  final DateTime timestamp;
  final String? peerId; // Related peer if applicable

  const RoomNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.peerId,
  });
}
