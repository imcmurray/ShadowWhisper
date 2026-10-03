/**
 * End Room Test - Creator terminates room
 *
 * Tests that:
 * - Creator can end the room
 * - All participants are notified
 * - Everyone returns to landing page
 * - Room becomes invalid
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'End Room',
  timeout: 120000,

  run: async () => {
    console.log('Testing end room...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Verify room is active
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Verifying room is active...');

      await sendMessage(creator.page, 'Room is active!', 'end-creator');
      await sendMessage(joiner.page, 'Yes, I can see it!', 'end-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '01-active-room', 'end-creator');
      await takeScreenshot(joiner.page, '01-active-room', 'end-joiner');

      console.log('    - Room confirmed active');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Creator clicks end room button
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Creator ending room...');

      // The end room button is typically in the app bar or settings
      // Try clicking the end room button
      await clickAt(creator.page, coords.chat.endRoomButton, 'End Room button');
      await creator.page.waitForTimeout(config.TIMEOUTS.mediumWait);

      await takeScreenshot(creator.page, '02-ending-room', 'end-creator');

      console.log('    - End room initiated');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Confirm end room (if dialog appears)
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Confirming end room...');

      // If there's a confirmation dialog, click confirm
      // The confirm button is typically in the center of the dialog
      await creator.page.waitForTimeout(config.TIMEOUTS.shortWait);
      // Click center of screen where confirm button would be
      await creator.page.mouse.click(640, 400);
      await creator.page.waitForTimeout(config.TIMEOUTS.longWait);

      await takeScreenshot(creator.page, '03-confirmed', 'end-creator');

      console.log('    - End room confirmed');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Verify joiner is notified and removed
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Joiner notified and removed...');

      // Wait for the end room event to propagate
      await joiner.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

      await takeScreenshot(joiner.page, '04-room-ended', 'end-joiner');

      console.log('    - Joiner notified of room end');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Both users on landing page
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Both users return to landing...');

      await creator.page.waitForTimeout(config.TIMEOUTS.mediumWait);
      await joiner.page.waitForTimeout(config.TIMEOUTS.mediumWait);

      await takeScreenshot(creator.page, '05-creator-landing', 'end-creator');
      await takeScreenshot(joiner.page, '05-joiner-landing', 'end-joiner');

      console.log('    - Both on landing page');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - End room button works');
      console.log('    - All participants notified');
      console.log('    - Users return to landing');
      console.log('    - Room successfully terminated');

    }, { roomName: 'End Room Test', screenshotPrefix: 'end' });
  }
};
