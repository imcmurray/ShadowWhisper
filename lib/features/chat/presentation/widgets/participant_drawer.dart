import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/domain/participant.dart';
import '../../../room/domain/room.dart';
import '../../../room/providers/room_provider.dart';
import 'pending_requests_section.dart';

/// Drawer showing the list of room participants.
///
/// Features:
/// - Online status indicators
/// - Creator badge
/// - Kick button for creators
class ParticipantDrawer extends ConsumerWidget {
  final VoidCallback onClose;

  const ParticipantDrawer({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participants = ref.watch(participantsProvider);
    final isCreator = ref.watch(isCreatorProvider);
    final currentPeerId = ref.watch(currentPeerIdProvider);
    final pendingRequests = ref.watch(pendingJoinRequestsProvider);
    final room = ref.watch(roomProvider);
    final isApprovalMode = room?.approvalMode ?? false;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.background,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Participants',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${participants.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),

            // Pending requests section (only for creator in approval mode)
            if (isCreator && isApprovalMode && pendingRequests.isNotEmpty)
              PendingRequestsSection(
                pendingRequests: pendingRequests,
              ),

            // Participant list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  final isSelf = participant.peerId == currentPeerId;
                  return _ParticipantTile(
                    participant: participant,
                    showKickButton: isCreator && !participant.isCreator && !isSelf,
                    isSelf: isSelf,
                    onKick: () => _kickParticipant(context, ref, participant),
                  );
                },
              ),
            ),

            // Add test participant button (for development)
            if (isCreator)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _addTestParticipant(context, ref),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add Test Participant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _simulateDisconnect(context, ref),
                      icon: const Icon(Icons.wifi_off_outlined),
                      label: const Text('Simulate Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                      ),
                    ),
                    if (isApprovalMode) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _addTestJoinRequest(context, ref),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: const Text('Simulate Join Request'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addTestParticipant(BuildContext context, WidgetRef ref) {
    final names = [
      'Shadow Wolf', 'Midnight Hawk', 'Silent Panther', 'Phantom Eagle',
      'Mystic Raven', 'Covert Serpent', 'Stealth Tiger', 'Veiled Lynx',
    ];
    final random = DateTime.now().millisecondsSinceEpoch % names.length;
    final success = ref.read(roomProvider.notifier).addSimulatedParticipant(names[random]);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room is full (maximum $maxRoomParticipants participants)'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _addTestJoinRequest(BuildContext context, WidgetRef ref) {
    final names = [
      'Curious Owl', 'Wandering Fox', 'Seeking Bear', 'Hopeful Deer',
      'Eager Rabbit', 'Patient Crow', 'Waiting Wolf', 'Pending Puma',
    ];
    final random = DateTime.now().millisecondsSinceEpoch % names.length;
    final success = ref.read(roomProvider.notifier).addSimulatedJoinRequest(names[random]);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approval mode is not enabled'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _simulateDisconnect(BuildContext context, WidgetRef ref) {
    final participants = ref.read(participantsProvider);
    final currentPeerId = ref.read(currentPeerIdProvider);

    // Find a non-creator, non-self participant to disconnect
    final targetParticipant = participants.where(
      (p) => !p.isCreator && p.peerId != currentPeerId && p.isOnline && !p.isDisconnected,
    ).toList();

    if (targetParticipant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No participants available to disconnect. Add a test participant first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Disconnect the first available participant
    final participant = targetParticipant.first;
    ref.read(roomProvider.notifier).markParticipantDisconnected(participant.peerId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${participant.displayName} disconnected. 30s countdown started.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _kickParticipant(BuildContext context, WidgetRef ref, Participant participant) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Participant?'),
        content: Text(
          'Are you sure you want to remove ${participant.displayName}? They will not be able to rejoin this room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final success = ref.read(roomProvider.notifier).kickParticipant(participant.peerId);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${participant.displayName} was removed'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// Individual participant tile.
class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool showKickButton;
  final bool isSelf;
  final VoidCallback onKick;
  final VoidCallback? onSimulateDisconnect;

  const _ParticipantTile({
    required this.participant,
    required this.showKickButton,
    required this.isSelf,
    required this.onKick,
    this.onSimulateDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isDisconnected = participant.isDisconnected;
    final remainingSeconds = participant.timeoutRemainingSeconds;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isDisconnected
                ? AppColors.warning.withValues(alpha: 0.2)
                : AppColors.background,
            child: Text(
              participant.displayName[0].toUpperCase(),
              style: TextStyle(
                color: isDisconnected ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Online indicator
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isDisconnected
                    ? AppColors.warning
                    : (participant.isOnline ? AppColors.online : AppColors.offline),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              participant.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDisconnected ? AppColors.textSecondary : null,
              ),
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'You',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          if (participant.isCreator) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Creator',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
          // Disconnected countdown badge
          if (isDisconnected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${remainingSeconds}s',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      subtitle: isDisconnected
          ? Text(
              'Disconnected - will be removed in ${remainingSeconds}s',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                    fontStyle: FontStyle.italic,
                  ),
            )
          : (participant.isTyping
              ? Text(
                  'typing...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.typing,
                        fontStyle: FontStyle.italic,
                      ),
                )
              : null),
      trailing: showKickButton
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              onPressed: onKick,
              color: AppColors.error,
              tooltip: 'Remove',
            )
          : null,
    );
  }
}
