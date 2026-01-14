import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shadow mode state for enhanced security.
///
/// Shadow mode activates additional onion routing hops
/// when anomalies are detected in network traffic.
class SecurityState {
  final bool shadowModeActive;
  final String? reason;
  final DateTime? activatedAt;

  const SecurityState({
    this.shadowModeActive = false,
    this.reason,
    this.activatedAt,
  });

  SecurityState copyWith({
    bool? shadowModeActive,
    String? reason,
    DateTime? activatedAt,
  }) {
    return SecurityState(
      shadowModeActive: shadowModeActive ?? this.shadowModeActive,
      reason: reason ?? this.reason,
      activatedAt: activatedAt ?? this.activatedAt,
    );
  }
}

/// Notifier for security state management.
class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier() : super(const SecurityState());

  /// Activate shadow mode with enhanced protection.
  void activateShadowMode({String? reason}) {
    state = state.copyWith(
      shadowModeActive: true,
      reason: reason ?? 'Anomaly detected',
      activatedAt: DateTime.now(),
    );
  }

  /// Deactivate shadow mode when threat is cleared.
  void deactivateShadowMode() {
    state = const SecurityState(shadowModeActive: false);
  }

  /// Toggle shadow mode for testing purposes.
  void toggleShadowMode() {
    if (state.shadowModeActive) {
      deactivateShadowMode();
    } else {
      activateShadowMode(reason: 'Manually activated');
    }
  }
}

/// Provider for security state.
final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier();
});

/// Convenience provider for shadow mode status.
final shadowModeActiveProvider = Provider<bool>((ref) {
  return ref.watch(securityProvider).shadowModeActive;
});
