import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Screen for creating a new ephemeral chat room.
///
/// Allows users to:
/// - Enter a room name
/// - Choose approval mode (open vs approval required)
/// - Generate and copy room code
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  bool _approvalRequired = false;
  bool _isCreating = false;
  String? _generatedRoomCode;
  bool _codeCopied = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  String _generateRoomCode() {
    // Generate a random room code in format "shadow-XXXXXX"
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = List.generate(6, (index) {
      return chars[(random ~/ (index + 1)) % chars.length];
    }).join();
    return 'shadow-$code';
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    // Simulate room creation delay (P2P setup)
    await Future.delayed(const Duration(milliseconds: 500));

    final roomCode = _generateRoomCode();

    setState(() {
      _generatedRoomCode = roomCode;
      _isCreating = false;
    });
  }

  Future<void> _copyRoomCode() async {
    if (_generatedRoomCode == null) return;

    await Clipboard.setData(ClipboardData(text: _generatedRoomCode!));

    setState(() {
      _codeCopied = true;
    });

    // Reset copy state after a delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _codeCopied = false;
        });
      }
    });
  }

  void _enterRoom() {
    Navigator.pushReplacementNamed(
      context,
      AppRouter.chat,
      arguments: ChatScreenArgs(
        roomCode: _generatedRoomCode,
        roomName: _roomNameController.text.trim(),
        isCreator: true,
        approvalMode: _approvalRequired,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Room'),
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
              child: _generatedRoomCode == null
                  ? _buildCreationForm()
                  : _buildRoomCodeDisplay(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Icon(
            Icons.add_circle_outline,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Create a New Room',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Set up your ephemeral chat room',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),

          // Room name input
          TextFormField(
            controller: _roomNameController,
            decoration: const InputDecoration(
              labelText: 'Room Name',
              hintText: 'Enter a name for your room',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a room name';
              }
              if (value.trim().length < 2) {
                return 'Room name must be at least 2 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _createRoom(),
          ),
          const SizedBox(height: 24),

          // Approval mode toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Require Approval',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _approvalRequired
                            ? 'You must approve each join request'
                            : 'Anyone with the code can join instantly',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _approvalRequired,
                  onChanged: (value) {
                    setState(() {
                      _approvalRequired = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Create button
          ElevatedButton(
            onPressed: _isCreating ? null : _createRoom,
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Text('Create Room'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),

        // Success message
        Text(
          'Room Created!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Share this code with others to invite them',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 32),

        // Room code display
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                _generatedRoomCode!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyRoomCode,
                  icon: Icon(
                    _codeCopied ? Icons.check : Icons.copy_outlined,
                  ),
                  label: Text(_codeCopied ? 'Copied!' : 'Copy Code'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Enter room button
        ElevatedButton.icon(
          onPressed: _enterRoom,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Enter Room'),
        ),
      ],
    );
  }
}
