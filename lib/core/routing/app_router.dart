import 'package:flutter/material.dart';
import '../../features/landing/presentation/landing_screen.dart';
import '../../features/room/presentation/create_room_screen.dart';
import '../../features/room/presentation/join_room_screen.dart';
import '../../features/room/presentation/waiting_room_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

/// App-wide routing configuration.
///
/// Defines all named routes and handles navigation transitions.
class AppRouter {
  AppRouter._();

  // Route names
  static const String landing = '/';
  static const String createRoom = '/create-room';
  static const String joinRoom = '/join-room';
  static const String waitingRoom = '/waiting-room';
  static const String chat = '/chat';
  static const String settings = '/settings';

  /// Generates routes for the application.
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case landing:
        return _buildRoute(const LandingScreen(), routeSettings);

      case createRoom:
        return _buildRoute(const CreateRoomScreen(), routeSettings);

      case joinRoom:
        return _buildRoute(const JoinRoomScreen(), routeSettings);

      case waitingRoom:
        final args = routeSettings.arguments as WaitingRoomArgs?;
        return _buildRoute(
          WaitingRoomScreen(args: args ?? const WaitingRoomArgs()),
          routeSettings,
        );

      case chat:
        final args = routeSettings.arguments as ChatScreenArgs?;
        return _buildRoute(
          ChatScreen(args: args ?? const ChatScreenArgs()),
          routeSettings,
        );

      case settings:
        return _buildModalRoute(const SettingsScreen(), routeSettings);

      default:
        return _buildRoute(
          const _NotFoundScreen(),
          routeSettings,
        );
    }
  }

  /// Builds a standard page route with fade transition.
  static PageRoute<T> _buildRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }

  /// Builds a modal route for overlay screens like Settings.
  static PageRoute<T> _buildModalRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}

/// Arguments for the waiting room screen.
class WaitingRoomArgs {
  final String? roomCode;
  final String? displayName;

  const WaitingRoomArgs({
    this.roomCode,
    this.displayName,
  });
}

/// Arguments for the chat screen.
class ChatScreenArgs {
  final String? roomCode;
  final String? roomName;
  final bool isCreator;
  final bool approvalMode;

  const ChatScreenArgs({
    this.roomCode,
    this.roomName,
    this.isCreator = false,
    this.approvalMode = false,
  });
}

/// 404 Not Found screen.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The page you are looking for does not exist.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRouter.landing,
                  (route) => false,
                );
              },
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
