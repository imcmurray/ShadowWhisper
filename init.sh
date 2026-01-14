#!/usr/bin/env bash
# ShadowWhisper - Development Environment Setup Script
# A zero-trust, anonymous P2P ephemeral group chat application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ShadowWhisper Development Setup                    ║${NC}"
echo -e "${GREEN}║     Zero-Trust Anonymous P2P Ephemeral Chat                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
echo -e "${BLUE}━━━ Checking Prerequisites ━━━${NC}"
echo ""

# Check Flutter
if command_exists flutter; then
    FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n 1 | grep -oP 'Flutter \K[0-9.]+' || echo "unknown")
    print_success "Flutter found: $FLUTTER_VERSION"

    # Check if version is >= 3.16.5
    REQUIRED_VERSION="3.16.5"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$FLUTTER_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        print_success "Flutter version meets requirement (>= $REQUIRED_VERSION)"
    else
        print_warning "Flutter version $FLUTTER_VERSION may be below required $REQUIRED_VERSION"
    fi
else
    print_error "Flutter not found. Please install Flutter SDK >= 3.16.5"
    print_status "Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check Dart
if command_exists dart; then
    DART_VERSION=$(dart --version 2>&1 | grep -oP 'Dart SDK version: \K[0-9.]+' || echo "unknown")
    print_success "Dart found: $DART_VERSION"
else
    print_error "Dart not found. Dart should be included with Flutter SDK."
    exit 1
fi

# Check if running in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_warning "pubspec.yaml not found. Creating Flutter project structure..."

    # Check if we're in the ShadowWhisper directory
    if [[ "$(basename "$(pwd)")" != "ShadowWhisper" ]]; then
        print_error "Please run this script from the ShadowWhisper project directory"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}━━━ Setting Up Project ━━━${NC}"
echo ""

# Create Flutter project if pubspec.yaml doesn't exist
if [ ! -f "pubspec.yaml" ]; then
    print_status "Initializing Flutter project..."

    # Create pubspec.yaml
    cat > pubspec.yaml << 'EOF'
name: shadow_whisper
description: A zero-trust, anonymous P2P ephemeral group chat application built on the ShadowSwarm Protocol.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.3 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Cryptography
  cryptography: ^2.7.2

  # UI Components
  cupertino_icons: ^1.0.8

  # Note: The following packages are specified in the spec but may need
  # custom implementations or alternatives for web:
  # - dart_libp2p (P2P networking)
  # - tor_hidden_service (Tor integration)
  # - circom_witnesscalc_flutter (ZK proofs)
  # - flutter_webrtc (WebRTC fallback)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.3

flutter:
  uses-material-design: true

  # Assets will be added as development progresses
  # assets:
  #   - assets/images/
  #   - assets/fonts/
EOF
    print_success "Created pubspec.yaml"
fi

# Get Flutter dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Enable web support
print_status "Ensuring web platform is enabled..."
flutter config --enable-web

echo ""
echo -e "${BLUE}━━━ Development Server ━━━${NC}"
echo ""

# Check for Chrome/Chromium
if command_exists google-chrome || command_exists chromium || command_exists chromium-browser; then
    print_success "Chrome/Chromium browser detected"
else
    print_warning "Chrome/Chromium not detected. Flutter web may use a different browser."
fi

# Start the development server
print_status "Starting Flutter Web development server..."
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ShadowWhisper                              ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  The app will be available at:                                ║${NC}"
echo -e "${GREEN}║  ${YELLOW}http://localhost:8080${GREEN}                                        ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║  Press ${YELLOW}q${GREEN} to quit the development server                       ║${NC}"
echo -e "${GREEN}║  Press ${YELLOW}r${GREEN} to hot reload                                        ║${NC}"
echo -e "${GREEN}║  Press ${YELLOW}R${GREEN} to hot restart                                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Run Flutter web
flutter run -d chrome --web-port=8080 2>/dev/null || flutter run -d web-server --web-port=8080
