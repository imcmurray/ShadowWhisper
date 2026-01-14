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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize room state if coming from create room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRoom();
    });
  }

  void _initializeRoom() {
    if (widget.args.isCreator) {
      ref.read(roomProvider.notifier).createRoom(
        roomName: widget.args.roomName ?? 'Room',
        roomCode: widget.args.roomCode ?? 'unknown',
        approvalMode: false,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Room?'),
        content: const Text(
          'Are you sure you want to leave? Your messages will disappear for all participants, and you will have a 30-second lockout before you can rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
              // Message list
              const Expanded(
                child: MessageList(),
              ),

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
                    Text(
                      roomName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    const ShadowModeIndicator(),
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
        // Participants button
        IconButton(
          icon: const Icon(Icons.people_outline),
          onPressed: _openParticipants,
          tooltip: 'Participants',
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
