/**
 * ShadowWhisper Signaling Server
 *
 * A simple WebSocket relay for WebRTC signaling.
 * Peers join rooms and exchange SDP offers/answers and ICE candidates.
 * No messages are stored - this is purely for connection establishment.
 */

// In-memory room storage (reset on worker restart, which is fine for signaling)
const rooms = new Map();

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Handle WebSocket upgrade
    if (request.headers.get('Upgrade') === 'websocket') {
      return handleWebSocket(request);
    }

    // Health check endpoint
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', rooms: rooms.size }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        }
      });
    }

    return new Response('ShadowWhisper Signaling Server. Connect via WebSocket.', {
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};

async function handleWebSocket(request) {
  const pair = new WebSocketPair();
  const [client, server] = Object.values(pair);

  server.accept();

  const peer = {
    id: null,
    roomCode: null,
    ws: server
  };

  server.addEventListener('message', (event) => {
    try {
      const message = JSON.parse(event.data);
      handleMessage(peer, message);
    } catch (error) {
      console.error('Invalid message:', error);
    }
  });

  server.addEventListener('close', () => {
    handleDisconnect(peer);
  });

  server.addEventListener('error', (error) => {
    console.error('WebSocket error:', error);
    handleDisconnect(peer);
  });

  return new Response(null, {
    status: 101,
    webSocket: client,
  });
}

function handleMessage(peer, message) {
  switch (message.type) {
    case 'join':
      handleJoin(peer, message);
      break;
    case 'offer':
    case 'answer':
    case 'ice-candidate':
      handleSignaling(peer, message);
      break;
    case 'leave':
      handleDisconnect(peer);
      break;
    default:
      console.log('Unknown message type:', message.type);
  }
}

function handleJoin(peer, message) {
  const { roomCode, peerId } = message;

  if (!roomCode || !peerId) {
    peer.ws.send(JSON.stringify({ type: 'error', message: 'Missing roomCode or peerId' }));
    return;
  }

  peer.id = peerId;
  peer.roomCode = roomCode;

  // Get or create room
  if (!rooms.has(roomCode)) {
    rooms.set(roomCode, new Map());
  }

  const room = rooms.get(roomCode);

  // Get existing peers before adding new one
  const existingPeers = Array.from(room.keys());

  // Add peer to room
  room.set(peerId, peer);

  // Send list of existing peers to the new joiner
  peer.ws.send(JSON.stringify({
    type: 'peers',
    peers: existingPeers
  }));

  // Notify existing peers about the new joiner
  for (const [existingPeerId, existingPeer] of room) {
    if (existingPeerId !== peerId) {
      existingPeer.ws.send(JSON.stringify({
        type: 'peer-joined',
        peerId: peerId
      }));
    }
  }

  console.log(`Peer ${peerId} joined room ${roomCode}. Room size: ${room.size}`);
}

function handleSignaling(peer, message) {
  if (!peer.roomCode || !peer.id) {
    peer.ws.send(JSON.stringify({ type: 'error', message: 'Not in a room' }));
    return;
  }

  const room = rooms.get(peer.roomCode);
  if (!room) return;

  const targetPeer = room.get(message.targetPeerId);
  if (!targetPeer) {
    peer.ws.send(JSON.stringify({
      type: 'error',
      message: `Peer ${message.targetPeerId} not found`
    }));
    return;
  }

  // Relay the message to the target peer
  targetPeer.ws.send(JSON.stringify({
    type: message.type,
    fromPeerId: peer.id,
    payload: message.payload
  }));
}

function handleDisconnect(peer) {
  if (!peer.roomCode || !peer.id) return;

  const room = rooms.get(peer.roomCode);
  if (!room) return;

  // Remove peer from room
  room.delete(peer.id);

  // Notify remaining peers
  for (const [, remainingPeer] of room) {
    remainingPeer.ws.send(JSON.stringify({
      type: 'peer-left',
      peerId: peer.id
    }));
  }

  // Clean up empty rooms
  if (room.size === 0) {
    rooms.delete(peer.roomCode);
  }

  console.log(`Peer ${peer.id} left room ${peer.roomCode}`);

  peer.roomCode = null;
  peer.id = null;
}
