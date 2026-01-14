import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/providers/room_provider.dart';
import '../../../room/domain/chat_message.dart';

/// Scrollable list of chat messages.
///
/// Features:
/// - Newest messages at bottom
/// - Auto-scroll to new messages
/// - Emoji-only messages display larger
/// - Message reactions
/// - Typing indicators
/// - Seen/delivered status
class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final ScrollController _scrollController = ScrollController();
  int _previousMessageCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final currentPeerId = ref.watch(currentPeerIdProvider);

    // Auto-scroll to bottom when new messages arrive
    if (messages.length > _previousMessageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _previousMessageCount = messages.length;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showSenderInfo = index == 0 ||
            messages[index - 1].senderPeerId != message.senderPeerId;

        return _MessageBubble(
          message: message,
          currentPeerId: currentPeerId,
          showSenderInfo: showSenderInfo,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

/// Message bubble widget.
class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final String currentPeerId;
  final bool showSenderInfo;

  const _MessageBubble({
    required this.message,
    required this.currentPeerId,
    required this.showSenderInfo,
  });

  bool get _isEmojiOnly {
    // Check if message contains only emoji characters
    final emojiRegex = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\s]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(message.content);
  }

  bool get _isOwnMessage => message.senderPeerId == currentPeerId;
  bool get _isSeen => message.seenBy.isNotEmpty;
  bool get _isDelivered => message.deliveredTo.isNotEmpty;

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '👎'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isRemoved) {
      return _buildRemovedMessage(context);
    }

    final isOwnMessage = _isOwnMessage;

    return Padding(
      padding: EdgeInsets.only(
        top: showSenderInfo ? 12 : 4,
        left: isOwnMessage ? 48 : 0,
        right: isOwnMessage ? 0 : 48,
      ),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender info
          if (showSenderInfo && !isOwnMessage)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                message.senderDisplayName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

          // Message bubble with long press for reactions
          GestureDetector(
            onLongPress: () => _showReactionPicker(context, ref),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _isEmojiOnly ? 8 : 16,
                vertical: _isEmojiOnly ? 4 : 10,
              ),
              decoration: BoxDecoration(
                color: isOwnMessage
                    ? AppColors.messageSent
                    : AppColors.messageReceived,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                  bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Message content
                  Text(
                    message.content,
                    style: _isEmojiOnly
                        ? const TextStyle(fontSize: 32)
                        : Theme.of(context).textTheme.bodyMedium,
                  ),

                  // Timestamp and status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isOwnMessage
                                  ? AppColors.textPrimary.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                            ),
                      ),
                      if (isOwnMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _isSeen
                              ? Icons.done_all
                              : (_isDelivered
                                  ? Icons.done_all
                                  : Icons.done),
                          size: 14,
                          color: _isSeen
                              ? AppColors.textPrimary
                              : AppColors.textPrimary.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Reactions
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: message.reactions.entries.map((entry) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${entry.key} ${entry.value.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemovedMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Text(
          '...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showReactionPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Reaction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _quickReactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    ref.read(messagesProvider.notifier).addReaction(
                      message.messageId,
                      emoji,
                      currentPeerId,
                    );
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
