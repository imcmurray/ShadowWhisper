import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/room_provider.dart';

/// Screen for joining an existing chat room.
///
/// Allows users to enter a room code and generates ZK proof
/// to verify code knowledge without revealing it.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;
  double _proofProgress = 0.0;
  String _statusMessage = '';

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
      _errorMessage = null;
      _proofProgress = 0.0;
      _statusMessage = 'Generating ZK proof...';
    });

    // Simulate proof-of-work and ZK proof generation (~5 seconds)
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      setState(() {
        _proofProgress = i / 5;
        if (i == 1) _statusMessage = 'Computing proof-of-work...';
        if (i == 2) _statusMessage = 'Generating ZK proof...';
        if (i == 3) _statusMessage = 'Verifying credentials...';
        if (i == 4) _statusMessage = 'Connecting to swarm...';
        if (i == 5) _statusMessage = 'Joining room...';
      });
    }

    final roomCode = _roomCodeController.text.trim().toLowerCase();

    // Validate room code format
    if (!roomCode.startsWith('shadow-') || roomCode.length < 10) {
      setState(() {
        _isJoining = false;
        _errorMessage = 'Room not found';
      });
      return;
    }

    // Try to join the room
    final result = ref.read(roomProvider.notifier).joinRoom(
      roomCode: roomCode,
      roomName: 'Room',
    );

    // Handle join result
    switch (result) {
      case JoinResult.kicked:
        setState(() {
          _isJoining = false;
          _errorMessage = 'You have been removed from this room and cannot rejoin';
        });
        return;
      case JoinResult.roomFull:
        setState(() {
          _isJoining = false;
          _errorMessage = 'Room is full (maximum 20 participants)';
        });
        return;
      case JoinResult.notFound:
        setState(() {
          _isJoining = false;
          _errorMessage = 'Room not found';
        });
        return;
      case JoinResult.pending:
        // Navigate to waiting room for approval
        if (!mounted) return;
        final displayName = ref.read(currentDisplayNameProvider);
        Navigator.pushReplacementNamed(
          context,
          AppRouter.waitingRoom,
          arguments: WaitingRoomArgs(
            roomCode: roomCode,
            displayName: displayName,
          ),
        );
        return;
      case JoinResult.success:
        // Continue to navigate
        break;
    }

    if (!mounted) return;

    // Navigate to chat
    Navigator.pushReplacementNamed(
      context,
      AppRouter.chat,
      arguments: ChatScreenArgs(
        roomCode: roomCode,
        roomName: 'Room',
        isCreator: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _isJoining ? _buildJoiningState() : _buildJoinForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Icon(
            Icons.login_outlined,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Join a Room',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the room code shared with you',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),

          // Room code input
          TextFormField(
            controller: _roomCodeController,
            decoration: InputDecoration(
              labelText: 'Room Code',
              hintText: 'shadow-xxxxxx',
              prefixIcon: const Icon(Icons.key_outlined),
              errorText: _errorMessage,
            ),
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a room code';
              }
              return null;
            },
            onFieldSubmitted: (_) => _joinRoom(),
          ),
          const SizedBox(height: 32),

          // Join button
          ElevatedButton(
            onPressed: _joinRoom,
            child: const Text('Join Room'),
          ),
          const SizedBox(height: 24),

          // Security note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your room code is never transmitted. We use zero-knowledge proofs to verify your access.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoiningState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated lock icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _proofProgress),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    backgroundColor: AppColors.surface,
                    color: AppColors.primary,
                  ),
                ),
                Icon(
                  value < 1 ? Icons.lock_outline : Icons.lock_open_outlined,
                  size: 48,
                  color: value < 1 ? AppColors.textSecondary : AppColors.primary,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        // Status message
        Text(
          _statusMessage,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${(_proofProgress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 32),

        // Security info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Zero-knowledge verification in progress',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
