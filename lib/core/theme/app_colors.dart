import 'package:flutter/material.dart';

/// Color palette for ShadowWhisper.
///
/// Based on the design system specification:
/// - Dark theme with green "secure" accent
/// - High contrast for accessibility
/// - Consistent visual hierarchy
class AppColors {
  AppColors._();

  /// Primary green - secure/trust indicator
  /// Used for primary actions, security elements, and success states
  static const Color primary = Color(0xFF10B981);

  /// Dark background - main app background
  static const Color background = Color(0xFF0F0F0F);

  /// Alternative background (slightly lighter)
  static const Color backgroundAlt = Color(0xFF121212);

  /// Surface color - cards, dialogs, elevated surfaces
  static const Color surface = Color(0xFF1E1E1E);

  /// Primary text - white for maximum readability
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text - gray for less emphasis
  static const Color textSecondary = Color(0xFF9CA3AF);

  /// Error color - red for destructive actions and errors
  static const Color error = Color(0xFFEF4444);

  /// Warning color - amber for caution states
  static const Color warning = Color(0xFFF59E0B);

  /// Success color - same as primary green
  static const Color success = Color(0xFF10B981);

  /// Online status indicator
  static const Color online = Color(0xFF10B981);

  /// Offline/disconnected status
  static const Color offline = Color(0xFF6B7280);

  /// Typing indicator color
  static const Color typing = Color(0xFF3B82F6);

  /// Message bubble - own messages
  static const Color messageSent = Color(0xFF10B981);

  /// Message bubble - received messages
  static const Color messageReceived = Color(0xFF374151);

  /// Shadow mode indicator - enhanced security active
  static const Color shadowMode = Color(0xFF8B5CF6);

  /// Blur overlay color for anti-surveillance
  static const Color blurOverlay = Color(0xE60F0F0F);
}
