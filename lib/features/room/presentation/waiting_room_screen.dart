import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/room_provider.dart';

/// Waiting room screen for rooms with approval required.
///
/// Displays a pending state while waiting for the room creator
/// to approve the join request.
class WaitingRoomScreen extends ConsumerStatefulWidget {
  final WaitingRoomArgs args;

  const WaitingRoomScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _wasRejected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _cancelRequest() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.landing,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for approval status changes
    final currentPeerId = ref.watch(currentPeerIdProvider);
    final participants = ref.watch(participantsProvider);
    final pendingRequests = ref.watch(pendingJoinRequestsProvider);

    // Check if we've been approved (our peerId is now in participants)
    final isApproved = participants.any((p) => p.peerId == currentPeerId);

    // Check if we've been rejected (our peerId is no longer in pending)
    final isStillPending = pendingRequests.any((r) => r.peerId == currentPeerId);

    // If approved, navigate to chat
    if (isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(
          context,
          AppRouter.chat,
          arguments: ChatScreenArgs(
            roomCode: widget.args.roomCode,
            roomName: 'Room',
            isCreator: false,
          ),
        );
      });
    }

    // If rejected (not in pending and not approved), show rejection message
    if (!isApproved && !isStillPending && !_wasRejected) {
      _wasRejected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRejectionDialog();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated waiting indicator
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity( 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Waiting message
              Text(
                'Waiting for Approval',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'The room creator needs to approve your request to join.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 48),

              // Room info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.key_outlined,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.args.roomCode ?? 'Unknown',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                        ),
                      ],
                    ),
                    if (widget.args.displayName != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Joining as: ${widget.args.displayName}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Cancel button
              OutlinedButton.icon(
                onPressed: _cancelRequest,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Request Denied'),
        content: const Text(
          'The room creator has denied your request to join.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRouter.landing,
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
