# ShadowWhisper Dual-Browser E2E Testing Guide

This guide covers how to write and run end-to-end tests that use two browser contexts to test the P2P chat functionality.

## Quick Start

### Prerequisites

1. **Flutter app running** on localhost:8080:
   ```bash
   flutter run -d chrome --web-port=8080
   ```

2. **Node.js** installed (for running Playwright tests)

3. **Playwright** with Chrome support (handled automatically by helpers)

### Running Tests

```bash
# Navigate to project root
cd /path/to/ShadowWhisper

# Run ALL tests (full regression)
./tests/e2e/run-dual-tests.sh

# Run a specific test (partial name match)
./tests/e2e/run-dual-tests.sh room-join
./tests/e2e/run-dual-tests.sh messaging
./tests/e2e/run-dual-tests.sh approval

# Run all tests in a category
./tests/e2e/run-dual-tests.sh --dir room

# List all available tests
./tests/e2e/run-dual-tests.sh --list

# Show help
./tests/e2e/run-dual-tests.sh --help
```

## Writing New Tests

### Test File Location

Tests live in `tests/e2e/dual-browser/specs/`. Organize by feature:

```
specs/
├── 01-room-join.spec.js      # Basic room joining
├── 02-approval-mode.spec.js  # Approval mode flow
├── 03-messaging.spec.js      # Chat messaging
├── room/                     # Future: room-related tests
├── messaging/                # Future: messaging tests
└── participants/             # Future: participant tests
```

### Test File Format

Every test file must export a module with `name` and `run`:

```javascript
module.exports = {
  name: 'My Test Name',           // Required: Human-readable name
  timeout: 120000,                // Optional: Timeout in ms (default: 120s)

  run: async () => {
    // Your test implementation
  }
};
```

### Using Fixtures (Recommended)

Most tests need two browsers in a connected room. Use fixtures to skip the boilerplate:

```javascript
const { withTwoBrowsersInRoom } = require('../helpers/fixtures');

module.exports = {
  name: 'My Feature Test',

  run: async () => {
    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      // Both browsers are already connected!
      // creator.page and joiner.page are Playwright page objects

      // Your test logic here...
    });
  }
};
```

### Available Fixtures

| Fixture | Description |
|---------|-------------|
| `withTwoBrowsersInRoom` | Two users joined to same room (most common) |
| `withApprovalModeRoom` | Room with approval mode, joiner in waiting room |
| `withCreatorOnly` | Just the creator, no joiner |
| `withThreeBrowsers` | Three participants for multi-user tests |

### Fixture Options

```javascript
await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
  // test logic
}, {
  roomName: 'Custom Room Name',       // Default: 'Test Room'
  screenshotPrefix: 'my-test',        // Default: 'test'
});
```

## Helper Functions

### Room Operations (`helpers/room.js`)

```javascript
const { createRoom, joinRoomWithCode, enterRoom, extractRoomCode } = require('../helpers/room');

// Create a room
await createRoom(page, {
  roomName: 'My Room',
  approvalMode: false,
  screenshotPrefix: 'test',
});

// Extract room code from clipboard
const roomCode = await extractRoomCode(page);

// Enter the room (after creation)
await enterRoom(page, 'screenshotPrefix');

// Join with a code
await joinRoomWithCode(page, roomCode, {
  screenshotPrefix: 'joiner',
});
```

### Messaging (`helpers/message.js`)

```javascript
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');

// Send a message
await sendMessage(page, 'Hello world!', 'screenshotPrefix');

// Wait for P2P delivery
await waitForMessageDelivery(2000);  // Wait 2 seconds
```

### Screenshots (`helpers/flutter.js`)

```javascript
const { takeScreenshot, waitForFlutterLoad } = require('../helpers/flutter');

// Take a screenshot
await takeScreenshot(page, 'step-name', 'prefix');
// Saves to: output/screenshots/prefix-step-name.png

// Wait for Flutter app to load
await waitForFlutterLoad(page);
```

### Console Log Capture (`helpers/console-capture.js`)

```javascript
const { ConsoleCapture, createCapturePair } = require('../helpers/console-capture');

// Capture logs from both browsers
const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

// ... run your test ...

// Check for specific log patterns
if (creatorLogs.contains('[addRemoteParticipant]')) {
  console.log('Connection verified!');
}

// Assert log contains pattern
creatorLogs.assertContains('hello');

// Assert no errors
creatorLogs.assertNoErrors(['acceptable-error']);

// Get all logs
const logs = creatorLogs.getLogs();

// Save to file
await creatorLogs.saveToFile('output/logs/my-test.log');

// Stop capturing
creatorLogs.stop();
```

### Assertions (`helpers/assertions.js`)

```javascript
const {
  assertP2PConnected,
  assertMessageReceived,
  assertLogContains,
  assertNoErrors,
} = require('../helpers/assertions');

// Assert P2P connection established
await assertP2PConnected(creatorLogs, joinerLogs, 15000);

// Assert message was received
await assertMessageReceived(joinerLogs, 'Hello', 10000);

// Assert specific log pattern appears
await assertLogContains(logs, 'connected', 10000, 'WebRTC connection');

// Assert no console errors
assertNoErrors(logs, ['ignored-error-pattern']);
```

