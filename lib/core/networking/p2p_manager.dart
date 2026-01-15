import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

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
  String? _localRoomName;
  bool _isCreator = false;
  Map<String, dynamic>? _iceServersConfig;

  final _messageController = StreamController<P2PMessage>.broadcast();
  final _connectionStateController = StreamController<P2PConnectionEvent>.broadcast();
  StreamSubscription<SignalingMessage>? _signalingSubscription;

  P2PManager({required this.signalingServerUrl});

  /// Fetch TURN credentials from the signaling server.
  Future<Map<String, dynamic>?> _fetchTurnCredentials() async {
    try {
      // Convert WebSocket URL to HTTP URL for credentials endpoint
      final httpUrl = signalingServerUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');
      final baseUrl = httpUrl.endsWith('/') ? httpUrl.substring(0, httpUrl.length - 1) : httpUrl;

      final response = await http.get(Uri.parse('$baseUrl/turn-credentials'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _buildIceServersConfig(data);
      } else {
        print('Failed to fetch TURN credentials: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      print('Error fetching TURN credentials: $error');
      return null;
    }
  }

  /// Build ICE servers configuration from Cloudflare TURN response.
  Map<String, dynamic> _buildIceServersConfig(Map<String, dynamic> turnData) {
    final iceServers = turnData['iceServers'] as Map<String, dynamic>?;
    if (iceServers == null) {
      return defaultWebRtcConfiguration;
    }

    final urls = iceServers['urls'] as List<dynamic>?;
    final username = iceServers['username'] as String?;
    final credential = iceServers['credential'] as String?;

    if (urls == null || urls.isEmpty) {
      return defaultWebRtcConfiguration;
    }

    return {
      'iceServers': [
        // Keep STUN servers as fallback
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        // Add TURN servers with credentials
        {
          'urls': urls.cast<String>(),
          'username': username,
          'credential': credential,
        },
      ],
    };
  }

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
    String? roomName,
    bool isCreator = false,
  }) async {
    _localPeerId = peerId;
    _localDisplayName = displayName;
    _localRoomName = roomName;
    _isCreator = isCreator;

    // Fetch TURN credentials before connecting
    _iceServersConfig = await _fetchTurnCredentials();
    if (_iceServersConfig != null) {
      print('TURN credentials fetched successfully');
    } else {
      print('Using STUN-only configuration (TURN unavailable)');
    }

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
    // Don't connect to self or existing peers
    if (peerId == _localPeerId || _peers.containsKey(peerId) || _localPeerId == null) return;

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
      onDataChannelOpen: () {
        _sendHelloMessage(peerId);
      },
      iceServers: _iceServersConfig,
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
    // Don't handle offers from self
    if (_localPeerId == null || peerId == _localPeerId) return;

    // Glare resolution: if we already have a connection to this peer, use tie-breaker
    // The peer with the lexicographically lower ID becomes the initiator
    if (_peers.containsKey(peerId)) {
      if (_localPeerId!.compareTo(peerId) < 0) {
        // We have lower ID, we should be initiator - ignore their offer
        return;
      } else {
        // They have lower ID, they should be initiator - abandon our connection
        await _peers[peerId]?.close();
        _peers.remove(peerId);
      }
    }

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
        onDataChannelOpen: () {
          _sendHelloMessage(peerId);
        },
        iceServers: _iceServersConfig,
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

  /// Send hello message to a specific peer when data channel opens.
  void _sendHelloMessage(String peerId) {
    if (_localPeerId == null || _localDisplayName == null) return;

    final hello = P2PMessage.hello(
      senderId: _localPeerId!,
      displayName: _localDisplayName!,
      roomName: _localRoomName,
      isCreator: _isCreator,
    );
    _peers[peerId]?.sendMessage(hello);
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
