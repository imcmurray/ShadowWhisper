const { chromium } = require('/app/node_modules/playwright');

async function testFeature12() {
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
    console.log('=== Feature #12: Back button from Create Room returns to landing ===\n');

    // Navigate to app
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });

    // Wait for Flutter to load
    for (let i = 0; i < 30; i++) {
      await page.waitForTimeout(1000);
      const html = await page.content();
      if (html.includes('flutter-view')) break;
    }
    await page.waitForTimeout(5000);

    await page.screenshot({ path: '/screenshots/f12-01-landing.png' });
    console.log('Step 1: Screenshot: f12-01-landing.png');

    // Step 2: Click Create Room
    console.log('\nStep 2: Click Create Room button...');
    await page.mouse.click(640, 655);
    await page.waitForTimeout(3000);

    await page.screenshot({ path: '/screenshots/f12-02-create-room.png' });
    console.log('  Screenshot: f12-02-create-room.png');

    // Step 3: Click back button (top left, at ~28, 28)
    console.log('\nStep 3: Click back button...');
    await page.mouse.click(28, 28);
    await page.waitForTimeout(2000);

    await page.screenshot({ path: '/screenshots/f12-03-back-to-landing.png' });
    console.log('  Screenshot: f12-03-back-to-landing.png');

    // Final screenshot
    await page.screenshot({ path: '/screenshots/f12-final-state.png', fullPage: true });
    console.log('\n  Final screenshot: f12-final-state.png');

    console.log('\n=== Test Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: '/screenshots/f12-error-state.png' }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testFeature12();
