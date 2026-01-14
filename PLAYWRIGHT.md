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

## Resources

- [Playwright Documentation](https://playwright.dev)
- [Playwright Docker Guide](https://playwright.dev/docs/docker)
- [Best Practices](https://playwright.dev/docs/best-practices)
