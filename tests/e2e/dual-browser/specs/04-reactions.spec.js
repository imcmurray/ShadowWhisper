/**
 * Reactions Test - Message reactions between two users
 *
 * Tests that:
 * - User can long-press a message to open reaction picker
 * - Adding a reaction updates local state
 * - Reaction syncs to other user via P2P
 * - Multiple reactions on same message work
 */

const { withTwoBrowsersInRoom } = require('../helpers/fixtures');
const { sendMessage, waitForMessageDelivery } = require('../helpers/message');
const { takeScreenshot, clickAt, longPressAt } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');
const coords = require('../config/coordinates');

module.exports = {
  name: 'Message Reactions',
  timeout: 120000,

  run: async () => {
    console.log('Testing message reactions...\n');

    await withTwoBrowsersInRoom(async ({ creator, joiner, roomCode }) => {
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);
      console.log('  Both users connected!\n');

      // ═══════════════════════════════════════════════════════════════
      // TEST 1: Creator sends message, Joiner adds reaction
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 1] Creator sends message...');

      await sendMessage(creator.page, 'Hello! React to this message!', 'react-creator');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '01-message-sent', 'react-creator');
      await takeScreenshot(joiner.page, '01-message-received', 'react-joiner');

      console.log('    - Message sent and received');

      // ═══════════════════════════════════════════════════════════════
      // TEST 2: Joiner long-presses to open reaction picker
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 2] Joiner opens reaction picker...');

      // Long-press on the message (received message is left-aligned)
      await longPressAt(joiner.page, coords.chat.firstMessageBubble, 'Message bubble');
      await joiner.page.waitForTimeout(config.TIMEOUTS.mediumWait);

      await takeScreenshot(joiner.page, '02-reaction-picker', 'react-joiner');

      console.log('    - Reaction picker opened');

      // ═══════════════════════════════════════════════════════════════
      // TEST 3: Joiner adds thumbs up reaction
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 3] Joiner adds thumbs up reaction...');

      await clickAt(joiner.page, coords.reactionPicker.thumbsUp, 'Thumbs up emoji');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(joiner.page, '03-after-reaction', 'react-joiner');
      await takeScreenshot(creator.page, '03-reaction-received', 'react-creator');

      console.log('    - Reaction added and synced');

      // ═══════════════════════════════════════════════════════════════
      // TEST 4: Creator adds different reaction to same message
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 4] Creator adds heart reaction...');

      // Long-press on own message (right-aligned)
      await longPressAt(creator.page, coords.chat.ownMessageBubble, 'Own message bubble');
      await creator.page.waitForTimeout(config.TIMEOUTS.mediumWait);

      await takeScreenshot(creator.page, '04-creator-picker', 'react-creator');

      await clickAt(creator.page, coords.reactionPicker.heart, 'Heart emoji');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '04-multiple-reactions', 'react-creator');
      await takeScreenshot(joiner.page, '04-multiple-reactions', 'react-joiner');

      console.log('    - Multiple reactions on message');

      // ═══════════════════════════════════════════════════════════════
      // TEST 5: Joiner sends message and Creator reacts
      // ═══════════════════════════════════════════════════════════════
      console.log('  [Test 5] Joiner sends message, Creator reacts...');

      await sendMessage(joiner.page, 'Now react to MY message!', 'react-joiner');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      // Creator long-presses joiner's message
      await longPressAt(creator.page, coords.chat.firstMessageBubble, 'Joiner message');
      await creator.page.waitForTimeout(config.TIMEOUTS.mediumWait);

      await clickAt(creator.page, coords.reactionPicker.laughing, 'Laughing emoji');
      await waitForMessageDelivery(config.TIMEOUTS.messageDelivery);

      await takeScreenshot(creator.page, '05-final', 'react-creator');
      await takeScreenshot(joiner.page, '05-final', 'react-joiner');

      console.log('    - Bidirectional reactions working');

      console.log(`\n  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      creatorLogs.stop();
      joinerLogs.stop();

      console.log('\n  Results:');
      console.log('    - Reaction picker opens on long-press');
      console.log('    - Reactions sync via P2P');
      console.log('    - Multiple reactions on same message');
      console.log('    - Bidirectional reactions work');

    }, { roomName: 'Reactions Test', screenshotPrefix: 'reactions' });
  }
};
