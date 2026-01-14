import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_list.dart';
import 'widgets/participant_drawer.dart';
import 'widgets/blur_overlay.dart';

/// Main chat screen for the room.
///
/// Displays:
/// - Header with room name, participant count, settings, leave button
/// - Participant list (sidebar/drawer)
/// - Message area (scrollable, newest at bottom)
/// - Input area with emoji picker and send button
/// - Blur overlay when window loses focus
class ChatScreen extends StatefulWidget {
  final ChatScreenArgs args;

  const ChatScreen({
    super.key,
    required this.args,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isBlurred = false;
  int _participantCount = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(),
          endDrawer: ParticipantDrawer(
            isCreator: widget.args.isCreator,
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.args.roomName ?? 'Room',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$_participantCount participant${_participantCount == 1 ? '' : 's'}',
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
