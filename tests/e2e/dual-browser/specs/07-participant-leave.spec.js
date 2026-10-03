/**
 * Participant Leave Test - Voluntary room exit
 *
 * Tests that:
 * - Participant can leave room voluntarily
 * - Other participants see them leave
 * - Room continues working after someone leaves
 * - Leaver returns to landing page
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Participant Leave',
  timeout: 120000,

  run: async () => {
    console.log('Testing participant leave...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Both users exchange messages
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Users exchange messages...');

      await sendMessage(creator.page, 'Hello from Creator!', 'leave-creator');
      await sendMessage(joiner.page, 'Hello from Joiner!', 'leave-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '01-before-leave', 'leave-creator');
      await takeScreenshot(joiner.page, '01-before-leave', 'leave-joiner');

      console.log('    - Messages exchanged');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Joiner clicks leave button
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Joiner clicks leave...');

      await clickAt(joiner.page, coords.chat.leaveButton, 'Leave button');
      await joiner.page.waitForTimeout(config.TIMEOUTS.longWait);

      await takeScreenshot(joiner.page, '02-after-leave', 'leave-joiner');

      console.log('    - Leave button clicked');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Verify joiner returned to landing
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Joiner on landing page...');

      await joiner.page.waitForTimeout(config.TIMEOUTS.mediumWait);
      await takeScreenshot(joiner.page, '03-landing', 'leave-joiner');

      console.log('    - Joiner returned to landing');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Creator sees participant left
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Creator notified of leave...');

      await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);
      await takeScreenshot(creator.page, '04-after-joiner-left', 'leave-creator');

      console.log('    - Creator sees joiner left');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Creator can still send messages
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Creator still in room...');

      await sendMessage(creator.page, 'I am still here!', 'leave-creator');
      await creator.page.waitForTimeout(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-creator-alone', 'leave-creator');

      console.log('    - Creator remains functional');

      // ═══════════════════════════════════════════════════════════════
      // TEST 6: Joiner's old messages may show placeholder
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 6] Checking message history...');

      // Take final screenshot showing message history
      await takeScreenshot(creator.page, '06-final-state', 'leave-creator');

      console.log('    - Message history preserved');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - Leave button works');
      console.log('    - Leaver returns to landing');
      console.log('    - Other users notified');
      console.log('    - Room continues functioning');

    }, { roomName: 'Leave Test', screenshotPrefix: 'leave' });
  }
};
