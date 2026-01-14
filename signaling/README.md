# ShadowWhisper Signaling Server

A minimal WebSocket relay for WebRTC signaling. Deployed as a Cloudflare Worker.

## What It Does

- Lets peers join rooms using room codes
- Relays WebRTC offers, answers, and ICE candidates between peers
- **Does NOT store messages** - purely for connection establishment

## Deploy to Cloudflare

1. Install Wrangler CLI:
   ```bash
   npm install -g wrangler
   ```

2. Login to Cloudflare:
   ```bash
   wrangler login
   ```

3. Deploy:
   ```bash
   cd signaling
   wrangler deploy
   ```

4. Note the URL (e.g., `https://shadowwhisper-signaling.YOUR_SUBDOMAIN.workers.dev`)

## Protocol

### Join Room
```json
{ "type": "join", "roomCode": "shadow-abc123", "peerId": "uuid-here" }
```

### Receive Peer List
```json
{ "type": "peers", "peers": ["peer-id-1", "peer-id-2"] }
```

### Send Offer/Answer
```json
{ "type": "offer", "targetPeerId": "peer-id", "payload": { "sdp": "..." } }
{ "type": "answer", "targetPeerId": "peer-id", "payload": { "sdp": "..." } }
```

### Send ICE Candidate
```json
{ "type": "ice-candidate", "targetPeerId": "peer-id", "payload": { "candidate": "..." } }
```

### Peer Events
```json
{ "type": "peer-joined", "peerId": "new-peer-id" }
{ "type": "peer-left", "peerId": "left-peer-id" }
```
