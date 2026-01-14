import 'dart:async';
import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'p2p_message.dart';

/// Callback for when a P2P message is received.
typedef OnMessageCallback = void Function(P2PMessage message);

/// Callback for when connection state changes.
typedef OnConnectionStateCallback = void Function(RTCPeerConnectionState state);

/// Callback for when an ICE candidate is generated.
typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);

/// WebRTC configuration for peer connections.
const Map<String, dynamic> webRtcConfiguration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
};

/// A wrapper around RTCPeerConnection for managing P2P connections.
class PeerConnection {
  final String peerId;
  final String localPeerId;
  final OnMessageCallback onMessage;
  final OnConnectionStateCallback? onConnectionState;
  final OnIceCandidateCallback onIceCandidate;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  bool _isInitiator = false;

  PeerConnection({
    required this.peerId,
    required this.localPeerId,
    required this.onMessage,
    required this.onIceCandidate,
    this.onConnectionState,
  });

  /// Whether the data channel is open and ready for messages.
  bool get isConnected =>
      _dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen;

  /// Initialize the peer connection.
  Future<void> initialize() async {
    _peerConnection = await createPeerConnection(webRtcConfiguration);

    _peerConnection!.onIceCandidate = (candidate) {
      onIceCandidate(candidate);
    };

    _peerConnection!.onConnectionState = (state) {
      print('Peer $peerId connection state: $state');
      onConnectionState?.call(state);
    };

    _peerConnection!.onDataChannel = (channel) {
      _setupDataChannel(channel);
    };
  }

  /// Create an offer to initiate a connection (caller side).
  Future<RTCSessionDescription> createOffer() async {
    _isInitiator = true;

    // Create data channel before creating offer
    final channelInit = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30;

    _dataChannel = await _peerConnection!.createDataChannel('messages', channelInit);
    _setupDataChannel(_dataChannel!);

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    return offer;
  }

  /// Handle a received offer and create an answer (callee side).
  Future<RTCSessionDescription> handleOffer(RTCSessionDescription offer) async {
    _isInitiator = false;

    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    return answer;
  }

  /// Handle a received answer (caller side).
  Future<void> handleAnswer(RTCSessionDescription answer) async {
    await _peerConnection!.setRemoteDescription(answer);
  }

  /// Add a received ICE candidate.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  /// Send a P2P message through the data channel.
  void sendMessage(P2PMessage message) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      final jsonString = jsonEncode(message.toJson());
      _dataChannel!.send(RTCDataChannelMessage(jsonString));
    } else {
      print('Cannot send message: data channel not open for peer $peerId');
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    channel.onMessage = (message) {
      try {
        final json = jsonDecode(message.text) as Map<String, dynamic>;
        final p2pMessage = P2PMessage.fromJson(json);
        onMessage(p2pMessage);
      } catch (error) {
        print('Error parsing P2P message: $error');
      }
    };

    channel.onDataChannelState = (state) {
      print('Data channel state for peer $peerId: $state');
    };
  }

  /// Close the peer connection and clean up resources.
  Future<void> close() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _dataChannel = null;
    _peerConnection = null;
  }
}
