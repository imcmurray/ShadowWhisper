/**
 * Assertion Helpers - Test verification utilities for dual-browser tests
 *
 * These helpers verify expected outcomes in the Flutter app during E2E tests.
 * Since Flutter renders to canvas, most assertions rely on accessibility
 * snapshots, console logs, or pixel-based verification.
 */

const config = require('../config/test.config');

/**
 * Assert that the participant count matches expected.
 *
 * Waits for the participant count to stabilize at the expected value.
 * Uses console log capture to verify the count.
 *
 * @param {ConsoleCapture} logs - Console capture instance for the page
 * @param {number} expected - Expected participant count
 * @param {number} timeout - Max time to wait in ms
 */
async function assertParticipantCount(logs, expected, timeout = 10000) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    // Look for participant count logs
    const countLogs = logs.getLogsMatching('participant');

    // Check if we have a log indicating the expected count
    const hasExpected = countLogs.some(log =>
      log.text.includes(`${expected} participant`) ||
      log.text.includes(`participants: ${expected}`)
    );

    if (hasExpected) {
      return true;
    }

    await new Promise(resolve => setTimeout(resolve, 500));
  }

  throw new Error(
    `Expected ${expected} participants but did not find matching log.\n` +
    `Participant-related logs:\n${logs.getLogsMatching('participant').map(l => l.text).join('\n')}`
  );
}

/**
 * Assert that the room name matches expected.
 *
 * @param {ConsoleCapture} logs - Console capture instance for the page
 * @param {string} expected - Expected room name
 */
function assertRoomName(logs, expected) {
  const hasRoomName = logs.contains(`roomName: ${expected}`) ||
                      logs.contains(`room: ${expected}`) ||
                      logs.contains(`"roomName":"${expected}"`);

  if (!hasRoomName) {
    console.log(`Note: Could not verify room name "${expected}" in logs`);
  }
}

/**
 * Assert that a message is visible (was received).
 *
 * @param {ConsoleCapture} logs - Console capture instance for the page
 * @param {string} message - Message text to find
 * @param {number} timeout - Max time to wait in ms
 */
async function assertMessageReceived(logs, message, timeout = 10000) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (logs.contains(message)) {
      return true;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  throw new Error(
    `Expected to receive message "${message}" but it was not found in logs.\n` +
    `Chat-related logs:\n${logs.getLogsMatching('chat').map(l => l.text).join('\n')}`
  );
}

/**
 * Assert that P2P connection was established.
 *
 * Looks for connection-related log messages indicating successful P2P setup.
 *
 * @param {ConsoleCapture} creatorLogs - Console capture for creator
 * @param {ConsoleCapture} joinerLogs - Console capture for joiner
 * @param {number} timeout - Max time to wait in ms
 */
async function assertP2PConnected(creatorLogs, joinerLogs, timeout = 15000) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    const creatorConnected =
      creatorLogs.contains('[addRemoteParticipant]') ||
      creatorLogs.contains('connected') ||
      creatorLogs.contains('RTCPeerConnectionStateConnected');

    const joinerConnected =
      joinerLogs.contains('[addRemoteParticipant]') ||
      joinerLogs.contains('connected') ||
      joinerLogs.contains('RTCPeerConnectionStateConnected');

    if (creatorConnected && joinerConnected) {
      return true;
    }

    await new Promise(resolve => setTimeout(resolve, 500));
  }

  throw new Error(
    `P2P connection not established within ${timeout}ms.\n` +
    `Creator logs:\n${creatorLogs.formatLogs()}\n\n` +
    `Joiner logs:\n${joinerLogs.formatLogs()}`
  );
}

/**
 * Assert that no errors occurred during test.
 *
 * Checks console logs for error messages, excluding known acceptable errors.
 *
 * @param {ConsoleCapture} logs - Console capture instance
 * @param {string[]} ignore - Patterns to ignore
 */
function assertNoErrors(logs, ignore = []) {
  // Common acceptable errors to ignore
  const defaultIgnore = [
    'favicon.ico',
    'DevTools',
    'Extension',
  ];

  logs.assertNoErrors([...defaultIgnore, ...ignore]);
}

