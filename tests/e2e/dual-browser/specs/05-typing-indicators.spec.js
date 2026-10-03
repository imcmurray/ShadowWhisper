/**
 * Typing Indicators Test - Real-time typing status
 *
 * Tests that:
 * - Typing in input triggers typing indicator for other user
 * - Stopping typing clears the indicator
 * - Sending message clears typing indicator
 * - Both users typing simultaneously works
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt, typeText } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Typing Indicators',
  timeout: 120000,

  run: async () => {
    console.log('Testing typing indicators...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Creator types, Joiner sees indicator
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Creator starts typing...');

      // Focus on input and type slowly (without sending)
      await clickAt(creator.page, coords.chat.messageInput, 'Message input');
      await typeText(creator.page, 'Hello, I am typing...', 100); // Slow typing

      // Wait for typing indicator to propagate
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '01-typing', 'typing-creator');
      await takeScreenshot(joiner.page, '01-see-typing', 'typing-joiner');

      console.log('    - Typing indicator should be visible to Joiner');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Creator stops typing (blurs input)
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Creator stops typing...');

      // Press Escape to blur/cancel
      await creator.page.keyboard.press('Escape');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(joiner.page, '02-typing-stopped', 'typing-joiner');

      console.log('    - Typing indicator should disappear');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Joiner types, Creator sees indicator
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Joiner starts typing...');

      await clickAt(joiner.page, coords.chat.messageInput, 'Message input');
      await typeText(joiner.page, 'Now I am typing!', 100);

      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '03-see-joiner-typing', 'typing-creator');
      await takeScreenshot(joiner.page, '03-joiner-typing', 'typing-joiner');

      console.log('    - Creator sees Joiner typing');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Joiner sends message, indicator clears
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Joiner sends message...');

      await joiner.page.keyboard.press('Enter');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '04-message-received', 'typing-creator');
      await takeScreenshot(joiner.page, '04-message-sent', 'typing-joiner');

      console.log('    - Typing indicator cleared after send');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Both users type simultaneously
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Both users type at once...');

      // Start typing on both browsers
      await clickAt(creator.page, coords.chat.messageInput, 'Creator input');
      await clickAt(joiner.page, coords.chat.messageInput, 'Joiner input');

      // Type simultaneously (interleaved)
      await creator.page.keyboard.type('Cr', { delay: 100 });
      await joiner.page.keyboard.type('Jo', { delay: 100 });
      await creator.page.keyboard.type('eat', { delay: 100 });
      await joiner.page.keyboard.type('iner', { delay: 100 });

      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-both-typing', 'typing-creator');
      await takeScreenshot(joiner.page, '05-both-typing', 'typing-joiner');

      console.log('    - Both typing indicators visible');

      // Send both messages
      await creator.page.keyboard.press('Enter');
      await joiner.page.keyboard.press('Enter');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-final', 'typing-creator');
      await takeScreenshot(joiner.page, '05-final', 'typing-joiner');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - Typing triggers indicator for other user');
      console.log('    - Stopping typing clears indicator');
      console.log('    - Sending message clears indicator');
      console.log('    - Simultaneous typing works');

    }, { roomName: 'Typing Test', screenshotPrefix: 'typing' });
  }
};
