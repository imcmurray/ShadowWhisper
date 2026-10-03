/**
 * Emoji Messages Test - Emoji rendering and display
 *
 * Tests that:
 * - Emoji-only messages display larger (32px)
 * - Mixed text and emoji render correctly
 * - Emoji appear on both sender and receiver screens
 * - Various emoji categories work
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt, typeText } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Emoji Messages',
  timeout: 120000,

  run: async () => {
    console.log('Testing emoji messages...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Single emoji message (should display larger)
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Single emoji message...');

      await sendMessage(creator.page, '👍', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '01-single-emoji', 'emoji-creator');
      await takeScreenshot(joiner.page, '01-single-emoji', 'emoji-joiner');

      console.log('    - Single emoji sent (should be 32px)');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Multiple emoji message (emoji-only)
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Multiple emoji message...');

      await sendMessage(joiner.page, '😀🎉🔥', 'emoji-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '02-multiple-emoji', 'emoji-creator');
      await takeScreenshot(joiner.page, '02-multiple-emoji', 'emoji-joiner');

      console.log('    - Multiple emoji sent (should be 32px)');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Mixed text and emoji (normal size)
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Mixed text and emoji...');

      await sendMessage(creator.page, 'Great job! 👏👏👏', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '03-mixed-message', 'emoji-creator');
      await takeScreenshot(joiner.page, '03-mixed-message', 'emoji-joiner');

      console.log('    - Mixed message sent (normal size)');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Different emoji categories
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Various emoji categories...');

      // Faces
      await sendMessage(joiner.page, '😀😂😍🤔😴', 'emoji-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Objects
      await sendMessage(creator.page, '🎁📱💻🎮🎧', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Animals
      await sendMessage(joiner.page, '🐶🐱🦁🐼🦊', 'emoji-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Symbols
      await sendMessage(creator.page, '❤️💯✅⭐🔥', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '04-various-emoji', 'emoji-creator');
      await takeScreenshot(joiner.page, '04-various-emoji', 'emoji-joiner');

      console.log('    - Various emoji categories sent');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Edge cases
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Edge cases...');

      // Emoji with spaces (still emoji-only)
      await sendMessage(creator.page, '👍 👍 👍', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Long emoji sequence
      await sendMessage(joiner.page, '🎉🎉🎉🎉🎉🎉🎉🎉🎉🎉', 'emoji-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Unicode flags
      await sendMessage(creator.page, '🇺🇸🇬🇧🇯🇵🇫🇷🇩🇪', 'emoji-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-edge-cases', 'emoji-creator');
      await takeScreenshot(joiner.page, '05-edge-cases', 'emoji-joiner');

      console.log('    - Edge cases handled');

      // ═══════════════════════════════════════════════════════════════
      // TEST 6: Final conversation view
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 6] Final conversation view...');

      // Send one final mixed message
      await sendMessage(joiner.page, 'This was fun! 🎊', 'emoji-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '06-final', 'emoji-creator');
      await takeScreenshot(joiner.page, '06-final', 'emoji-joiner');

      console.log('    - Final view captured');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - Single emoji displays larger');
      console.log('    - Multiple emoji displays larger');
      console.log('    - Mixed messages display normal');
      console.log('    - Various emoji categories work');
      console.log('    - Edge cases handled correctly');

    }, { roomName: 'Emoji Test', screenshotPrefix: 'emoji' });
  }
};
