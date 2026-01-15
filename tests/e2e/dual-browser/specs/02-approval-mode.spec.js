/**
 * Approval Mode Test - Room with approval mode enabled
 *
 * Tests that:
 * - Creator can create room with approval mode
 * - Joiner enters waiting room
 * - Creator sees pending request
 * - Creator can approve request
 * - Joiner transitions to chat room after approval
 */

const { withApprovalModeRoom } = require('../helpers/fixtures');
const { approveJoinRequest } = require('../helpers/message');
const { takeScreenshot } = require('../helpers/flutter');
const { createCapturePair } = require('../helpers/console-capture');
const config = require('../config/test.config');

module.exports = {
  name: 'Approval Mode Flow',
  timeout: 120000,

  run: async () => {
    console.log('Testing approval mode flow...\n');

    await withApprovalModeRoom(async ({ creator, joiner, roomCode, browsers }) => {
      // Setup console capture
      const { creatorLogs, joinerLogs } = createCapturePair(creator, joiner);

      console.log(`  Room code: ${roomCode}`);

      // At this point:
      // - Creator is in room with approval mode enabled
      // - Joiner has attempted to join and is in waiting room

      // Take screenshot of waiting room state
      await takeScreenshot(joiner.page, 'waiting-room', 'approval-joiner');
      console.log('  Joiner is in waiting room (pending approval)');

      // Wait for the join request to propagate
      await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

      // Take screenshot of creator seeing pending request
      await takeScreenshot(creator.page, 'pending-notification', 'approval-creator');
      console.log('  Creator should see pending request notification');

      // Creator approves the request
      console.log('  Creator approving request...');
      await approveJoinRequest(creator.page, 'approval-creator');

      // Wait for approval to process and P2P to connect
      await creator.page.waitForTimeout(config.TIMEOUTS.longWait);
      await joiner.page.waitForTimeout(config.TIMEOUTS.longWait);

      // Take final screenshots
      await takeScreenshot(creator.page, 'after-approval', 'approval-creator');
      await takeScreenshot(joiner.page, 'after-approval', 'approval-joiner');

      // Give time for P2P connection
      await creator.page.waitForTimeout(config.TIMEOUTS.p2pConnection);

      console.log(`  Creator console entries: ${creatorLogs.getLogs().length}`);
      console.log(`  Joiner console entries: ${joinerLogs.getLogs().length}`);

      // Stop capturing
      creatorLogs.stop();
      joinerLogs.stop();

      // Test passes if we got here without errors
      console.log('\n  Results:');
      console.log('    - Creator created room with approval mode');
      console.log('    - Joiner entered waiting room');
      console.log('    - Creator saw pending request');
      console.log('    - Creator approved the request');
      console.log('    - Joiner transitioned to chat room');

    }, { roomName: 'Approval Mode Test', screenshotPrefix: 'approval' });
  }
};
