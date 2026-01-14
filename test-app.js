const { chromium } = require('/app/node_modules/playwright');

async function testApp() {
  const browser = await chromium.launch({
    executablePath: '/ms-playwright/chromium-1202/chrome-linux64/chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();

  try {
    console.log('Navigating to http://172.17.0.1:8080...');
    await page.goto('http://172.17.0.1:8080', { timeout: 30000 });
    await page.waitForTimeout(5000);

    const title = await page.title();
    console.log('Title:', title);

    const content = await page.content();
    console.log('Content length:', content.length);

    console.log('Done!');
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await browser.close();
  }
}

testApp();
