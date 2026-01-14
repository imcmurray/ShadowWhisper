import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'p2p_message.dart';
import 'peer_connection.dart';
import 'signaling_client.dart';

/// Manages P2P connections for a room.
class P2PManager {
  final String signalingServerUrl;

  SignalingClient? _signalingClient;
  final Map<String, PeerConnection> _peers = {};
  String? _localPeerId;
  String? _localDisplayName;

  final _messageController = StreamController<P2PMessage>.broadcast();
  final _connectionStateController = StreamController<P2PConnectionEvent>.broadcast();
  StreamSubscription<SignalingMessage>? _signalingSubscription;

  P2PManager({required this.signalingServerUrl});

  /// Stream of P2P messages from all peers.
  Stream<P2PMessage> get messages => _messageController.stream;

  /// Stream of connection events.
  Stream<P2PConnectionEvent> get connectionEvents => _connectionStateController.stream;

  /// Our local peer ID.
  String? get localPeerId => _localPeerId;

  /// List of connected peer IDs.
  List<String> get connectedPeers => _peers.keys.toList();

  /// Join a room and start connecting to peers.
  Future<void> joinRoom({
    required String roomCode,
    required String peerId,
    required String displayName,
  }) async {
    _localPeerId = peerId;
    _localDisplayName = displayName;

    _signalingClient = SignalingClient(serverUrl: signalingServerUrl);

    _signalingSubscription = _signalingClient!.messages.listen(_handleSignalingMessage);

    await _signalingClient!.connect(roomCode, peerId);
  }

  /// Send a chat message to all connected peers.
  void sendChatMessage({
    required String messageId,
    required String content,
  }) {
    if (_localPeerId == null || _localDisplayName == null) return;

    final message = P2PMessage.chat(
      senderId: _localPeerId!,
      messageId: messageId,
      content: content,
      displayName: _localDisplayName!,
    );

    _broadcast(message);
  }

  /// Send a typing indicator to all connected peers.
  void sendTypingIndicator(bool isTyping) {
    if (_localPeerId == null) return;

    final message = P2PMessage.typing(
      senderId: _localPeerId!,
      isTyping: isTyping,
    );

    _broadcast(message);
  }

  /// Leave the room and disconnect from all peers.
  Future<void> leaveRoom() async {
    if (_localPeerId != null) {
      final goodbye = P2PMessage.goodbye(senderId: _localPeerId!);
      _broadcast(goodbye);
    }

    await _signalingSubscription?.cancel();
    _signalingClient?.disconnect();
    _signalingClient?.dispose();
    _signalingClient = null;

    for (final peer in _peers.values) {
      await peer.close();
    }
    _peers.clear();

    _localPeerId = null;
    _localDisplayName = null;
  }

  void _handleSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case SignalingMessageType.peers:
        // We received the list of existing peers - initiate connections to them
        if (message.peers != null) {
          for (final peerId in message.peers!) {
            await _initiateConnection(peerId);
          }
        }
        break;

      case SignalingMessageType.peerJoined:
        // A new peer joined - they will initiate connection to us
        if (message.peerId != null) {
          _connectionStateController.add(P2PConnectionEvent(
            peerId: message.peerId!,
            type: P2PConnectionEventType.peerDiscovered,
          ));
        }
        break;

      case SignalingMessageType.peerLeft:
        // A peer left - clean up their connection
        if (message.peerId != null) {
          await _removePeer(message.peerId!);
        }
        break;

      case SignalingMessageType.offer:
        // Received an offer - handle it
        if (message.peerId != null && message.payload != null) {
          await _handleOffer(message.peerId!, message.payload!);
        }
        break;

      case SignalingMessageType.answer:
        // Received an answer - handle it
        if (message.peerId != null && message.payload != null) {
          await _handleAnswer(message.peerId!, message.payload!);
        }
        break;

      case SignalingMessageType.iceCandidate:
        // Received an ICE candidate - add it
        if (message.peerId != null && message.payload != null) {
          await _handleIceCandidate(message.peerId!, message.payload!);
        }
        break;