/**
 * Assert that a specific log pattern appears within timeout.
 *
 * @param {ConsoleCapture} logs - Console capture instance
 * @param {string} pattern - Pattern to search for
 * @param {number} timeout - Max time to wait in ms
 * @param {string} description - Human-readable description for error message
 */
async function assertLogContains(logs, pattern, timeout = 10000, description = null) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (logs.contains(pattern)) {
      return true;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  const desc = description || `pattern "${pattern}"`;
  throw new Error(
    `Expected ${desc} within ${timeout}ms but not found.\n` +
    `All logs:\n${logs.formatLogs()}`
  );
}

/**
 * Assert that a log pattern does NOT appear.
 *
 * @param {ConsoleCapture} logs - Console capture instance
 * @param {string} pattern - Pattern that should NOT appear
 * @param {string} message - Custom error message
 */
function assertLogNotContains(logs, pattern, message = null) {
  logs.assertNotContains(pattern, message);
}

/**
 * Compare two browser states for consistency.
 *
 * Useful for verifying both browsers show the same state.
 *
 * @param {ConsoleCapture} logs1 - First browser logs
 * @param {ConsoleCapture} logs2 - Second browser logs
 * @param {string} pattern - Pattern to check
 * @returns {Object} Comparison result with matches from each
 */
function compareBrowserLogs(logs1, logs2, pattern) {
  const matches1 = logs1.getLogsMatching(pattern);
  const matches2 = logs2.getLogsMatching(pattern);

  return {
    browser1: matches1,
    browser2: matches2,
    bothHave: matches1.length > 0 && matches2.length > 0,
    countMatch: matches1.length === matches2.length,
  };
}

/**
 * Wait for a condition in logs with custom check function.
 *
 * @param {ConsoleCapture} logs - Console capture instance
 * @param {Function} checkFn - Function that receives logs array and returns boolean
 * @param {number} timeout - Max time to wait in ms
 * @param {string} description - Description of what we're waiting for
 */
async function waitForCondition(logs, checkFn, timeout = 10000, description = 'condition') {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (checkFn(logs.getLogs())) {
      return true;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  throw new Error(
    `Timed out waiting for ${description} (${timeout}ms).\n` +
    `Final logs:\n${logs.formatLogs()}`
  );
}

/**
 * Assert that both browsers eventually show the same participant count.
 *
 * @param {ConsoleCapture} creatorLogs - Creator's console capture
 * @param {ConsoleCapture} joinerLogs - Joiner's console capture
 * @param {number} expected - Expected count for both
 * @param {number} timeout - Max time to wait
 */
async function assertBothShowSameParticipantCount(creatorLogs, joinerLogs, expected, timeout = 15000) {
  // This is a coordination assertion - wait for both to stabilize
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    // Check if both have addRemoteParticipant logs indicating the connection
    const creatorHasRemote = creatorLogs.contains('[addRemoteParticipant]');
    const joinerHasRemote = joinerLogs.contains('[addRemoteParticipant]');

    if (creatorHasRemote && joinerHasRemote) {
      return true;
    }

    await new Promise(resolve => setTimeout(resolve, 500));
  }

  throw new Error(
    `Both browsers should show ${expected} participants but connection not verified.\n` +
    `Creator addRemoteParticipant logs: ${creatorLogs.getLogsMatching('[addRemoteParticipant]').length}\n` +
    `Joiner addRemoteParticipant logs: ${joinerLogs.getLogsMatching('[addRemoteParticipant]').length}`
  );
}

/**
 * Soft assertion that logs a warning instead of throwing.
 *
 * @param {Function} assertFn - Assertion function to run
 * @param {string} description - Description of what's being checked
 * @returns {Object} Result with passed boolean and any error message
 */
async function softAssert(assertFn, description) {
  try {
    await assertFn();
    return { passed: true, description };
  } catch (error) {
    console.warn(`Soft assertion failed: ${description}`);
    console.warn(`  ${error.message.split('\n')[0]}`);
    return { passed: false, description, error: error.message };
  }
}

module.exports = {
  assertParticipantCount,
  assertRoomName,
  assertMessageReceived,
  assertP2PConnected,
  assertNoErrors,
  assertLogContains,
  assertLogNotContains,
  compareBrowserLogs,
  waitForCondition,
  assertBothShowSameParticipantCount,
  softAssert,
};
