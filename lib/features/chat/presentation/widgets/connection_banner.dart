import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/security_provider.dart';

/// Banner widget that displays connection status with friendly messages.
///
/// Shows:
/// - Green banner when connected
/// - Yellow banner when connecting/reconnecting
/// - Red banner when disconnected
///
/// All messages are user-friendly with no technical details.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionProvider);

    // Only show banner when not connected normally
    if (connectionStatus.state == ConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _getBackgroundColor(connectionStatus.state),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            _getIcon(connectionStatus.state),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connectionStatus.friendlyMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getTextColor(connectionStatus.state),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (connectionStatus.state == ConnectionState.disconnected)
              TextButton(
                onPressed: () {
                  ref.read(connectionProvider.notifier).setReconnecting();
                  // Simulate reconnection after a short delay
                  Future.delayed(const Duration(seconds: 2), () {
                    ref.read(connectionProvider.notifier).setConnected();
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: _getTextColor(connectionStatus.state),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Retry'),
              ),
            if (connectionStatus.state == ConnectionState.connecting ||
                connectionStatus.state == ConnectionState.reconnecting)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return AppColors.success;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return AppColors.warning;
      case ConnectionState.disconnected:
        return AppColors.error;
    }
  }

  Color _getTextColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return AppColors.textPrimary;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return AppColors.background;
      case ConnectionState.disconnected:
        return AppColors.textPrimary;
    }
  }

  Widget _getIcon(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return const Icon(Icons.wifi, color: Colors.white, size: 20);
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return const Icon(Icons.wifi_find, color: Colors.white, size: 20);
      case ConnectionState.disconnected:
        return const Icon(Icons.wifi_off, color: Colors.white, size: 20);
    }
  }
}

/// Compact connection status indicator for the app bar.
class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionProvider);

    return Tooltip(
      message: connectionStatus.friendlyMessage,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getColor(connectionStatus.state),
        ),
      ),
    );
  }

  Color _getColor(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        return AppColors.success;
      case ConnectionState.connecting:
      case ConnectionState.reconnecting:
        return AppColors.warning;
      case ConnectionState.disconnected:
        return AppColors.error;
    }
  }
}
