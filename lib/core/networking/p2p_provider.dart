import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/room/providers/room_provider.dart';
import 'p2p_manager.dart';
import 'p2p_message.dart';

/// Signaling server URL
const String signalingServerUrl = 'wss://shadowwhisper-signaling.ianmc.workers.dev';

/// P2P connection state
enum P2PState {
  disconnected,
  connecting,
  connected,
  error,
}

/// P2P provider state
class P2PProviderState {
  final P2PState state;
  final String? errorMessage;
  final List<String> connectedPeers;

  const P2PProviderState({
    this.state = P2PState.disconnected,
    this.errorMessage,
    this.connectedPeers = const [],
  });

  P2PProviderState copyWith({
    P2PState? state,
    String? errorMessage,
    List<String>? connectedPeers,
  }) {
    return P2PProviderState(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      connectedPeers: connectedPeers ?? this.connectedPeers,
    );
  }
}

/// P2P state notifier provider
final p2pProvider = StateNotifierProvider<P2PNotifier, P2PProviderState>((ref) {
  return P2PNotifier(ref);
});

/// P2P state notifier
class P2PNotifier extends StateNotifier<P2PProviderState> {
  final Ref _ref;
  P2PManager? _manager;
  StreamSubscription<P2PMessage>? _messageSubscription;
  StreamSubscription<P2PConnectionEvent>? _connectionSubscription;
  bool _isDisposed = false;

  P2PNotifier(this._ref) : super(const P2PProviderState());

  /// Connect to a room via P2P
  Future<void> connect({
    required String roomCode,
  }) async {
    if (_manager != null) {
      await disconnect();
    }

    state = state.copyWith(state: P2PState.connecting);

    try {
      final peerId = _ref.read(currentPeerIdProvider);
      final displayName = _ref.read(currentDisplayNameProvider);

      _manager = P2PManager(signalingServerUrl: signalingServerUrl);

      // Listen for P2P messages
      _messageSubscription = _manager!.messages.listen(_handleMessage);

      // Listen for connection events
      _connectionSubscription = _manager!.connectionEvents.listen(_handleConnectionEvent);

      await _manager!.joinRoom(
        roomCode: roomCode,
        peerId: peerId,
        displayName: displayName,
      );

      state = state.copyWith(state: P2PState.connected);
    } catch (error) {
      state = state.copyWith(
        state: P2PState.error,
        errorMessage: error.toString(),
      );
    }
  }

  /// Disconnect from P2P
  Future<void> disconnect() async {
    await _messageSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _manager?.leaveRoom();
    _manager?.dispose();
    _manager = null;

    state = const P2PProviderState();
  }

  /// Send a chat message via P2P
  void sendChatMessage({
    required String messageId,
    required String content,
  }) {
    _manager?.sendChatMessage(
      messageId: messageId,
      content: content,
    );
  }

  /// Send typing indicator via P2P
  void sendTypingIndicator(bool isTyping) {
    _manager?.sendTypingIndicator(isTyping);
  }

  void _handleMessage(P2PMessage message) {
    // Guard against callbacks after disposal
    if (_isDisposed) return;

    try {
      switch (message.type) {
        case P2PMessageType.hello:
          // A peer said hello - they're connected
          final displayName = message.payload['displayName'] as String?;
          if (displayName != null) {
            // Add them as a participant if not already present
            _ref.read(roomProvider.notifier).addRemoteParticipant(
              peerId: message.senderId,
              displayName: displayName,
            );
          }
          break;

        case P2PMessageType.goodbye:
          // A peer is leaving
          _ref.read(roomProvider.notifier).removeRemoteParticipant(message.senderId);
          break;

        case P2PMessageType.chatMessage:
          // Received a chat message
          final content = message.payload['content'] as String?;
          final displayName = message.payload['displayName'] as String?;
          if (content != null && displayName != null) {
            _ref.read(messagesProvider.notifier).addMessage(
              senderPeerId: message.senderId,
              senderDisplayName: displayName,
              content: content,
            );
          }
          break;

        case P2PMessageType.typingStart:
          _ref.read(roomProvider.notifier).setTyping(message.senderId, true);
          break;

        case P2PMessageType.typingStop:
          _ref.read(roomProvider.notifier).setTyping(message.senderId, false);
          break;

        default:
          // Handle other message types as needed
          break;
      }
    } catch (error) {
      // Provider might be disposed, ignore errors during cleanup
      print('Error handling P2P message: $error');
    }
  }

  void _handleConnectionEvent(P2PConnectionEvent event) {
    // Guard against callbacks after disposal
    if (_isDisposed) return;

    try {
      switch (event.type) {
        case P2PConnectionEventType.connected:
          final peers = [...state.connectedPeers, event.peerId];
          state = state.copyWith(connectedPeers: peers);
          break;

        case P2PConnectionEventType.disconnected:
        case P2PConnectionEventType.failed:
          final peers = state.connectedPeers.where((p) => p != event.peerId).toList();
          state = state.copyWith(connectedPeers: peers);
          // Mark participant as disconnected
          _ref.read(roomProvider.notifier).markParticipantDisconnected(event.peerId);
          break;

        default:
          break;
      }
    } catch (error) {
      // Provider might be disposed, ignore errors during cleanup
      print('Error handling connection event: $error');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    super.dispose();
  }
}
