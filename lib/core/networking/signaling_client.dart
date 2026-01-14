import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Signaling message types from the server.
enum SignalingMessageType {
  peers,
  peerJoined,
  peerLeft,
  offer,
  answer,
  iceCandidate,
  error,
}

/// A message received from the signaling server.
class SignalingMessage {
  final SignalingMessageType type;
  final String? peerId;
  final List<String>? peers;
  final Map<String, dynamic>? payload;
  final String? error;

  SignalingMessage({
    required this.type,
    this.peerId,
    this.peers,
    this.payload,
    this.error,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    SignalingMessageType type;

    switch (typeStr) {
      case 'peers':
        type = SignalingMessageType.peers;
        break;
      case 'peer-joined':
        type = SignalingMessageType.peerJoined;
        break;
      case 'peer-left':
        type = SignalingMessageType.peerLeft;
        break;
      case 'offer':
        type = SignalingMessageType.offer;
        break;
      case 'answer':
        type = SignalingMessageType.answer;
        break;
      case 'ice-candidate':
        type = SignalingMessageType.iceCandidate;
        break;
      case 'error':
        type = SignalingMessageType.error;
        break;
      default:
        type = SignalingMessageType.error;
    }

    return SignalingMessage(
      type: type,
      peerId: json['peerId'] as String? ?? json['fromPeerId'] as String?,
      peers: (json['peers'] as List<dynamic>?)?.cast<String>(),
      payload: json['payload'] as Map<String, dynamic>?,
      error: json['message'] as String?,
    );
  }
}

/// Client for connecting to the signaling server.
class SignalingClient {
  final String serverUrl;

  WebSocketChannel? _channel;
  final _messageController = StreamController<SignalingMessage>.broadcast();

  String? _peerId;
  String? _roomCode;

  SignalingClient({required this.serverUrl});

  /// Stream of messages from the signaling server.
  Stream<SignalingMessage> get messages => _messageController.stream;

  /// Whether we're connected to the signaling server.
  bool get isConnected => _channel != null;

  /// Our peer ID.
  String? get peerId => _peerId;

  /// Connect to the signaling server and join a room.
  Future<void> connect(String roomCode, String peerId) async {
    _peerId = peerId;
    _roomCode = roomCode;

    final uri = Uri.parse(serverUrl);
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final message = SignalingMessage.fromJson(json);
          _messageController.add(message);
        } catch (error) {
          print('Error parsing signaling message: $error');
        }
      },
      onError: (error) {
        print('Signaling WebSocket error: $error');
      },
      onDone: () {
        print('Signaling WebSocket closed');
        _channel = null;
      },
    );

    // Wait for connection to establish
    await Future.delayed(const Duration(milliseconds: 100));

    // Join the room
    _send({
      'type': 'join',
      'roomCode': roomCode,
      'peerId': peerId,
    });
  }

  /// Send an SDP offer to a specific peer.
  void sendOffer(String targetPeerId, RTCSessionDescription offer) {
    _send({
      'type': 'offer',
      'targetPeerId': targetPeerId,
      'payload': {
        'sdp': offer.sdp,
        'type': offer.type,
      },
    });
  }

  /// Send an SDP answer to a specific peer.
  void sendAnswer(String targetPeerId, RTCSessionDescription answer) {
    _send({
      'type': 'answer',
      'targetPeerId': targetPeerId,
      'payload': {
        'sdp': answer.sdp,
        'type': answer.type,
      },
    });
  }

  /// Send an ICE candidate to a specific peer.
  void sendIceCandidate(String targetPeerId, RTCIceCandidate candidate) {
    _send({
      'type': 'ice-candidate',
      'targetPeerId': targetPeerId,
      'payload': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    });
  }

  /// Disconnect from the signaling server.
  void disconnect() {
    if (_channel != null) {
      _send({'type': 'leave'});
      _channel!.sink.close();
      _channel = null;
    }
    _peerId = null;
    _roomCode = null;
  }

  void _send(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Clean up resources.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
