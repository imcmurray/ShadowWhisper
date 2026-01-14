import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/domain/participant.dart';
import '../../../room/providers/room_provider.dart';

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
                child: OutlinedButton.icon(
                  onPressed: () => _addTestParticipant(ref),
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add Test Participant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addTestParticipant(WidgetRef ref) {
    final names = [
      'Shadow Wolf', 'Midnight Hawk', 'Silent Panther', 'Phantom Eagle',
      'Mystic Raven', 'Covert Serpent', 'Stealth Tiger', 'Veiled Lynx',
    ];
    final random = DateTime.now().millisecondsSinceEpoch % names.length;
    ref.read(roomProvider.notifier).addSimulatedParticipant(names[random]);
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

  const _ParticipantTile({
    required this.participant,
    required this.showKickButton,
    required this.isSelf,
    required this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.background,
            child: Text(
              participant.displayName[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.primary,
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
                color: participant.isOnline ? AppColors.online : AppColors.offline,
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
        ],
      ),
      subtitle: participant.isTyping
          ? Text(
              'typing...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.typing,
                    fontStyle: FontStyle.italic,
                  ),
            )
          : null,
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