## Test Output

After running tests, find outputs in:

```
tests/e2e/dual-browser/output/
├── screenshots/          # Screenshots from test runs
│   ├── creator-01-landing.png
│   ├── joiner-01-landing.png
│   └── ...
├── logs/                 # Console logs (if saved)
│   └── my-test-creator.log
└── reports/
    ├── test-results.json  # Machine-readable results
    └── latest.json        # Same as above, for convenience
```

### JSON Report Format

```json
{
  "timestamp": "2024-01-14T10:30:00.000Z",
  "duration": 45000,
  "summary": {
    "total": 3,
    "passed": 3,
    "failed": 0,
    "skipped": 0
  },
  "tests": [
    {
      "name": "Basic Room Join Flow",
      "file": "01-room-join.spec.js",
      "status": "passed",
      "duration": 15000,
      "error": null
    }
  ]
}
```

## Debugging Failed Tests

### 1. Run the failing test alone

```bash
./tests/e2e/run-dual-tests.sh room-join
```

### 2. Check screenshots

Look in `output/screenshots/` for visual state at each step.

### 3. Check console logs

Add console capture to your test and save logs:

```javascript
const { creatorLogs } = createCapturePair(creator, joiner);

// ... test code ...

// Save logs for debugging
await creatorLogs.saveToFile('output/logs/debug-creator.log');
creatorLogs.print();  // Also print to console
```

### 4. Add Flutter debug logs

In Flutter code, use `print()` - it appears in browser console:

```dart
print('[DEBUG] Current participants: ${participants.length}');
```

Then capture in test:

```javascript
creatorLogs.captureAll();
// ... run test ...
const debugLogs = creatorLogs.getLogsMatching('[DEBUG]');
console.log(debugLogs);
```

### 5. Increase timeouts

If tests fail intermittently, increase wait times:

```javascript
module.exports = {
  name: 'Slow Test',
  timeout: 180000,  // 3 minutes

  run: async () => {
    // Use longer waits
    await page.waitForTimeout(5000);
  }
};
```

## Best Practices

### 1. Use fixtures for common setup

Don't repeat browser setup code. Use `withTwoBrowsersInRoom` or similar.

### 2. Take screenshots at key moments

Screenshots are invaluable for debugging failures:

```javascript
await takeScreenshot(page, '01-before-action', 'test');
await performAction(page);
await takeScreenshot(page, '02-after-action', 'test');
```

### 3. Capture console logs

Always capture logs for P2P debugging:

```javascript
const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);
```

### 4. Clean up in finally blocks

Fixtures handle cleanup, but if writing custom setup:

```javascript
let browsers;
try {
  browsers = await setupBrowserPair();
  // test code
} finally {
  if (browsers) await browsers.cleanup();
}
```

### 5. Keep tests focused

One test should verify one thing. Break complex flows into multiple tests.

### 6. Use descriptive names

Test names should describe the behavior being tested:
- Good: `"Room creator can kick a participant"`
- Bad: `"Test 4"`

## Configuration

Edit `config/test.config.js` to adjust:

```javascript
module.exports = {
  APP_URL: 'http://localhost:8080',

  TIMEOUTS: {
    flutterLoad: 30000,     // Wait for Flutter to boot
    shortWait: 1000,        // Quick pauses
    longWait: 3000,         // Longer pauses
    p2pConnection: 5000,    // P2P connection establishment
    messageDelivery: 2000,  // Message propagation
  },

  VIEWPORT: { width: 800, height: 600 },

  BROWSER_ARGS: [
    '--disable-web-security',
    // ... other args
  ],
};
```

## Coordinate-Based Clicking

Flutter renders to a canvas, so we use coordinates for clicking. Coordinates are defined in `config/coordinates.js`:

```javascript
module.exports = {
  LANDING: {
    createRoomButton: { x: 400, y: 350 },
    joinRoomButton: { x: 400, y: 420 },
  },
  // ...
};
```

To find coordinates:
1. Run Flutter app in Chrome
2. Open DevTools
3. Use the element inspector to find pixel coordinates
4. Add to coordinates.js

## CI Integration

The test runner returns proper exit codes:
- `0` = All tests passed
- `1` = One or more tests failed

Use in CI:

```yaml
- name: Run E2E Tests
  run: |
    flutter run -d chrome --web-port=8080 &
    sleep 30  # Wait for Flutter to start
    ./tests/e2e/run-dual-tests.sh
```

## Troubleshooting

### "App is not running on localhost:8080"

Start the Flutter app first:
```bash
flutter run -d chrome --web-port=8080
```

### "No tests found"

Make sure test files:
1. Are in `specs/` directory
2. End with `.spec.js`
3. Export `name` and `run` properties

### Flaky P2P connections

Increase `p2pConnection` timeout in config, or add explicit waits:
```javascript
await creator.page.waitForTimeout(5000);
```

### Screenshots show wrong state

Flutter renders asynchronously. Add a wait before screenshot:
```javascript
await page.waitForTimeout(500);
await takeScreenshot(page, 'state', 'prefix');
```
