import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../room/providers/room_provider.dart';

/// Chat input widget with message field, emoji picker, and send button.
///
/// Features:
/// - 500 character limit with counter
/// - Emoji picker integration
/// - Send on Enter key
/// - Disabled state during sending
class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSending = false;
  bool _wasTyping = false;
  static const int _maxLength = 500;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    // Clear typing status when disposing
    _setTypingStatus(false);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});

    // Update typing status
    final isTyping = _controller.text.isNotEmpty;
    if (isTyping != _wasTyping) {
      _wasTyping = isTyping;
      _setTypingStatus(isTyping);
    }
  }

  void _setTypingStatus(bool isTyping) {
    final peerId = ref.read(currentPeerIdProvider);
    ref.read(roomProvider.notifier).setTyping(peerId, isTyping);
  }

  bool get _canSend {
    final text = _controller.text.trim();
    return text.isNotEmpty && text.length <= _maxLength && !_isSending;
  }

  int get _remainingChars => _maxLength - _controller.text.length;

  Future<void> _sendMessage() async {
    if (!_canSend) return;

    final message = _controller.text.trim();

    setState(() {
      _isSending = true;
    });

    // Get current user info from providers
    final peerId = ref.read(currentPeerIdProvider);
    final displayName = ref.read(currentDisplayNameProvider);

    // Add message to the messages provider
    ref.read(messagesProvider.notifier).addMessage(
      senderPeerId: peerId,
      senderDisplayName: displayName,
      content: message,
    );

    _controller.clear();

    // Clear typing status since message was sent
    _wasTyping = false;
    _setTypingStatus(false);

    setState(() {
      _isSending = false;
    });

    _focusNode.requestFocus();
  }

  void _showEmojiPicker() {
    // TODO: Show emoji picker
    // For now, insert a sample emoji
    final selection = _controller.selection;
    final text = _controller.text;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '\u{1F44D}',
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Character counter
            if (_controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 4),
                child: Text(
                  '$_remainingChars',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _remainingChars < 50
                            ? (_remainingChars < 0
                                ? AppColors.error
                                : AppColors.warning)
                            : AppColors.textSecondary,
                      ),
                ),
              ),

            // Input row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji picker button
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  onPressed: _showEmojiPicker,
                  color: AppColors.textSecondary,
                  tooltip: 'Emoji',
                ),

                // Text field
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: _maxLength,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null, // Hide default counter
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _canSend ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(Icons.send),
                    onPressed: _canSend ? _sendMessage : null,
                    color: _canSend
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
