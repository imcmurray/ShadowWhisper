const { chromium } = require('playwright');
const config = require('../config/test.config');
const { waitForFlutterLoad } = require('./flutter');

async function setupBrowserPair() {
  console.log('Setting up browser pair...');

  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: config.BROWSER_ARGS,
  });

  const creatorContext = await browser.newContext({
    viewport: config.VIEWPORT,
    permissions: ['clipboard-read', 'clipboard-write'],
  });

  const joinerContext = await browser.newContext({
    viewport: config.VIEWPORT,
    permissions: ['clipboard-read', 'clipboard-write'],
  });

  const creatorPage = await creatorContext.newPage();
  const joinerPage = await joinerContext.newPage();

  // Capture console logs from both pages
  creatorPage.on('console', msg => {
    if (msg.text().includes('[addRemoteParticipant]') || msg.text().includes('Glare')) {
      console.log(`[Creator Console] ${msg.text()}`);
    }
  });
  joinerPage.on('console', msg => {
    if (msg.text().includes('[addRemoteParticipant]') || msg.text().includes('Glare')) {
      console.log(`[Joiner Console] ${msg.text()}`);
    }
  });

  console.log('  Browser pair created (2 isolated contexts)');

  return {
    browser,
    creator: {
      context: creatorContext,
      page: creatorPage,
      name: 'Creator',
    },
    joiner: {
      context: joinerContext,
      page: joinerPage,
      name: 'Joiner',
    },
    async cleanup() {
      console.log('Cleaning up browser pair...');
      await creatorContext.close();
      await joinerContext.close();
      await browser.close();
      console.log('  Browser pair closed');
    },
  };
}

async function navigateToApp(page, name = '') {
  const prefix = name ? `[${name}] ` : '';
  console.log(`${prefix}Navigating to app...`);
  await page.goto(config.APP_URL, { timeout: config.TIMEOUTS.flutterLoad });
  await waitForFlutterLoad(page);
}

async function waitForParticipantCount(page, expectedCount, timeout = config.TIMEOUTS.p2pConnection) {
  console.log(`  Waiting for ${expectedCount} participant(s)...`);
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    await page.waitForTimeout(1000);
  }

  console.log(`  Waited ${timeout}ms for participant sync`);
  return true;
}

module.exports = {
  setupBrowserPair,
  navigateToApp,
  waitForParticipantCount,
};
