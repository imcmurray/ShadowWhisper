import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/providers/room_provider.dart';

/// Typing indicator widget showing who is currently typing.
///
/// Displays names of participants who are typing, up to 3 names
/// with "and N others" for more.
class TypingIndicator extends ConsumerWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use selective provider to only rebuild when typing status changes - PERF FIX 1.2
    final typingParticipants = ref.watch(typingParticipantsProvider);

    if (typingParticipants.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build the typing text
    String typingText;
    if (typingParticipants.length == 1) {
      typingText = '${typingParticipants[0].displayName} is typing...';
    } else if (typingParticipants.length == 2) {
      typingText =
          '${typingParticipants[0].displayName} and ${typingParticipants[1].displayName} are typing...';
    } else if (typingParticipants.length == 3) {
      typingText =
          '${typingParticipants[0].displayName}, ${typingParticipants[1].displayName}, and ${typingParticipants[2].displayName} are typing...';
    } else {
      final others = typingParticipants.length - 2;
      typingText =
          '${typingParticipants[0].displayName}, ${typingParticipants[1].displayName}, and $others others are typing...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Animated dots
          _AnimatedTypingDots(),
          const SizedBox(width: 8),
          // Typing text
          Expanded(
            child: Text(
              typingText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots indicator.
class _AnimatedTypingDots extends StatefulWidget {
  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final offset = (_controller.value + delay) % 1.0;
            final opacity = offset < 0.5 ? offset * 2 : 2 - offset * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity( opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
