import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Drawer showing the list of room participants.
///
/// Features:
/// - Online status indicators
/// - Creator badge
/// - Kick button for creators
class ParticipantDrawer extends StatelessWidget {
  final bool isCreator;
  final VoidCallback onClose;

  const ParticipantDrawer({
    super.key,
    required this.isCreator,
    required this.onClose,
  });

  // TODO: Replace with real participants from Riverpod state
  List<_Participant> get _participants => [
        _Participant(
          id: '1',
          displayName: 'Anonymous Fox',
          isOnline: true,
          isCreator: true,
          isTyping: false,
        ),
      ];

  @override
  Widget build(BuildContext context) {
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
                    '${_participants.length}',
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
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final participant = _participants[index];
                  return _ParticipantTile(
                    participant: participant,
                    showKickButton: isCreator && !participant.isCreator,
                    onKick: () => _kickParticipant(context, participant),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _kickParticipant(BuildContext context, _Participant participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant?'),
        content: Text(
          'Are you sure you want to remove ${participant.displayName}? They will not be able to rejoin this room.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Kick participant via P2P network
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
  final _Participant participant;
  final bool showKickButton;
  final VoidCallback onKick;

  const _ParticipantTile({
    required this.participant,
    required this.showKickButton,
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
                color:
                    participant.isOnline ? AppColors.online : AppColors.offline,
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

/// Participant model (temporary, will be replaced with proper model).
class _Participant {
  final String id;
  final String displayName;
  final bool isOnline;
  final bool isCreator;
  final bool isTyping;

  _Participant({
    required this.id,
    required this.displayName,
    required this.isOnline,
    required this.isCreator,
    required this.isTyping,
  });
}
