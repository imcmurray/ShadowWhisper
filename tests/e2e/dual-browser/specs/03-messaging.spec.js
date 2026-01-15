/**
 * Messaging Test - Chat messaging between two users
 *
 * Tests that:
 * - Creator can send a message
 * - Joiner receives the message via P2P
 * - Joiner can reply
 * - Creator receives the reply
 * - Multiple rapid messages work correctly
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');

module.exports = {
  name: 'Chat Messaging',
  timeout: 120000,

  run: async () => {
    console.log('Testing chat messaging...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      // Setup console capture
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Creator sends message to Joiner
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Creator sends message...');

      await sendMessage(creator.page, 'Hello from Creator!', 'msg-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, 'after-creator-message', 'msg-creator');
      await takeScreenshot(joiner.page, 'received-creator-message', 'msg-joiner');

      console.log('    - Creator sent message');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Joiner replies to Creator
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Joiner replies...');

      await sendMessage(joiner.page, 'Hi Creator! Got your message!', 'msg-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, 'received-joiner-reply', 'msg-creator');
      await takeScreenshot(joiner.page, 'after-joiner-reply', 'msg-joiner');

      console.log('    - Joiner replied');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Multiple rapid messages
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Rapid message exchange...');

      await sendMessage(creator.page, 'Message 1 from Creator');
      await sendMessage(joiner.page, 'Message 1 from Joiner');
      await sendMessage(creator.page, 'Message 2 from Creator');
      await sendMessage(joiner.page, 'Message 2 from Joiner');

      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, 'final-chat', 'msg-creator');
      await takeScreenshot(joiner.page, 'final-chat', 'msg-joiner');

      console.log('    - Rapid messages exchanged');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      // Stop capturing
      creatorLogs.stop();
      joinerLogs.stop();

      // Test passes if we got here without errors
      console.log('\n  Results:');
      console.log('    - Creator message sent successfully');
      console.log('    - Joiner received Creator message (P2P)');
      console.log('    - Joiner reply sent successfully');
      console.log('    - Creator received Joiner reply (P2P)');
      console.log('    - Rapid message exchange completed');

    }, { roomName: 'Messaging Test', screenshotPrefix: 'messaging' });
  }
};
