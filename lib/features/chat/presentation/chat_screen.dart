import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../room/providers/room_provider.dart';
import '../../room/domain/room_notification.dart';
import '../providers/security_provider.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_list.dart';
import 'widgets/participant_drawer.dart';
import 'widgets/blur_overlay.dart';
import 'widgets/shadow_mode_indicator.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/connection_banner.dart';

/// Main chat screen for the room.
///
/// Displays:
/// - Header with room name, participant count, settings, leave button
/// - Participant list (sidebar/drawer)
/// - Message area (scrollable, newest at bottom)
/// - Input area with emoji picker and send button
/// - Blur overlay when window loses focus
class ChatScreen extends ConsumerStatefulWidget {
  final ChatScreenArgs args;

  const ChatScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isBlurred = false;
  int? _lastNotificationCount;
  Timer? _timeoutCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize room state if coming from create room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRoom();
    });

    // Start periodic timer to check for timed out participants
    _timeoutCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTimedOutParticipants();
    });
  }

  void _checkTimedOutParticipants() {
    // Check and remove timed out participants
    final removedPeerIds = ref.read(roomProvider.notifier).checkAndRemoveTimedOutParticipants();
    if (removedPeerIds.isNotEmpty) {
      // Force UI rebuild to update participant list and countdown timers
      setState(() {});
    }
  }

  void _initializeRoom() {
    if (widget.args.isCreator) {
      ref.read(roomProvider.notifier).createRoom(
        roomName: widget.args.roomName ?? 'Room',
        roomCode: widget.args.roomCode ?? 'unknown',
        approvalMode: widget.args.approvalMode,
      );
    } else {
      ref.read(roomProvider.notifier).joinRoom(
        roomCode: widget.args.roomCode ?? 'unknown',
        roomName: widget.args.roomName ?? 'Room',
      );
    }
  }

  @override
  void dispose() {
    _timeoutCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Activate blur when app is not in foreground
    setState(() {
      _isBlurred = state != AppLifecycleState.resumed;
    });
  }

  void _showLeaveConfirmation() {
    final isCreator = ref.read(isCreatorProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isCreator ? 'Leave or End Room?' : 'Leave Room?'),
        content: Text(
          isCreator
              ? 'You can leave the room (your messages disappear) or end the room for everyone.'
              : 'Are you sure you want to leave? Your messages will disappear for all participants, and you will have a 30-second lockout before you can rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          if (isCreator)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _endRoom();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
              ),
              child: const Text('End Room'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _leaveRoom();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _leaveRoom() {
    ref.read(roomProvider.notifier).leaveRoom();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.landing,
      (route) => false,
    );
  }

  void _endRoom() {
    ref.read(roomProvider.notifier).endRoom();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRouter.landing,
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.pushNamed(context, AppRouter.settings);
  }

  void _openParticipants() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final participantCount = ref.watch(participantCountProvider);
    final notifications = ref.watch(notificationsProvider);
    final room = ref.watch(roomProvider);

    // Show notification snackbars for new notifications
    if (_lastNotificationCount != null && notifications.length > _lastNotificationCount!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newNotifications = notifications.skip(_lastNotificationCount!);
        for (final notification in newNotifications) {
          if (notification.type == RoomNotificationType.participantKicked ||
              notification.type == RoomNotificationType.participantJoined ||
              notification.type == RoomNotificationType.participantLeft) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(notification.message),
                backgroundColor: notification.type == RoomNotificationType.participantKicked
                    ? AppColors.error
                    : AppColors.surface,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      });
    }
    _lastNotificationCount = notifications.length;

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(participantCount, room?.roomName ?? widget.args.roomName ?? 'Room'),
          endDrawer: ParticipantDrawer(
            onClose: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              // Connection status banner (shows only when disconnected)
              const ConnectionBanner(),

              // Message list
              const Expanded(
                child: MessageList(),
              ),

              // Typing indicator
              const TypingIndicator(),

              // Chat input
              const ChatInput(),
            ],
          ),
        ),

        // Blur overlay for anti-surveillance
        if (_isBlurred) const BlurOverlay(),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(int participantCount, String roomName) {
    final pendingCount = ref.watch(pendingRequestCountProvider);
    final isApprovalMode = ref.watch(roomProvider)?.approvalMode ?? false;
    final isCreator = ref.watch(isCreatorProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        roomName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const ShadowModeIndicator(),
                    const SizedBox(width: 4),
                    const ConnectionIndicator(),
                    if (isApprovalMode) ...[
                      const SizedBox(width: 4),
                      const _ApprovalModeIndicator(),
                    ],
                  ],
                ),
                Text(
                  '$participantCount participant${participantCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Shadow mode toggle (for testing)
        const ShadowModeToggle(),
        // Participants button with pending badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.people_outline),
              onPressed: _openParticipants,
              tooltip: 'Participants',
            ),
            if (isCreator && pendingCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: _openSettings,
          tooltip: 'Settings',
        ),
        // Leave button
        IconButton(
          icon: const Icon(Icons.logout_outlined),
          onPressed: _showLeaveConfirmation,
          tooltip: 'Leave Room',
          color: AppColors.error,
        ),
      ],
    );
  }
}

/// Small indicator showing approval mode is active.
class _ApprovalModeIndicator extends StatelessWidget {
  const _ApprovalModeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity( 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 10,
            color: AppColors.warning,
          ),
          const SizedBox(width: 2),
          Text(
            'Approval',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
          ),
        ],
      ),
    );
  }
}
