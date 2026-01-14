import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../room/providers/room_provider.dart';
import '../../chat/providers/security_provider.dart';

/// Settings screen overlay/modal.
///
/// Features:
/// - Display name change
/// - Security features explanation
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _displayNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load current display name from state
    _displayNameController.text = ref.read(currentDisplayNameProvider);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final newName = _displayNameController.text.trim();
    if (newName.isEmpty) return;

    // Check if name is different from current
    final currentName = ref.read(currentDisplayNameProvider);
    if (newName == currentName) return;

    setState(() {
      _isSaving = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Update display name via room provider
    final currentPeerId = ref.read(currentPeerIdProvider);
    final room = ref.read(roomProvider);

    if (room != null) {
      // Update in room state (will also update currentDisplayNameProvider)
      ref.read(roomProvider.notifier).updateDisplayName(currentPeerId, newName);
    } else {
      // Not in a room, just update the provider directly
      ref.read(currentDisplayNameProvider.notifier).state = newName;
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name updated'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background.withValues(alpha: 0.9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Display name section
                    _buildSection(
                      context,
                      title: 'Display Name',
                      icon: Icons.person_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your display name',
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveDisplayName,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Security features section
                    _buildSection(
                      context,
                      title: 'Security Features',
                      icon: Icons.shield_outlined,
                      child: Column(
                        children: [
                          _buildSecurityFeature(
                            context,
                            icon: Icons.visibility_off_outlined,
                            title: 'Zero-Knowledge Authentication',
                            description:
                                'Your room code is never transmitted. We use ZK-SNARKs to prove you know the code without revealing it.',
                          ),
                          const Divider(height: 24),
                          _buildSecurityFeature(
                            context,
                            icon: Icons.timer_outlined,
                            title: 'Ephemeral by Design',
                            description:
                                'All messages exist only in memory. When you leave, your messages disappear for everyone.',
                          ),
                          const Divider(height: 24),
                          _buildSecurityFeature(
                            context,
                            icon: Icons.hub_outlined,
                            title: 'Peer-to-Peer Mesh',
                            description:
                                'No central servers. Messages travel directly between participants through encrypted P2P connections.',
                          ),
                          const Divider(height: 24),
                          _buildSecurityFeature(
                            context,
                            icon: Icons.lock_outline,
                            title: 'Post-Quantum Encryption',
                            description:
                                'Kyber encryption protects your messages against future quantum computer attacks.',
                          ),
                          const Divider(height: 24),
                          _buildSecurityFeature(
                            context,
                            icon: Icons.blur_on_outlined,
                            title: 'Anti-Surveillance',
                            description:
                                'Screen blur activates when the window loses focus, protecting against screen capture.',
                          ),
                          const Divider(height: 24),
                          _buildSecurityFeature(
                            context,
                            icon: Icons.public_off_outlined,
                            title: 'Onion Routing',
                            description:
                                'Traffic is routed through multiple anonymous relays, hiding your IP address.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Developer tools section (for testing)
                    _buildSection(
                      context,
                      title: 'Developer Tools',
                      icon: Icons.bug_report_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Test network error handling',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(connectionProvider.notifier).simulateNetworkError();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.wifi_off, size: 18),
                            label: const Text('Simulate Network Error'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              ref.read(connectionProvider.notifier).setConnected();
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.wifi, size: 18),
                            label: const Text('Restore Connection'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.success,
                              side: const BorderSide(color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildSecurityFeature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
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
