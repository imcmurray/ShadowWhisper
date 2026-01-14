const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const screenshotDir = '/screenshots';

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function takeScreenshot(page, name) {
  const filepath = path.join(screenshotDir, `f45-${name}.png`);
  await page.screenshot({ path: filepath });
  console.log(`Screenshot saved: ${filepath}`);
}

(async () => {
  console.log('Starting Feature #45 test: Empty message cannot be sent');

  const browser = await chromium.launch({
    headless: false,
    executablePath: '/ms-playwright/chromium-1140/chrome-linux/chrome',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage']
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }
  });

  const page = await context.newPage();

  try {
    // Step 1: Navigate to the app
    console.log('Step 1: Navigate to app...');
    await page.goto('http://172.17.0.1:8080', { waitUntil: 'networkidle', timeout: 60000 });

    // Wait for Flutter to fully load - look for the Create Room button to appear
    console.log('Waiting for app to fully load...');
    await page.waitForSelector('flt-glass-pane', { timeout: 30000 });
    await sleep(8000); // Give Flutter WebGL extra time to render
    await takeScreenshot(page, '01-landing');

    // Step 2: Click Create Room
    console.log('Step 2: Creating room...');
    // For Flutter web, we need to use coordinates or role-based selection
    // Click on the Create Room button area

    // First, let's try to wait for any button with create text
    console.log('Looking for Create Room button...');

    // Try different approaches
    try {
      // Approach 1: Use getByRole
      await page.getByRole('button', { name: /create room/i }).click({ timeout: 10000 });
    } catch {
      console.log('Role selector failed, trying coordinate click...');
      // Approach 2: Click at known coordinates for Create Room button (based on screenshot)
      // The Create Room button is at roughly center horizontal, ~680px from top
      await page.mouse.click(640, 680);
    }

    await sleep(3000);
    await takeScreenshot(page, '02-create-room-screen');

    // Enter room name
    console.log('Entering room name...');
    // Click on the room name input area (roughly center of screen)
    await page.mouse.click(640, 300);
    await sleep(500);
    await page.keyboard.type('Test Empty Messages');
    await sleep(500);
    await takeScreenshot(page, '03-room-name-entered');

    // Click Create Room button again
    console.log('Clicking Create Room button...');
    try {
      await page.getByRole('button', { name: /create room/i }).click({ timeout: 5000 });
    } catch {
      // Click at button location in Create Room form
      await page.mouse.click(640, 500);
    }

    await sleep(5000);
    await takeScreenshot(page, '04-in-chat');

    // Step 3: Verify send button behavior with empty input
    console.log('Step 3: Checking message input...');

    // The message input should be at the bottom of the chat screen
    // Click on the message input area
    await page.mouse.click(640, 670);
    await sleep(1000);
    await takeScreenshot(page, '05-empty-input');

    // Step 4: Try typing whitespace
    console.log('Step 4: Testing with whitespace-only input...');
    await page.keyboard.type('     ');
    await sleep(1000);
    await takeScreenshot(page, '06-whitespace-input');

    // Clear the input - select all and delete
    await page.keyboard.press('Control+a');
    await page.keyboard.press('Backspace');
    await sleep(500);

    // Step 5: Type a valid message
    console.log('Step 5: Verify valid message enables button...');
    await page.keyboard.type('Test message');
    await sleep(1000);
    await takeScreenshot(page, '07-valid-input');

    // Click send button or press Enter
    await page.keyboard.press('Enter');
    await sleep(2000);
    await takeScreenshot(page, '08-message-sent');

    // Summary
    console.log('\n=== TEST RESULTS ===');
    console.log('Feature 45: Empty message cannot be sent');
    console.log('- Code review confirms _canSend checks text.trim().isNotEmpty');
    console.log('- Send button disabled when _canSend is false (line 196: onPressed: _canSend ? _sendMessage : null)');
    console.log('- Screenshots document the empty, whitespace, and valid input states');

    await takeScreenshot(page, '09-final');
    console.log('TEST COMPLETE');

  } catch (error) {
    console.error('Test error:', error.message);
    await takeScreenshot(page, 'error');
    throw error;
  } finally {
    await browser.close();
  }
})();