      case SignalingMessageType.error:
        print('Signaling error: ${message.error}');
        break;
    }
  }

  Future<void> _initiateConnection(String peerId) async {
    if (_peers.containsKey(peerId) || _localPeerId == null) return;

    final peerConnection = PeerConnection(
      peerId: peerId,
      localPeerId: _localPeerId!,
      onMessage: _handlePeerMessage,
      onIceCandidate: (candidate) {
        _signalingClient?.sendIceCandidate(peerId, candidate);
      },
      onConnectionState: (state) {
        _handleConnectionStateChange(peerId, state);
      },
    );

    _peers[peerId] = peerConnection;
    await peerConnection.initialize();

    // Create and send offer
    final offer = await peerConnection.createOffer();
    _signalingClient?.sendOffer(peerId, offer);

    _connectionStateController.add(P2PConnectionEvent(
      peerId: peerId,
      type: P2PConnectionEventType.connecting,
    ));
  }

  Future<void> _handleOffer(String peerId, Map<String, dynamic> payload) async {
    if (_localPeerId == null) return;

    // Create peer connection if it doesn't exist
    if (!_peers.containsKey(peerId)) {
      final peerConnection = PeerConnection(
        peerId: peerId,
        localPeerId: _localPeerId!,
        onMessage: _handlePeerMessage,
        onIceCandidate: (candidate) {
          _signalingClient?.sendIceCandidate(peerId, candidate);
        },
        onConnectionState: (state) {
          _handleConnectionStateChange(peerId, state);
        },
      );

      _peers[peerId] = peerConnection;
      await peerConnection.initialize();
    }

    final offer = RTCSessionDescription(
      payload['sdp'] as String?,
      payload['type'] as String?,
    );

    final answer = await _peers[peerId]!.handleOffer(offer);
    _signalingClient?.sendAnswer(peerId, answer);
  }

  Future<void> _handleAnswer(String peerId, Map<String, dynamic> payload) async {
    final peerConnection = _peers[peerId];
    if (peerConnection == null) return;

    final answer = RTCSessionDescription(
      payload['sdp'] as String?,
      payload['type'] as String?,
    );

    await peerConnection.handleAnswer(answer);
  }

  Future<void> _handleIceCandidate(String peerId, Map<String, dynamic> payload) async {
    final peerConnection = _peers[peerId];
    if (peerConnection == null) return;

    final candidate = RTCIceCandidate(
      payload['candidate'] as String?,
      payload['sdpMid'] as String?,
      payload['sdpMLineIndex'] as int?,
    );

    await peerConnection.addIceCandidate(candidate);
  }

  void _handlePeerMessage(P2PMessage message) {
    _messageController.add(message);
  }

  void _handleConnectionStateChange(String peerId, RTCPeerConnectionState state) {
    P2PConnectionEventType eventType;

    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        eventType = P2PConnectionEventType.connected;
        // Send hello message
        if (_localPeerId != null && _localDisplayName != null) {
          final hello = P2PMessage.hello(
            senderId: _localPeerId!,
            displayName: _localDisplayName!,
          );
          _peers[peerId]?.sendMessage(hello);
        }
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        eventType = P2PConnectionEventType.disconnected;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        eventType = P2PConnectionEventType.failed;
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        eventType = P2PConnectionEventType.disconnected;
        break;
      default:
        return;
    }

    _connectionStateController.add(P2PConnectionEvent(
      peerId: peerId,
      type: eventType,
    ));
  }

  Future<void> _removePeer(String peerId) async {
    final peerConnection = _peers.remove(peerId);
    await peerConnection?.close();

    _connectionStateController.add(P2PConnectionEvent(
      peerId: peerId,
      type: P2PConnectionEventType.disconnected,
    ));
  }

  void _broadcast(P2PMessage message) {
    for (final peer in _peers.values) {
      peer.sendMessage(message);
    }
  }

  /// Clean up resources.
  void dispose() {
    leaveRoom();
    _messageController.close();
    _connectionStateController.close();
  }
}

/// Types of P2P connection events.
enum P2PConnectionEventType {
  peerDiscovered,
  connecting,
  connected,
  disconnected,
  failed,
}

/// A P2P connection event.
class P2PConnectionEvent {
  final String peerId;
  final P2PConnectionEventType type;

  P2PConnectionEvent({
    required this.peerId,
    required this.type,
  });
}
