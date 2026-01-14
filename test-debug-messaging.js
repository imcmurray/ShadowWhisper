const { chromium } = require('/app/node_modules/playwright');
const path = require('path');

async function testMessaging() {
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

  const screenshotDir = '/test';

  // Capture console logs
  page.on('console', msg => {
    console.log(`[CONSOLE ${msg.type()}]: ${msg.text()}`);
  });

  page.on('pageerror', error => {
    console.log(`[PAGE ERROR]: ${error.message}`);
  });

  try {
    console.log('=== Debug Messaging Test ===\n');

    // Navigate to app
    console.log('Navigating to app...');
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });

    // Wait for Flutter to load
    console.log('Waiting for Flutter to load...');
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(1000);
      const html = await page.content();
      if (html.includes('flutter-view')) {
        console.log('Flutter view detected!');
        break;
      }
    }
    await page.waitForTimeout(5000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-01-landing.png') });
    console.log('Screenshot: debug-01-landing.png');

    // Create a room
    console.log('\nCreating a room...');
    await page.mouse.click(640, 655);  // Create Room button
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-02-create-screen.png') });
    console.log('Screenshot: debug-02-create-screen.png');

    // Enter room name
    console.log('Clicking room name input...');
    await page.mouse.click(640, 393);  // Room name input
    await page.waitForTimeout(500);

    console.log('Typing room name...');
    await page.keyboard.type('Debug Test Room', { delay: 50 });
    await page.waitForTimeout(1000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-03-room-name.png') });
    console.log('Screenshot: debug-03-room-name.png');

    // Click Create Room
    console.log('Clicking Create Room button...');
    await page.mouse.click(640, 563);
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-04-room-created.png') });
    console.log('Screenshot: debug-04-room-created.png');

    // Enter Room
    console.log('Clicking Enter Room...');
    await page.mouse.click(640, 578);
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-05-in-chat.png') });
    console.log('Screenshot: debug-05-in-chat.png');

    // Now test messaging
    console.log('\n=== Testing Message Input ===');

    // Click on the text input field - it's at the bottom center
    console.log('Clicking message input field at (640, 683)...');
    await page.mouse.click(640, 683);
    await page.waitForTimeout(1000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-06-input-clicked.png') });
    console.log('Screenshot: debug-06-input-clicked.png');

    // Type a message
    const testMessage = 'HELLO_TEST_' + Date.now();
    console.log(`Typing message: "${testMessage}"...`);
    await page.keyboard.type(testMessage, { delay: 100 });
    await page.waitForTimeout(1000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-07-message-typed.png') });
    console.log('Screenshot: debug-07-message-typed.png');

    // Try pressing Enter to send
    console.log('Pressing Enter to send...');
    await page.keyboard.press('Enter');
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-08-after-enter.png') });
    console.log('Screenshot: debug-08-after-enter.png');

    // Click the input again and try the send button
    console.log('\nTrying send button approach...');
    await page.mouse.click(640, 683);
    await page.waitForTimeout(500);

    const testMessage2 = 'SEND_BUTTON_TEST_' + Date.now();
    console.log(`Typing second message: "${testMessage2}"...`);
    await page.keyboard.type(testMessage2, { delay: 100 });
    await page.waitForTimeout(1000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-09-second-message-typed.png') });
    console.log('Screenshot: debug-09-second-message-typed.png');

    // Click the send button (green circle on the right)
    console.log('Clicking send button at approximately (1247, 687)...');
    await page.mouse.click(1247, 687);
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'debug-10-after-send-button.png') });
    console.log('Screenshot: debug-10-after-send-button.png');

    // Final state
    await page.screenshot({ path: path.join(screenshotDir, 'debug-final.png'), fullPage: true });
    console.log('\nFinal screenshot: debug-final.png');

    console.log('\n=== Test Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: path.join(screenshotDir, 'debug-error.png') }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testMessaging();
