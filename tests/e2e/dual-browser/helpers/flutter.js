const config = require('../config/test.config');

async function waitForFlutterLoad(page, timeout = config.TIMEOUTS.flutterLoad) {
  console.log('  Waiting for Flutter to load...');
  const maxIterations = Math.floor(timeout / 1000);

  for (let i = 0; i < maxIterations; i++) {
    await page.waitForTimeout(1000);
    const html = await page.content();
    if (html.includes('flutter-view') || html.includes('flt-glass-pane')) {
      console.log(`  Flutter loaded after ${i + 1} seconds`);
      await page.waitForTimeout(config.TIMEOUTS.flutterRender);
      return true;
    }
  }

  throw new Error(`Flutter failed to load within ${timeout}ms`);
}

async function clickAt(page, coordinates, description = '') {
  if (description) {
    console.log(`  Clicking: ${description}`);
  }
  await page.mouse.click(coordinates.x, coordinates.y);
  await page.waitForTimeout(config.TIMEOUTS.shortWait);
}

async function typeText(page, text, delay = 50) {
  await page.keyboard.type(text, { delay });
  await page.waitForTimeout(config.TIMEOUTS.shortWait);
}

async function takeScreenshot(page, name, prefix = '') {
  const filename = prefix ? `${prefix}-${name}.png` : `${name}.png`;
  const path = `${config.SCREENSHOT_DIR}/${filename}`;
  await page.screenshot({ path });
  console.log(`  Screenshot: ${filename}`);
  return path;
}

module.exports = {
  waitForFlutterLoad,
  clickAt,
  typeText,
  takeScreenshot,
};
