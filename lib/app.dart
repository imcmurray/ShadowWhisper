import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

/// The root widget for the ShadowWhisper application.
///
/// This sets up the app-wide theme, routing, and any global providers.
class ShadowWhisperApp extends ConsumerWidget {
  const ShadowWhisperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ShadowWhisper',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRouter.landing,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
