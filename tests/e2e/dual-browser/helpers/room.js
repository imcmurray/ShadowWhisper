const config = require('../config/test.config');
const coords = require('../config/coordinates');
const { clickAt, typeText, takeScreenshot } = require('./flutter');
const { navigateToApp } = require('./browser');

async function createRoom(page, options = {}) {
  const {
    roomName = 'Test Room',
    approvalMode = false,
    screenshotPrefix = 'creator',
  } = options;

  console.log(`Creating room: "${roomName}" (approval: ${approvalMode})`);

  await clickAt(page, coords.landing.createRoomButton, 'Create Room button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  await takeScreenshot(page, '01-create-room-screen', screenshotPrefix);

  await clickAt(page, coords.createRoom.roomNameInput, 'Room name input');
  await typeText(page, roomName);

  if (approvalMode) {
    await clickAt(page, coords.createRoom.approvalToggle, 'Approval mode toggle');
    await page.waitForTimeout(config.TIMEOUTS.shortWait);
  }

  await takeScreenshot(page, '02-room-name-entered', screenshotPrefix);

  await clickAt(page, coords.createRoom.createButton, 'Create button');
  await page.waitForTimeout(config.TIMEOUTS.roomCreation);

  await takeScreenshot(page, '03-room-created', screenshotPrefix);

  console.log('  Room created successfully');
}

async function extractRoomCode(page) {
  console.log('Extracting room code from page...');

  // Clear clipboard first with a marker
  await page.evaluate(async () => {
    await navigator.clipboard.writeText('CLIPBOARD_CLEARED');
  });

  // Click the Copy Code button
  await clickAt(page, coords.createRoom.copyCodeButton, 'Copy code button');
  await page.waitForTimeout(config.TIMEOUTS.mediumWait);

  // Read from clipboard
  const roomCode = await page.evaluate(async () => {
    try {
      const text = await navigator.clipboard.readText();
      return text?.trim() || null;
    } catch (e) {
      return null;
    }
  });

  // Validate the room code format (alphanumeric)
  if (!roomCode || !roomCode.match(/^shadow-[a-z0-9]+$/)) {
    console.log('  Clipboard content:', roomCode?.substring(0, 100));
    throw new Error(`Invalid room code from clipboard: ${roomCode?.substring(0, 50)}`);
  }

  console.log(`  Room code extracted: ${roomCode}`);
  return roomCode;
}

async function enterRoom(page, screenshotPrefix = 'creator') {
  console.log('Entering room...');

  await clickAt(page, coords.createRoom.enterRoomButton, 'Enter Room button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  await takeScreenshot(page, '04-chat-screen', screenshotPrefix);

  console.log('  Entered chat screen');
}

async function joinRoomWithCode(page, roomCode, options = {}) {
  const { screenshotPrefix = 'joiner' } = options;

  console.log(`Joining room with code: ${roomCode}`);

  await clickAt(page, coords.landing.joinRoomButton, 'Join Room button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  await takeScreenshot(page, '01-join-room-screen', screenshotPrefix);

  await clickAt(page, coords.joinRoom.roomCodeInput, 'Room code input');
  await typeText(page, roomCode);

  await takeScreenshot(page, '02-code-entered', screenshotPrefix);

  await clickAt(page, coords.joinRoom.joinButton, 'Join button');

  console.log('  Waiting for ZK proof animation...');
  await page.waitForTimeout(config.TIMEOUTS.zkProof);

  await takeScreenshot(page, '03-joined', screenshotPrefix);

  console.log('  Join complete');
}

async function leaveRoom(page) {
  console.log('Leaving room...');
  await clickAt(page, coords.chat.leaveButton, 'Leave button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);
}

module.exports = {
  createRoom,
  extractRoomCode,
  enterRoom,
  joinRoomWithCode,
  leaveRoom,
};
