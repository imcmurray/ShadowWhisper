# 🔒 ShadowWhisper

**Zero-Trust Anonymous P2P Ephemeral Group Chat**

ShadowWhisper is a cutting-edge, privacy-first chat application that combines peer-to-peer networking, zero-knowledge proofs, and post-quantum cryptography to deliver truly anonymous, ephemeral communication.

> *No servers. No logs. No traces.*

---

## ✨ Features

### 🛡️ Security First

- **Zero-Knowledge Authentication** - Prove you know the room code without revealing it
- **Post-Quantum Encryption** - Kyber encryption protects against future quantum attacks
- **Perfect Forward Secrecy** - Each message uses unique encryption keys
- **Onion Routing** - Traffic routed through 3-5 anonymous relays

### 💨 Ephemeral by Design

- **In-Memory Only** - Nothing is ever written to disk
- **Messages Disappear** - When you leave, your messages vanish for everyone
- **Room Self-Destruction** - Rooms cease to exist when empty

### 🕸️ Peer-to-Peer

- **No Central Servers** - Direct mesh networking between participants
- **Self-Healing Swarms** - Network adapts to disconnections
- **Gossipsub Protocol** - Efficient message propagation

### 🛡️ Anti-Surveillance

- **Screen Blur** - Activates when window loses focus
- **Shadow Mode** - Enhanced protection on anomaly detection
- **No IP Exposure** - All traffic via Tor hidden services

---

## 🚀 Quick Start

### Prerequisites

- **Flutter SDK** >= 3.16.5
- **Dart SDK** >= 3.2.3
- Modern web browser with WebRTC/WebTransport support

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd ShadowWhisper

# Run the setup script
./init.sh
```

The app will be available at `http://localhost:8080`

### Manual Setup

```bash
# Install dependencies
flutter pub get

# Enable web platform
flutter config --enable-web

# Run the development server
flutter run -d chrome --web-port=8080
```

---

## 📱 Usage

### Creating a Room

1. Click **"Create Room"** on the landing page
2. Enter a room name
3. Optionally enable **Approval Required** mode
4. Share the generated room code with others

### Joining a Room

1. Click **"Join Room"** on the landing page
2. Enter the room code shared with you
3. Wait for ZK proof verification (~5 seconds)
4. If approval mode is enabled, wait for creator approval

### In the Chat

- **Send messages** - Up to 500 characters each
- **Add emoji reactions** - React to any message
- **View participants** - Click the people icon
- **Change display name** - Via settings gear icon
- **Leave room** - Click logout icon (messages will disappear)

---

## 🏗️ Architecture

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root widget with Riverpod
├── core/
│   ├── theme/               # App theme and colors
│   └── routing/             # Navigation configuration
└── features/
    ├── landing/             # Landing page
    ├── room/                # Room creation/joining
    ├── chat/                # Chat interface
    └── settings/            # Settings screen
```

### Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter Web 3.16+ |
| State Management | Riverpod 2.5+ |
| Styling | Material Design (Dark Theme) |
| P2P Networking | dart_libp2p (Gossipsub, DHT) |
| Anonymity | Tor Hidden Services |
| ZK Proofs | circom_witnesscalc_flutter |
| Encryption | Kyber (Post-Quantum) + Ed25519 |

---

## 🔐 Security Model

### Room Code Flow

```
Room Code → Argon2 Hash → Swarm ID → P2P Discovery
     ↓
ZK Proof Generation → Verification → Room Access
```

### Message Encryption

1. **Key Exchange** - Kyber post-quantum + Diffie-Hellman
2. **Message Encryption** - AES-256-GCM
3. **Transport** - Tor onion routing (3-5 hops)

### DoS Protection

- Light proof-of-work (~5s) required for room joins
- libp2p peer scoring for reputation management
- Maximum 20 participants per room
- Bad actors automatically pruned from mesh

---

## 🧪 Testing

The project includes 90 comprehensive feature tests covering:

- Security & Access Control
- Navigation Integrity
- Real Data Verification
- Workflow Completeness
- Error Handling
- UI-Backend Integration
- State & Persistence
- And more...

---

## 📄 License

This project is proprietary and confidential.

---

## ⚠️ Disclaimer

ShadowWhisper is designed for legitimate privacy needs. Users are responsible for complying with applicable laws and regulations in their jurisdiction.

---

<p align="center">
  <strong>Built with 🔒 by the ShadowWhisper Team</strong>
</p>
