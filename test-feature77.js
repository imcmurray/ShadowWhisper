const { chromium } = require('/app/node_modules/playwright');

async function testFeature77() {
  const browser = await chromium.launch({
    executablePath: '/ms-playwright/chromium-1202/chrome-linux64/chrome',
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-gpu',
      '--enable-webgl',
      '--use-gl=swiftshader',
      '--ignore-gpu-blocklist'
    ]
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 }
  });

  const page = await context.newPage();

  // Collect console messages
  const consoleMessages = [];
  page.on('console', msg => {
    consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    console.log('BROWSER:', msg.type(), msg.text());
  });
  page.on('pageerror', err => console.log('PAGE ERROR:', err.message));

  try {
    console.log('Step 1: Navigate to app');
    await page.goto('http://172.17.0.1:8080', { waitUntil: 'load', timeout: 60000 });

    // Wait for Flutter to initialize
    console.log('Waiting 15s for Flutter to initialize...');
    await page.waitForTimeout(15000);
    await page.screenshot({ path: '/screenshots/f77-01-after-wait.png' });

    // Check WebGL support
    const webglSupport = await page.evaluate(() => {
      const canvas = document.createElement('canvas');
      const gl = canvas.getContext('webgl') || canvas.getContext('webgl2');
      return gl ? 'WebGL supported' : 'WebGL NOT supported';
    });
    console.log('WebGL status:', webglSupport);

    // Check if Flutter canvas exists
    const flutterCanvas = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      return canvas ? `Canvas found: ${canvas.width}x${canvas.height}` : 'No canvas found';
    });
    console.log('Flutter canvas:', flutterCanvas);

    // Check if loading div is hidden
    const loadingVisible = await page.evaluate(() => {
      const loading = document.getElementById('loading');
      if (!loading) return 'No loading div';
      const style = window.getComputedStyle(loading);
      return `Loading div: display=${style.display}, visibility=${style.visibility}`;
    });
    console.log('Loading status:', loadingVisible);

    console.log('\n=== Console Messages ===');
    consoleMessages.forEach(m => console.log(m));

  } catch (error) {
    console.error('Error:', error);
    await page.screenshot({ path: '/screenshots/f77-error.png' });
  } finally {
    await browser.close();
  }
}

testFeature77().catch(console.error);
