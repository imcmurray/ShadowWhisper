const { chromium } = require('/app/node_modules/playwright');
const path = require('path');

async function testFeature16() {
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

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }
  });
  const page = await context.newPage();

  const screenshotDir = '/test';

  try {
    console.log('=== Feature #16: Participant count reflects actual participants ===\n');

    // Navigate to app
    console.log('Navigating to app...');
    await page.goto('http://172.17.0.1:8080', { timeout: 60000 });

    // Wait for Flutter to fully load - look for flt-glass-pane or flutter-view
    console.log('Waiting for Flutter to load (looking for flt-glass-pane)...');
    let loaded = false;
    for (let i = 0; i < 60; i++) {  // Up to 60 seconds
      await page.waitForTimeout(1000);
      try {
        const html = await page.content();
        if (html.includes('flt-glass-pane') || html.includes('flutter-view')) {
          console.log(`Flutter detected after ${i+1} seconds`);
          loaded = true;
          break;
        }
      } catch (e) {
        // Page might be navigating
      }
      if (i % 10 === 9) {
        console.log(`Still waiting... ${i+1}s`);
      }
    }

    if (!loaded) {
      console.log('WARNING: Flutter may not have fully loaded');
    }

    // Additional wait for rendering to complete
    await page.waitForTimeout(5000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-00-loaded.png') });
    console.log('Screenshot: f16-00-loaded.png');

    // Step 1: Create a room (1 participant)
    console.log('\n=== Step 1: Create a room (1 participant) ===');
    console.log('Clicking Create Room button...');
    await page.mouse.click(640, 655);  // Create Room button
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-01-create-screen.png') });
    console.log('Screenshot: f16-01-create-screen.png');

    // Enter room name
    console.log('Entering room name...');
    await page.mouse.click(640, 393);  // Room name input
    await page.waitForTimeout(500);
    await page.keyboard.type('Participant Test Room');
    await page.waitForTimeout(1000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-02-room-name-entered.png') });

    // Click Create Room
    console.log('Clicking Create Room button...');
    await page.mouse.click(640, 563);  // Create Room button
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-03-room-created.png') });
    console.log('Screenshot: f16-03-room-created.png');

    // Enter Room
    console.log('Clicking Enter Room...');
    await page.mouse.click(640, 578);  // Enter Room
    await page.waitForTimeout(3000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-04-one-participant.png') });
    console.log('Screenshot: f16-04-one-participant.png');
    console.log('Check screenshot - should show "1 participant" in header');

    // Step 3: Have a second user join - using the Add Test Participant button
    console.log('\n=== Step 3: Add a test participant ===');

    // Open participant drawer - people icon is in the header at top right
    console.log('Opening participant drawer...');
    await page.mouse.click(1178, 28);  // People icon in header
    await page.waitForTimeout(2000);

    await page.screenshot({ path: path.join(screenshotDir, 'f16-05-drawer-open.png') });
    console.log('Screenshot: f16-05-drawer-open.png');

    // Look for and click "Add Test Participant" button
    // It should be visible in the drawer
    console.log('Looking for Add Test Participant button...');

    // The drawer opens from the right side. Let's try clicking in the drawer area
    // The button should be at the bottom of the participant list
    // Try y positions around 150-250 and x around 1100-1140 (inside drawer)
    await page.mouse.click(1130, 170);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(screenshotDir, 'f16-06-after-click-170.png') });

    // Try clicking lower
    await page.mouse.click(1130, 220);
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(screenshotDir, 'f16-06b-after-click-220.png') });

    // Close drawer
    console.log('Closing drawer...');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1000);

    // Check header for participant count
    console.log('\n=== Step 4: Check participant count ===');
    await page.screenshot({ path: path.join(screenshotDir, 'f16-07-after-adding.png') });
    console.log('Screenshot: f16-07-after-adding.png');
    console.log('Check if header shows "2 participants"');

    console.log('\n=== Test Complete ===');

  } catch (error) {
    console.error('Error:', error.message);
    console.error('Stack:', error.stack);
    await page.screenshot({ path: path.join(screenshotDir, 'f16-error.png') }).catch(() => {});
  } finally {
    await browser.close();
  }
}

testFeature16();
