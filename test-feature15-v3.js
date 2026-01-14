const { chromium } = require('/app/node_modules/playwright');
const path = require('path');

async function testFeature15() {
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

  // Use /test directory for screenshots (same as mounted volume)
  const screenshotDir = '/test';

  try {
    console.log('=== Feature #15: Messages are real and not mocked ===\n');

    // Navigate to app
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });

    // Wait for Flutter to load
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(1000);
      const html = await page.content();
      if (html.includes('flutter-view')) break;
    }
    await page.waitForTimeout(5000);

    // Create and enter a room
    console.log('Step 1: Create and enter a room...');
    await page.mouse.click(640, 655);  // Create Room
    await page.waitForTimeout(3000);
    await page.mouse.click(640, 393);  // Room name input
    await page.waitForTimeout(500);
    await page.keyboard.type('Message Test Room');
    await page.waitForTimeout(1000);
    await page.mouse.click(640, 563);  // Create Room button
    await page.waitForTimeout(3000);
    await page.mouse.click(640, 578);  // Enter Room
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'f15-01-in-chat.png') });
    console.log('  Screenshot: f15-01-in-chat.png');

    // Step 2: Send a unique message
    console.log('\nStep 2: Send unique message...');
    // Click on message input field (at bottom center, y ~683)
    await page.mouse.click(640, 683);
    await page.waitForTimeout(500);

    const uniqueMessage = 'TEST_MSG_' + Date.now();
    console.log('  Sending:', uniqueMessage);
    await page.keyboard.type(uniqueMessage);
    await page.waitForTimeout(500);

    await page.screenshot({ path: path.join(screenshotDir, 'f15-02-message-typed.png') });
    console.log('  Screenshot: f15-02-message-typed.png');

    // Press Enter to send the message
    console.log('  Pressing Enter to send...');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2000);

    await page.screenshot({ path: path.join(screenshotDir, 'f15-03-message-sent.png') });
    console.log('  Screenshot: f15-03-message-sent.png');

    // Also try clicking the send button for good measure
    await page.mouse.click(640, 683);  // Click input again
    await page.waitForTimeout(500);
    await page.keyboard.type('Second test message');
    await page.waitForTimeout(500);

    // The send button is at the right edge of the input area
    await page.mouse.click(1247, 687);
    await page.waitForTimeout(2000);

    await page.screenshot({ path: path.join(screenshotDir, 'f15-04-second-message.png') });
    console.log('  Screenshot: f15-04-second-message.png');

    // Final screenshot
    await page.screenshot({ path: path.join(screenshotDir, 'f15-final-state.png'), fullPage: true });
    console.log('\n  Final screenshot: f15-final-state.png');

    console.log('\n=== Test Complete ===');
    console.log('Verify messages appear in chat');

  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: path.join(screenshotDir, 'f15-error-state.png') }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testFeature15();
