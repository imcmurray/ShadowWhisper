import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/domain/room.dart';
import '../../../room/providers/room_provider.dart';

/// Section showing pending join requests for approval mode rooms.
///
/// Displays a list of users waiting for approval with
/// approve and reject buttons for each.
class PendingRequestsSection extends ConsumerWidget {
  final List<JoinRequest> pendingRequests;

  const PendingRequestsSection({
    super.key,
    required this.pendingRequests,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.surface,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pending Requests',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pendingRequests.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),

          // Request list
          ...pendingRequests.map((request) => _PendingRequestTile(
                request: request,
                onApprove: () => _approveRequest(ref, request),
                onReject: () => _rejectRequest(ref, request),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _approveRequest(WidgetRef ref, JoinRequest request) {
    ref.read(roomProvider.notifier).approveJoinRequest(request.peerId);
  }

  void _rejectRequest(WidgetRef ref, JoinRequest request) {
    ref.read(roomProvider.notifier).rejectJoinRequest(request.peerId);
  }
}

/// Individual pending request tile with approve/reject buttons.
class _PendingRequestTile extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingRequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: AppColors.warning.withValues(alpha: 0.2),
              radius: 18,
              child: Text(
                request.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    _formatTime(request.requestedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

            // Approve button
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              onPressed: onApprove,
              color: AppColors.online,
              tooltip: 'Approve',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),

            // Reject button
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              onPressed: onReject,
              color: AppColors.error,
              tooltip: 'Reject',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }
}
