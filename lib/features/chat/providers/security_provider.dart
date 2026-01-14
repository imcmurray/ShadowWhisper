import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connection state for network status tracking.
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
}

/// Connection status with user-friendly messaging.
class ConnectionStatus {
  final ConnectionState state;
  final String message;
  final DateTime? lastConnected;

  const ConnectionStatus({
    this.state = ConnectionState.connected,
    this.message = 'Connected to secure mesh',
    this.lastConnected,
  });

  ConnectionStatus copyWith({
    ConnectionState? state,
    String? message,
    DateTime? lastConnected,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  /// User-friendly message for the current connection state
  String get friendlyMessage {
    switch (state) {
      case ConnectionState.connected:
        return 'Connected securely';
      case ConnectionState.connecting:
        return 'Establishing secure connection...';
      case ConnectionState.disconnected:
        return 'Connection lost. Check your internet connection.';
      case ConnectionState.reconnecting:
        return 'Reconnecting to secure mesh...';
    }
  }

  bool get isConnected => state == ConnectionState.connected;
  bool get isDisconnected => state == ConnectionState.disconnected;
}

/// Notifier for connection status management.
class ConnectionNotifier extends StateNotifier<ConnectionStatus> {
  ConnectionNotifier() : super(const ConnectionStatus());

  /// Set connection as established
  void setConnected() {
    state = ConnectionStatus(
      state: ConnectionState.connected,
      message: 'Connected to secure mesh',
      lastConnected: DateTime.now(),
    );
  }

  /// Set connection as connecting
  void setConnecting() {
    state = state.copyWith(
      state: ConnectionState.connecting,
      message: 'Establishing secure connection...',
    );
  }

  /// Set connection as disconnected with optional reason
  void setDisconnected({String? reason}) {
    state = state.copyWith(
      state: ConnectionState.disconnected,
      message: reason ?? 'Connection lost. Check your internet connection.',
    );
  }

  /// Set connection as reconnecting
  void setReconnecting() {
    state = state.copyWith(
      state: ConnectionState.reconnecting,
      message: 'Reconnecting to secure mesh...',
    );
  }

  /// Simulate a network error (for testing)
  void simulateNetworkError() {
    setDisconnected(reason: 'Unable to connect. Please check your internet connection and try again.');
  }
}

/// Provider for connection status.
final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionStatus>((ref) {
  return ConnectionNotifier();
});

/// Convenience provider for checking if connected.
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});

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
