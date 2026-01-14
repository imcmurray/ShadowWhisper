const { chromium } = require('/app/node_modules/playwright');

async function testFeature11() {
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
    console.log('=== Feature #11: Leave button accessible in chat UI ===\n');

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
    await page.keyboard.type('Leave Test Room');
    await page.waitForTimeout(1000);
    await page.mouse.click(640, 563);  // Create Room button
    await page.waitForTimeout(3000);
    await page.mouse.click(640, 578);  // Enter Room
    await page.waitForTimeout(3000);

    await page.screenshot({ path: '/screenshots/f11-01-in-chat.png' });
    console.log('  Screenshot: f11-01-in-chat.png');

    // Step 2 & 3: Click leave button (rightmost icon in top right, at ~1250, 28)
    console.log('\nStep 2-3: Click leave button...');
    await page.mouse.click(1250, 28);
    await page.waitForTimeout(2000);

    await page.screenshot({ path: '/screenshots/f11-02-leave-dialog.png' });
    console.log('  Screenshot: f11-02-leave-dialog.png');

    // Final screenshot
    await page.screenshot({ path: '/screenshots/f11-final-state.png', fullPage: true });
    console.log('\n  Final screenshot: f11-final-state.png');

    console.log('\n=== Test Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: '/screenshots/f11-error-state.png' }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testFeature11();
