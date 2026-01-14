/**
 * ShadowWhisper Signaling Server
 *
 * A WebSocket relay for WebRTC signaling using Durable Objects.
 * Each room is a Durable Object instance ensuring all peers share state.
 */

// Main worker - routes requests to the appropriate room Durable Object
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check endpoint
    if (url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok' }), {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // TURN credentials endpoint
    if (url.pathname === '/turn-credentials') {
      return generateTurnCredentials(env);
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

    // WebSocket connections must include room code in path: /room/{roomCode}
    if (url.pathname.startsWith('/room/')) {
      const roomCode = url.pathname.split('/room/')[1];
      if (!roomCode) {
        return new Response('Missing room code', { status: 400 });
      }

      // Get or create the Durable Object for this room
      const roomId = env.ROOMS.idFromName(roomCode);
      const room = env.ROOMS.get(roomId);

      // Forward the request to the Durable Object
      return room.fetch(request);
    }

    return new Response('ShadowWhisper Signaling Server. Connect via WebSocket to /room/{roomCode}', {
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};

/**
 * SignalingRoom Durable Object
 *
 * Each instance handles one room. All WebSocket connections to the same room
 * connect to the same Durable Object instance, ensuring shared state.
 */
export class SignalingRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.peers = new Map(); // peerId -> { ws, id }
  }

  async fetch(request) {
    // Handle WebSocket upgrade
    if (request.headers.get('Upgrade') === 'websocket') {
      return this.handleWebSocket(request);
    }

    return new Response('Expected WebSocket', { status: 400 });
  }

  handleWebSocket(request) {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    server.accept();

    const peer = {
      id: null,
      ws: server
    };

    server.addEventListener('message', (event) => {
      try {
        const message = JSON.parse(event.data);
        this.handleMessage(peer, message);
      } catch (error) {
        console.error('Invalid message:', error);
      }
    });

    server.addEventListener('close', () => {
      this.handleDisconnect(peer);
    });

    server.addEventListener('error', (error) => {
      console.error('WebSocket error:', error);
      this.handleDisconnect(peer);
    });

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  handleMessage(peer, message) {
    switch (message.type) {
      case 'join':
        this.handleJoin(peer, message);
        break;
      case 'offer':
      case 'answer':
      case 'ice-candidate':
        this.handleSignaling(peer, message);
        break;
      case 'leave':
        this.handleDisconnect(peer);
        break;
      default:
        console.log('Unknown message type:', message.type);
    }
  }

  handleJoin(peer, message) {
    const { peerId } = message;

    if (!peerId) {
      peer.ws.send(JSON.stringify({ type: 'error', message: 'Missing peerId' }));
      return;
    }

    peer.id = peerId;

    // Get existing peers before adding new one
    const existingPeers = Array.from(this.peers.keys());

    // Add peer to room
    this.peers.set(peerId, peer);

    // Send list of existing peers to the new joiner
    peer.ws.send(JSON.stringify({
      type: 'peers',
      peers: existingPeers
    }));

    // Notify existing peers about the new joiner
    for (const [existingPeerId, existingPeer] of this.peers) {
      if (existingPeerId !== peerId) {
        existingPeer.ws.send(JSON.stringify({
          type: 'peer-joined',
          peerId: peerId
        }));
      }
    }

    console.log(`Peer ${peerId} joined. Room size: ${this.peers.size}`);
  }

  handleSignaling(peer, message) {
    if (!peer.id) {
      peer.ws.send(JSON.stringify({ type: 'error', message: 'Not joined yet' }));
      return;
    }

    const targetPeer = this.peers.get(message.targetPeerId);
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

  handleDisconnect(peer) {
    if (!peer.id) return;

    // Remove peer from room
    this.peers.delete(peer.id);

    // Notify remaining peers
    for (const [, remainingPeer] of this.peers) {
      remainingPeer.ws.send(JSON.stringify({
        type: 'peer-left',
        peerId: peer.id
      }));
    }

    console.log(`Peer ${peer.id} left. Room size: ${this.peers.size}`);

    peer.id = null;
  }
}

/**
 * Generate short-lived TURN credentials from Cloudflare
 */
async function generateTurnCredentials(env) {
  try {
    const response = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${env.TURN_KEY_ID}/credentials/generate`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${env.TURN_KEY_API_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ ttl: 86400 }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('TURN API error:', response.status, errorText);
      return new Response(JSON.stringify({ error: 'Failed to generate TURN credentials' }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      });
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (error) {
    console.error('TURN credentials error:', error);
    return new Response(JSON.stringify({ error: 'Failed to generate TURN credentials' }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
}
