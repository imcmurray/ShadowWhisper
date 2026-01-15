const config = require('../config/test.config');
const coords = require('../config/coordinates');
const { clickAt, typeText, takeScreenshot } = require('./flutter');

async function sendMessage(page, message, screenshotPrefix = '') {
  console.log(`Sending message: "${message}"`);

  await clickAt(page, coords.chat.messageInput, 'Message input');
  await typeText(page, message);
  await page.keyboard.press('Enter');

  await page.waitForTimeout(config.TIMEOUTS.messageDelivery);

  if (screenshotPrefix) {
    await takeScreenshot(page, 'message-sent', screenshotPrefix);
  }

  console.log('  Message sent');
}

async function waitForMessageDelivery(timeout = config.TIMEOUTS.messageDelivery) {
  console.log(`Waiting ${timeout}ms for P2P message delivery...`);
  await new Promise(resolve => setTimeout(resolve, timeout));
}

async function openParticipantDrawer(page) {
  console.log('Opening participant drawer...');
  await clickAt(page, coords.chat.participantsButton, 'Participants button');
  await page.waitForTimeout(config.TIMEOUTS.mediumWait);
}

async function closeParticipantDrawer(page) {
  console.log('Closing participant drawer...');
  await clickAt(page, coords.participantDrawer.closeButton, 'Close drawer button');
  await page.waitForTimeout(config.TIMEOUTS.mediumWait);
}

async function kickParticipant(page, screenshotPrefix = '') {
  console.log('Kicking participant...');

  await openParticipantDrawer(page);
  await page.waitForTimeout(config.TIMEOUTS.shortWait);

  if (screenshotPrefix) {
    await takeScreenshot(page, 'participant-drawer', screenshotPrefix);
  }

  await clickAt(page, coords.participantDrawer.firstParticipantKickButton, 'Kick button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  if (screenshotPrefix) {
    await takeScreenshot(page, 'after-kick', screenshotPrefix);
  }

  console.log('  Participant kicked');
}

async function approveJoinRequest(page, screenshotPrefix = '') {
  console.log('Approving join request...');

  await openParticipantDrawer(page);
  await page.waitForTimeout(config.TIMEOUTS.shortWait);

  if (screenshotPrefix) {
    await takeScreenshot(page, 'pending-request', screenshotPrefix);
  }

  await clickAt(page, coords.participantDrawer.approveButton, 'Approve button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  console.log('  Join request approved');
}

async function rejectJoinRequest(page, screenshotPrefix = '') {
  console.log('Rejecting join request...');

  await openParticipantDrawer(page);
  await page.waitForTimeout(config.TIMEOUTS.shortWait);

  await clickAt(page, coords.participantDrawer.rejectButton, 'Reject button');
  await page.waitForTimeout(config.TIMEOUTS.longWait);

  console.log('  Join request rejected');
}

module.exports = {
  sendMessage,
  waitForMessageDelivery,
  openParticipantDrawer,
  closeParticipantDrawer,
  kickParticipant,
  approveJoinRequest,
  rejectJoinRequest,
};
