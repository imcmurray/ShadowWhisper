/// Application-wide constants for ShadowWhisper.
///
/// Centralizes magic numbers and configuration values for easier maintenance.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // Room limits
  static const int maxParticipants = 20;
  static const int maxMessageLength = 500;
  static const int maxNotifications = 100;

  // Timeouts and intervals
  static const Duration reconnectionGracePeriod = Duration(seconds: 30);
  static const Duration timeoutCheckInterval = Duration(seconds: 1);
  static const Duration sessionCleanupInterval = Duration(minutes: 5);

  // Rate limiting
  static const int maxMessagesPerSecond = 5;
  static const int maxTypingUpdatesPerSecond = 2;
  static const Duration rateLimitWindow = Duration(seconds: 1);

  // P2P networking
  static const int typingDebounceMs = 300;
  static const int maxRetransmits = 30;

  // UI
  static const int characterCountWarningThreshold = 50;
}
