const { chromium } = require('/app/node_modules/playwright');

async function testFeature3() {
  const browser = await chromium.launch({
    executablePath: '/ms-playwright/chromium-1202/chrome-linux64/chrome',
    headless: false,
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--single-process',
      '--disable-gpu',
    ]
  });

  const page = await browser.newPage();
  await page.setViewportSize({ width: 1280, height: 720 });

  try {
    console.log('=== Feature #3: ZK proof required for room join ===\n');

    // Navigate to app
    console.log('Step 1: Navigate to Join Room screen...');
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });

    // Wait for Flutter to load
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(1000);
      const html = await page.content();
      if (html.includes('flutter-view')) break;
    }
    await page.waitForTimeout(5000);

    // Click Join Room button
    await page.mouse.click(640, 702);
    await page.waitForTimeout(2000);

    await page.screenshot({ path: '/screenshots/f3-01-join-room-screen.png' });
    console.log('  Screenshot: f3-01-join-room-screen.png');

    // Step 2: Enter a VALID room code format (for ZK proof test)
    console.log('\nStep 2: Enter a valid room code format...');
    await page.mouse.click(640, 397);  // Room code input
    await page.waitForTimeout(500);
    await page.keyboard.type('shadow-validcode123');  // Valid format: starts with shadow-, >= 10 chars
    await page.waitForTimeout(1000);

    await page.screenshot({ path: '/screenshots/f3-02-code-entered.png' });
    console.log('  Screenshot: f3-02-code-entered.png');

    // Step 3: Click Join and watch for ZK proof generation
    console.log('\nStep 3: Verify ZK proof generation begins...');
    await page.mouse.click(640, 471);  // Join Room button
    await page.waitForTimeout(500);

    // Take a screenshot during the ZK proof animation
    await page.screenshot({ path: '/screenshots/f3-03-zk-proof-loading-1.png' });
    console.log('  Screenshot: f3-03-zk-proof-loading-1.png');

    await page.waitForTimeout(1500);
    await page.screenshot({ path: '/screenshots/f3-04-zk-proof-loading-2.png' });
    console.log('  Screenshot: f3-04-zk-proof-loading-2.png');

    await page.waitForTimeout(2000);
    await page.screenshot({ path: '/screenshots/f3-05-zk-proof-loading-3.png' });
    console.log('  Screenshot: f3-05-zk-proof-loading-3.png');

    // Wait for full ZK proof completion
    await page.waitForTimeout(3000);
    await page.screenshot({ path: '/screenshots/f3-06-after-zk-proof.png' });
    console.log('  Screenshot: f3-06-after-zk-proof.png');

    // Step 5: Now test invalid room code
    console.log('\nStep 5: Test invalid room code...');

    // Go back to landing
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });
    await page.waitForTimeout(5000);

    // Click Join Room
    await page.mouse.click(640, 702);
    await page.waitForTimeout(2000);

    // Enter an INVALID room code (doesn't start with shadow- or too short)
    await page.mouse.click(640, 397);  // Room code input
    await page.waitForTimeout(500);
    await page.keyboard.type('invalid');  // Invalid: doesn't match shadow-xxxxxx pattern
    await page.waitForTimeout(1000);

    await page.screenshot({ path: '/screenshots/f3-07-invalid-code-entered.png' });

    // Click Join
    await page.mouse.click(640, 471);
    await page.waitForTimeout(7000);  // Wait for ZK proof animation

    // Step 6: Verify generic "Room not found" error
    console.log('\nStep 6: Verify generic error message...');
    await page.screenshot({ path: '/screenshots/f3-08-error-message.png' });
    console.log('  Screenshot: f3-08-error-message.png');

    // Final screenshot
    await page.screenshot({ path: '/screenshots/f3-final-state.png', fullPage: true });
    console.log('\n  Final screenshot: f3-final-state.png');

    console.log('\n=== Feature #3 Test Results ===');
    console.log('Check screenshots for:');
    console.log('- ZK proof loading indicator with progress percentage');
    console.log('- "Computing proof-of-work...", "Generating ZK proof..." messages');
    console.log('- Generic "Room not found" error (no code details leaked)');
    console.log('\n=== Test Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: '/screenshots/f3-error-state.png' }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testFeature3();
