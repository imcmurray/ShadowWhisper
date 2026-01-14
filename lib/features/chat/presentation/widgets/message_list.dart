import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Scrollable list of chat messages.
///
/// Features:
/// - Newest messages at bottom
/// - Auto-scroll to new messages
/// - Emoji-only messages display larger
/// - Message reactions
/// - Typing indicators
/// - Seen/delivered status
class MessageList extends StatefulWidget {
  const MessageList({super.key});

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  // TODO: Replace with real messages from Riverpod state
  final List<_Message> _messages = [];

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
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showSenderInfo = index == 0 ||
            _messages[index - 1].senderId != message.senderId;

        return _MessageBubble(
          message: message,
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
class _MessageBubble extends StatelessWidget {
  final _Message message;
  final bool showSenderInfo;

  const _MessageBubble({
    required this.message,
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

  @override
  Widget build(BuildContext context) {
    if (message.isRemoved) {
      return _buildRemovedMessage(context);
    }

    final isOwnMessage = message.isOwn;

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
                message.senderName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

          // Message bubble
          Container(
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
                        message.isSeen
                            ? Icons.done_all
                            : (message.isDelivered
                                ? Icons.done_all
                                : Icons.done),
                        size: 14,
                        color: message.isSeen
                            ? AppColors.textPrimary
                            : AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
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
                      '${entry.key} ${entry.value}',
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
}

/// Message model (temporary, will be replaced with proper model).
class _Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isOwn;
  final bool isDelivered;
  final bool isSeen;
  final bool isRemoved;
  final Map<String, int> reactions;

  _Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isOwn = false,
    this.isDelivered = false,
    this.isSeen = false,
    this.isRemoved = false,
    this.reactions = const {},
  });
}
