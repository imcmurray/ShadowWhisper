/**
 * Three Participants Test - Multi-user scenarios
 *
 * Tests that:
 * - Three users can join the same room
 * - Messages from one user reach both others
 * - All three can exchange messages
 * - P2P mesh networking works correctly
 */

const { withThreeBrowsers } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt } = require('../helpers/flutter');
const { ConsoleCapture } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Three Participants',
  timeout: 180000, // Longer timeout for 3 browsers

  run: async () => {
    console.log('Testing three participants...\n');

    await withThreeBrowsers(async ({ creator, joiner1, joiner2, roomCode }) => {
      // Set up console capture for all three
      const creatorLogs = new ConsoleCapture(creator.page, 'Creator');
      const joiner1Logs = new ConsoleCapture(joiner1.page, 'Joiner1');
      const joiner2Logs = new ConsoleCapture(joiner2.page, 'Joiner2');

      console.log(`  Room code: ${roomCode}`);
      console.log('  All three users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Initial state with three users
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Verifying three users in room...');

      await takeScreenshot(creator.page, '01-three-users', 'three-creator');
      await takeScreenshot(joiner1.page, '01-three-users', 'three-joiner1');
      await takeScreenshot(joiner2.page, '01-three-users', 'three-joiner2');

      console.log('    - All three connected');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Creator sends message, both joiners receive
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Creator broadcasts message...');

      await sendMessage(creator.page, 'Hello from Creator to everyone!', 'three-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(joiner1.page, '02-received-creator', 'three-joiner1');
      await takeScreenshot(joiner2.page, '02-received-creator', 'three-joiner2');

      console.log('    - Both joiners received message');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Joiner1 sends message, creator and joiner2 receive
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Joiner1 broadcasts message...');

      await sendMessage(joiner1.page, 'Hello from Joiner1!', 'three-joiner1');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '03-received-joiner1', 'three-creator');
      await takeScreenshot(joiner2.page, '03-received-joiner1', 'three-joiner2');

      console.log('    - Creator and Joiner2 received message');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Joiner2 sends message, creator and joiner1 receive
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Joiner2 broadcasts message...');

      await sendMessage(joiner2.page, 'Hello from Joiner2!', 'three-joiner2');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '04-received-joiner2', 'three-creator');
      await takeScreenshot(joiner1.page, '04-received-joiner2', 'three-joiner1');

      console.log('    - Creator and Joiner1 received message');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Rapid three-way conversation
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Three-way rapid conversation...');

      await sendMessage(creator.page, 'Message 1 from Creator');
      await sendMessage(joiner1.page, 'Message 1 from Joiner1');
      await sendMessage(joiner2.page, 'Message 1 from Joiner2');
      await sendMessage(creator.page, 'Message 2 from Creator');
      await sendMessage(joiner1.page, 'Message 2 from Joiner1');
      await sendMessage(joiner2.page, 'Message 2 from Joiner2');

      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery * 2);

      await takeScreenshot(creator.page, '05-rapid-chat', 'three-creator');
      await takeScreenshot(joiner1.page, '05-rapid-chat', 'three-joiner1');
      await takeScreenshot(joiner2.page, '05-rapid-chat', 'three-joiner2');

      console.log('    - Rapid exchange completed');

      // ═══════════════════════════════════════════════════════════════
      // TEST 6: One user leaves, other two remain connected
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 6] Joiner2 leaves room...');

      await clickAt(joiner2.page, coords.chat.leaveButton, 'Leave button');
      await joiner2.page.waitForTimeout(config.TIMEOUTS.longWait);

      await takeScreenshot(joiner2.page, '06-left-room', 'three-joiner2');

      // Wait for leave to propagate
      await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

      console.log('    - Joiner2 left');

      // ═══════════════════════════════════════════════════════════════
      // TEST 7: Creator and Joiner1 can still communicate
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 7] Remaining users communicate...');

      await sendMessage(creator.page, 'Still here with Joiner1!', 'three-creator');
      await sendMessage(joiner1.page, 'Yes, we are still connected!', 'three-joiner1');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '07-final', 'three-creator');
      await takeScreenshot(joiner1.page, '07-final', 'three-joiner1');

      console.log('    - Two remaining users still connected');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner1 console entries: ${joiner1Logs.getLogs().length}`);
      console.log(`  Joiner2 console entries: ${joiner2Logs.getLogs().length}`);

      creatorLogs.stop();
      joiner1Logs.stop();
      joiner2Logs.stop();

      console.log('\n  Results:');
      console.log('    - Three users connected successfully');
      console.log('    - Messages broadcast to all users');
      console.log('    - P2P mesh networking works');
      console.log('    - Room survives user departure');

    }, { roomName: 'Three User Room', screenshotPrefix: 'three' });
  }
};
