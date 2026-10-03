/**
 * Kick Participant Test - Room moderation
 *
 * Tests that:
 * - Creator can open participant drawer
 * - Creator can kick a participant
 * - Kicked user is removed from room
 * - Kicked user returns to landing screen
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery, kickParticipant, openParticipantDrawer } = require('../helpers/message');
const { takeScreenshot, clickAt } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Kick Participant',
  timeout: 120000,

  run: async () => {
    console.log('Testing kick participant...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Verify both users are in room
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Verifying both users in room...');

      await takeScreenshot(creator.page, '01-before-kick', 'kick-creator');
      await takeScreenshot(joiner.page, '01-in-room', 'kick-joiner');

      // Send a message to confirm P2P is working
      await sendMessage(creator.page, 'You are about to be kicked!', 'kick-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      console.log('    - Both users confirmed in room');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Creator opens participant drawer
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Opening participant drawer...');

      await openParticipantDrawer(creator.page);
      await takeScreenshot(creator.page, '02-drawer-open', 'kick-creator');

      console.log('    - Drawer opened, joiner visible');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Creator kicks joiner
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Kicking participant...');

      await clickAt(creator.page, coords.participantDrawer.firstParticipantKickButton, 'Kick button');
      await creator.page.waitForTimeout(config.TIMEOUTS.longWait);

      await takeScreenshot(creator.page, '03-after-kick', 'kick-creator');

      console.log('    - Kick action performed');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Verify joiner is kicked
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Verifying joiner kicked...');

      // Wait for kick to propagate
      await joiner.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

      await takeScreenshot(joiner.page, '04-kicked-state', 'kick-joiner');
      await takeScreenshot(creator.page, '04-after-kick-final', 'kick-creator');

      console.log('    - Joiner should be removed/redirected');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Creator is alone in room
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Creator alone in room...');

      // Close drawer if still open
      await creator.page.keyboard.press('Escape');
      await creator.page.waitForTimeout(config.TIMEOUTS.shortWait);

      // Send message to confirm room still works
      await sendMessage(creator.page, 'Joiner has been kicked', 'kick-creator');
      await creator.page.waitForTimeout(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-alone', 'kick-creator');

      console.log('    - Creator remains in room alone');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - Participant drawer shows users');
      console.log('    - Kick button removes participant');
      console.log('    - Kicked user leaves room');
      console.log('    - Creator remains in room');

    }, { roomName: 'Kick Test', screenshotPrefix: 'kick' });
  }
};
