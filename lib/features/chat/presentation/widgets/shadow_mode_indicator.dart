import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/security_provider.dart';

/// Visual indicator showing when shadow mode (enhanced protection) is active.
///
/// Displays a compact badge in the app header when extra security
/// measures are enabled due to detected anomalies.
class ShadowModeIndicator extends ConsumerWidget {
  const ShadowModeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);

    if (!securityState.shadowModeActive) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: securityState.reason ?? 'Enhanced protection active',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.shadowMode.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.shadowMode.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_moon_outlined,
              size: 14,
              color: AppColors.shadowMode,
            ),
            const SizedBox(width: 4),
            Text(
              'Shadow',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.shadowMode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A button to toggle shadow mode for testing purposes.
class ShadowModeToggle extends ConsumerWidget {
  const ShadowModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(shadowModeActiveProvider);

    return IconButton(
      icon: Icon(
        isActive ? Icons.shield_moon : Icons.shield_moon_outlined,
        color: isActive ? AppColors.shadowMode : null,
      ),
      onPressed: () {
        ref.read(securityProvider.notifier).toggleShadowMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? 'Shadow mode deactivated'
                  : 'Shadow mode activated - enhanced protection enabled',
            ),
            backgroundColor: isActive ? AppColors.surface : AppColors.shadowMode,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      tooltip: isActive ? 'Deactivate shadow mode' : 'Activate shadow mode',
    );
  }
}
