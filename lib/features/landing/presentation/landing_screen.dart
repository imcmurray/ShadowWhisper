import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Landing page for ShadowWhisper.
///
/// Displays:
/// - Hero section with branding
/// - Security features explanation
/// - Create Room and Join Room buttons
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and branding
                  _buildHeroSection(context),
                  const SizedBox(height: 48),

                  // Security features
                  _buildSecurityFeatures(context),
                  const SizedBox(height: 48),

                  // Action buttons
                  _buildActionButtons(context),
                  const SizedBox(height: 48),

                  // Footer
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Logo icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 64,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),

        // App name
        Text(
          'ShadowWhisper',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
        ),
        const SizedBox(height: 12),

        // Tagline
        Text(
          'Zero-Trust Anonymous Chat',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          'Ephemeral, encrypted, and truly private. No servers, no logs, no traces.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildSecurityFeatures(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildFeatureRow(
            context,
            Icons.visibility_off_outlined,
            'Zero-Knowledge Auth',
            'Prove you belong without revealing anything',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            context,
            Icons.timer_outlined,
            'Ephemeral by Design',
            'Messages vanish when you leave',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            context,
            Icons.hub_outlined,
            'Peer-to-Peer',
            'No central servers to compromise',
          ),
          const SizedBox(height: 16),
          _buildFeatureRow(
            context,
            Icons.shield_outlined,
            'Post-Quantum Encryption',
            'Future-proof security',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
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
        const SizedBox(width: 16),
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.createRoom);
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create Room'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRouter.joinRoom);
            },
            icon: const Icon(Icons.login_outlined),
            label: const Text('Join Room'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Text(
      'All conversations are end-to-end encrypted and never stored.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
    );
  }
}
