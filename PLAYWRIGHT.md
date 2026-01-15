# Playwright E2E Testing with Docker

This project is configured to run Playwright tests in a Docker container using the official Playwright image.

## Quick Start

### Run Tests

```bash
./run-tests.sh
```

This will:
1. Start the web server
2. Run all Playwright tests in Docker
3. Clean up when done

## Available Commands

### Test Commands

```bash
./run-tests.sh test          # Run all tests (default)
./run-tests.sh test:debug    # Run tests in debug mode
./run-tests.sh report        # Show test report
./run-tests.sh build         # Build the Playwright Docker image
./run-tests.sh clean         # Clean up test artifacts
./run-tests.sh shell         # Open shell in Playwright container
./run-tests.sh help          # Show help
```

### Direct Docker Compose Commands

```bash
# Start web server only
docker-compose up -d web

# Run tests
docker-compose run --rm playwright npm test

# Run specific test file
docker-compose run --rm playwright npm test tests/example.spec.js

# Stop services
docker-compose down
```

## Project Structure

```
.
├── docker-compose.yml           # Orchestrates web server and tests
├── Dockerfile.playwright        # Playwright container image
├── playwright.config.js         # Playwright configuration
├── package.json                 # Node.js dependencies
├── tests/                       # Test files
│   └── example.spec.js          # Sample test
├── test-results/                # Test results (auto-generated)
├── playwright-report/           # HTML reports (auto-generated)
└── run-tests.sh                 # Test runner script
```

## Configuration

### Playwright Config (`playwright.config.js`)

- Tests run on Chromium, Firefox, WebKit, and mobile browsers
- Configured for CI/CD with retries and parallel execution
- Screenshots and videos captured on failure
- HTML and JSON reports generated

### Docker Setup

The setup uses two containers:

1. **Web Server** (`web` service)
   - Runs Node.js server on port 3000
   - Serves the TimeFlow web app
   - Includes health check to ensure it's ready

2. **Playwright** (`playwright` service)
   - Based on `mcr.microsoft.com/playwright:v1.48.0-jammy`
   - Waits for web server to be healthy
   - Runs tests against the web server
   - Shares test results via volumes

## Writing Tests

Create test files in the `tests/` directory:

```javascript
// tests/my-feature.spec.js
const { test, expect } = require('@playwright/test');

test('should test my feature', async ({ page }) => {
  await page.goto('/');
  // Add your test assertions here
});
```

## Viewing Results

### HTML Report

```bash
./run-tests.sh report
```

The report will be available in `playwright-report/index.html`.

### CI/CD Integration

The tests are configured to work in CI environments:

- Set `CI=true` environment variable
- Tests run with retries enabled
- JSON results exported to `test-results/results.json`

## Troubleshooting

### Tests Failing to Connect

If tests can't reach the web server:

```bash
# Check if web server is running
docker-compose ps

# Check web server logs
docker-compose logs web

# Restart services
docker-compose down && ./run-tests.sh
```

### Debugging Tests

```bash
# Open shell in Playwright container
./run-tests.sh shell

# Then run tests manually
npm test
```

### Clean Start

```bash
./run-tests.sh clean
docker-compose down -v
./run-tests.sh build
```

## Browser Options

The configuration tests against:

- Desktop Chrome (Chromium)
- Desktop Firefox
- Desktop Safari (WebKit)
- Mobile Chrome (Pixel 5)
- Mobile Safari (iPhone 12)

To run only specific browsers, modify `playwright.config.js` or use the `--project` flag:

```bash
docker-compose run --rm playwright npm test -- --project=chromium
```

## Performance Notes

- First run will download the Playwright Docker image (~1GB)
- Subsequent runs are faster
- Test results and reports are persisted on the host machine

---

## 🔄 Dual-Browser Testing

ShadowWhisper includes specialized dual-browser tests that simulate two users interacting in real-time. These tests verify P2P communication, room joining, approval workflows, and messaging between participants.

### Quick Start

```bash
# Run the default test (room join)
./tests/e2e/run-dual-tests.sh
```

**Prerequisite**: The Flutter app must be running on port 8080:

```bash
flutter run -d chrome --web-port=8080
```

### Available Test Specs

| Test | Command | Description |
|------|---------|-------------|
| Room Join | `./tests/e2e/run-dual-tests.sh specs/01-room-join.spec.js` | Basic flow: creator makes room, joiner enters with code |
| Approval Mode | `./tests/e2e/run-dual-tests.sh specs/02-approval-mode.spec.js` | Creator approves/rejects join requests |
| Messaging | `./tests/e2e/run-dual-tests.sh specs/03-messaging.spec.js` | Two-way message exchange between participants |

### How It Works

The dual-browser tests use two separate Chromium instances running in Docker:

```
┌─────────────────┐         ┌─────────────────┐
│     Creator     │◄───────►│     Joiner      │
│   (Browser 1)   │   P2P   │   (Browser 2)   │
└─────────────────┘         └─────────────────┘
        │                           │
        └───────────┬───────────────┘
                    ▼
           Flutter App (localhost:8080)
```

1. **Creator** opens the app and creates a room
2. **Room code** is extracted from Creator's screen
3. **Joiner** opens the app and enters the room code
4. **Tests verify** both participants see each other and can communicate

### Project Structure

```
tests/e2e/dual-browser/
├── config/
│   ├── test.config.js      # URLs, timeouts, browser args
│   └── coordinates.js      # Click coordinates for Flutter canvas
├── helpers/
│   ├── browser.js          # Browser setup and navigation
│   ├── flutter.js          # Flutter-specific interactions
│   ├── room.js             # Room creation and joining
│   ├── message.js          # Messaging helpers
│   └── index.js            # Helper exports
└── specs/
    ├── 01-room-join.spec.js
    ├── 02-approval-mode.spec.js
    └── 03-messaging.spec.js
```

### Screenshots

Tests automatically capture screenshots at key points. Find them in:

```
./screenshots/
├── creator-00-landing.png
├── creator-01-room-created.png
├── joiner-00-landing.png
├── joiner-01-entering-code.png
└── ...
```

### Configuration

Edit `tests/e2e/dual-browser/config/test.config.js` to adjust:

```javascript
module.exports = {
  APP_URL: 'http://172.17.0.1:8080',  // Docker host address
  VIEWPORT: { width: 1280, height: 720 },
  TIMEOUTS: {
    flutterLoad: 60000,    // Initial Flutter load
    p2pConnection: 15000,  // P2P handshake
    messageDelivery: 5000, // Message arrival
    // ...
  },
};
```

### Troubleshooting

**App not detected**
```
ERROR: App is not running on localhost:8080
```
→ Start Flutter: `flutter run -d chrome --web-port=8080`

**Connection timeout**
- Increase `p2pConnection` timeout in config
- Check that signaling server is running
- Verify TURN server configuration

**Click not registering**
- Flutter uses canvas rendering; clicks use coordinates
- Adjust coordinates in `config/coordinates.js` if UI layout changed

**Debug mode**
```bash
# Open shell in the Docker container
docker run -it --rm --network host \
  -v "$(pwd)/tests/e2e/dual-browser:/test/dual-browser" \
  -w /test/dual-browser \
  mcr.microsoft.com/playwright:v1.50.1-noble \
  bash
```

---

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Playwright Docker Guide](https://playwright.dev/docs/docker)
- [Best Practices](https://playwright.dev/docs/best-practices)
