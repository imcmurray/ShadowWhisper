/**
 * Test Fixtures - Common setup patterns for dual-browser tests
 *
 * These fixtures handle the boilerplate of setting up browsers and getting
 * users into rooms, so tests can focus on the actual test logic.
 */

const { setupBrowserPair, navigateToApp } = require('./browser');
const { createRoom, extractRoomCode, enterRoom, joinRoomWithCode } = require('./room');
const { takeScreenshot } = require('./flutter');
const config = require('../config/test.config');

/**
 * Most common fixture: Two browsers, both joined to the same room.
 *
 * Usage:
 *   await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
 *     // Both browsers are connected and in the room
 *     await sendMessage(creator.page, 'Hello!');
 *   });
 *
 * @param {Function} testFn - Test function receiving { creator, joiner, roomCode, browsers }
 * @param {Object} options - Optional configuration
 * @param {string} options.roomName - Room name (default: 'Test Room')
 * @param {string} options.screenshotPrefix - Prefix for screenshots
 */
async function withTwoBrowsersInRoom(testFn, options = {}) {
  const {
    roomName = 'Test Room',
    screenshotPrefix = 'test',
  } = options;

  const browsers = await setupBrowserPair();
  const { creator, joiner } = browsers;

  try {
    // Phase 1: Creator creates and enters room
    await navigateToApp(creator.page, 'Creator');
    await createRoom(creator.page, {
      roomName,
      approvalMode: false,
      screenshotPrefix: `${screenshotPrefix}-creator`,
    });
    const roomCode = await extractRoomCode(creator.page);
    await enterRoom(creator.page, `${screenshotPrefix}-creator`);

    // Wait for P2P initialization
    await creator.page.waitForTimeout(config.TIMEOUTS.longWait);

    // Phase 2: Joiner joins the room
    await navigateToApp(joiner.page, 'Joiner');
    await joinRoomWithCode(joiner.page, roomCode, {
      screenshotPrefix: `${screenshotPrefix}-joiner`,
    });

    // Phase 3: Wait for P2P connection to establish
    await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

    // Run the actual test
    await testFn({ creator, joiner, roomCode, browsers });

  } finally {
    await browsers.cleanup();
  }
}

/**
 * Fixture for testing approval mode: Creator has approval enabled,
 * joiner enters waiting room.
 *
 * Usage:
 *   await withApprovalModeRoom(async ({ creator, joiner, roomCode }) => {
 *     // Joiner is in waiting room, needs approval
 *     await approveJoinRequest(creator.page);
 *   });
 */
async function withApprovalModeRoom(testFn, options = {}) {
  const {
    roomName = 'Approval Test Room',
    screenshotPrefix = 'approval',
  } = options;

  const browsers = await setupBrowserPair();
  const { creator, joiner } = browsers;

  try {
    // Creator creates room WITH approval mode
    await navigateToApp(creator.page, 'Creator');
    await createRoom(creator.page, {
      roomName,
      approvalMode: true,
      screenshotPrefix: `${screenshotPrefix}-creator`,
    });
    const roomCode = await extractRoomCode(creator.page);
    await enterRoom(creator.page, `${screenshotPrefix}-creator`);

    await creator.page.waitForTimeout(config.TIMEOUTS.longWait);

    // Joiner attempts to join (enters waiting room)
    await navigateToApp(joiner.page, 'Joiner');
    await joinRoomWithCode(joiner.page, roomCode, {
      screenshotPrefix: `${screenshotPrefix}-joiner`,
    });

    // Run the test (joiner is in waiting room)
    await testFn({ creator, joiner, roomCode, browsers });

  } finally {
    await browsers.cleanup();
  }
}

/**
 * Fixture for creator-only tests (no joiner needed).
 *
 * Usage:
 *   await withCreatorOnly(async ({ creator, roomCode }) => {
 *     // Test room creation flow
 *   });
 */
async function withCreatorOnly(testFn, options = {}) {
  const {
    roomName = 'Solo Test Room',
    screenshotPrefix = 'solo',
    enterRoomAfterCreate = true,
  } = options;

  const browsers = await setupBrowserPair();
  const { creator } = browsers;

  try {
    await navigateToApp(creator.page, 'Creator');
    await createRoom(creator.page, {
      roomName,
      approvalMode: false,
      screenshotPrefix: `${screenshotPrefix}-creator`,
    });
    const roomCode = await extractRoomCode(creator.page);

    if (enterRoomAfterCreate) {
      await enterRoom(creator.page, `${screenshotPrefix}-creator`);
      await creator.page.waitForTimeout(config.TIMEOUTS.longWait);
    }

    await testFn({ creator, roomCode, browsers });

  } finally {
    await browsers.cleanup();
  }
}

/**
 * Fixture for three-browser tests (creator + 2 joiners).
 *
 * Usage:
 *   await withThreeBrowsers(async ({ creator, joiner1, joiner2, roomCode }) => {
 *     // Test with 3 participants
 *   });
 */
async function withThreeBrowsers(testFn, options = {}) {
  const {
    roomName = 'Three User Room',
    screenshotPrefix = 'three',
  } = options;

  const { chromium } = require('playwright');

  const browser = await chromium.launch({
    headless: false,
    channel: 'chrome',
    args: config.BROWSER_ARGS,
  });

  const creatorContext = await browser.newContext({
    viewport: config.VIEWPORT,
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const joiner1Context = await browser.newContext({
    viewport: config.VIEWPORT,
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const joiner2Context = await browser.newContext({
    viewport: config.VIEWPORT,
    permissions: ['clipboard-read', 'clipboard-write'],
  });

  const creator = { page: await creatorContext.newPage(), name: 'Creator' };
  const joiner1 = { page: await joiner1Context.newPage(), name: 'Joiner1' };
  const joiner2 = { page: await joiner2Context.newPage(), name: 'Joiner2' };

  try {
    // Creator creates and enters room
    await navigateToApp(creator.page, 'Creator');
    await createRoom(creator.page, {
      roomName,
      approvalMode: false,
      screenshotPrefix: `${screenshotPrefix}-creator`,
    });
    const roomCode = await extractRoomCode(creator.page);
    await enterRoom(creator.page, `${screenshotPrefix}-creator`);
    await creator.page.waitForTimeout(config.TIMEOUTS.longWait);

    // Joiner 1 joins
    await navigateToApp(joiner1.page, 'Joiner1');
    await joinRoomWithCode(joiner1.page, roomCode, {
      screenshotPrefix: `${screenshotPrefix}-joiner1`,
    });
    await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

    // Joiner 2 joins
    await navigateToApp(joiner2.page, 'Joiner2');
    await joinRoomWithCode(joiner2.page, roomCode, {
      screenshotPrefix: `${screenshotPrefix}-joiner2`,
    });
    await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

    await testFn({ creator, joiner1, joiner2, roomCode, browser });

  } finally {
    await creatorContext.close();
    await joiner1Context.close();
    await joiner2Context.close();
    await browser.close();
  }
}

module.exports = {
  withTwoBrowsersInRoom,
  withApprovalModeRoom,
  withCreatorOnly,
  withThreeBrowsers,
};
