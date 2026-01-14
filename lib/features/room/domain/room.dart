import 'package:flutter/foundation.dart';
import 'participant.dart';

/// Maximum number of participants allowed in a room.
const int maxRoomParticipants = 20;

/// Represents a pending join request in approval mode.
@immutable
class JoinRequest {
  final String peerId;
  final String displayName;
  final DateTime requestedAt;

  const JoinRequest({
    required this.peerId,
    required this.displayName,
    required this.requestedAt,
  });
}

/// Represents an ephemeral chat room.
@immutable
class Room {
  final String swarmId;
  final String roomName;
  final String roomCode;
  final bool approvalMode;
  final String creatorPeerId;
  final List<Participant> participants;
  final List<String> kickedPeerIds;
  final List<JoinRequest> pendingJoinRequests;
  final DateTime createdAt;

  const Room({
    required this.swarmId,
    required this.roomName,
    required this.roomCode,
    required this.creatorPeerId,
    this.approvalMode = false,
    this.participants = const [],
    this.kickedPeerIds = const [],
    this.pendingJoinRequests = const [],
    required this.createdAt,
  });

  /// Get the creator participant
  Participant? get creator {
    try {
      return participants.firstWhere((p) => p.isCreator);
    } catch (_) {
      return null;
    }
  }

  /// Check if a peer ID has been kicked from this room
  bool isKicked(String peerId) => kickedPeerIds.contains(peerId);

  /// Get participant count
  int get participantCount => participants.length;

  /// Check if the room is full
  bool get isFull => participants.length >= maxRoomParticipants;

  /// Check if there are pending join requests
  bool get hasPendingRequests => pendingJoinRequests.isNotEmpty;

  /// Get pending request count
  int get pendingRequestCount => pendingJoinRequests.length;

  Room copyWith({
    String? swarmId,
    String? roomName,
    String? roomCode,
    bool? approvalMode,
    String? creatorPeerId,
    List<Participant>? participants,
    List<String>? kickedPeerIds,
    List<JoinRequest>? pendingJoinRequests,
    DateTime? createdAt,
  }) {
    return Room(
      swarmId: swarmId ?? this.swarmId,
      roomName: roomName ?? this.roomName,
      roomCode: roomCode ?? this.roomCode,
      approvalMode: approvalMode ?? this.approvalMode,
      creatorPeerId: creatorPeerId ?? this.creatorPeerId,
      participants: participants ?? this.participants,
      kickedPeerIds: kickedPeerIds ?? this.kickedPeerIds,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
