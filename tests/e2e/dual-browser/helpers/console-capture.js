/**
 * Console Capture - Enhanced console log capture for debugging tests
 *
 * Captures browser console output from Flutter/Playwright and provides
 * methods for filtering, asserting, and saving logs.
 */

const fs = require('fs');
const path = require('path');

class ConsoleCapture {
  /**
   * Create a new console capture instance for a page.
   *
   * @param {Page} page - Playwright page object
   * @param {string} name - Identifier for this capture (e.g., 'creator', 'joiner')
   */
  constructor(page, name) {
    this.page = page;
    this.name = name;
    this.logs = [];
    this.isCapturing = false;
    this._handler = null;
  }

  /**
   * Start capturing ALL console messages.
   */
  captureAll() {
    if (this.isCapturing) return;

    this._handler = (msg) => {
      const entry = {
        timestamp: new Date().toISOString(),
        type: msg.type(),
        text: msg.text(),
        location: msg.location(),
      };
      this.logs.push(entry);
    };

    this.page.on('console', this._handler);
    this.isCapturing = true;
  }

  /**
   * Start capturing only messages matching specified patterns.
   *
   * @param {string[]} patterns - Array of strings to match against log text
   */
  captureFiltered(patterns) {
    if (this.isCapturing) return;

    this._handler = (msg) => {
      const text = msg.text();
      const matches = patterns.some(pattern => text.includes(pattern));

      if (matches) {
        const entry = {
          timestamp: new Date().toISOString(),
          type: msg.type(),
          text: text,
          location: msg.location(),
        };
        this.logs.push(entry);
      }
    };

    this.page.on('console', this._handler);
    this.isCapturing = true;
  }

  /**
   * Stop capturing console messages.
   */
  stop() {
    if (!this.isCapturing || !this._handler) return;

    this.page.off('console', this._handler);
    this.isCapturing = false;
    this._handler = null;
  }

  /**
   * Get all captured logs.
   *
   * @returns {Array} Array of log entries
   */
  getLogs() {
    return [...this.logs];
  }

  /**
   * Get logs filtered by pattern.
   *
   * @param {string} pattern - String to match against log text
   * @returns {Array} Filtered log entries
   */
  getLogsMatching(pattern) {
    return this.logs.filter(log => log.text.includes(pattern));
  }

  /**
   * Get logs filtered by type (log, warn, error, etc.).
   *
   * @param {string} type - Console message type
   * @returns {Array} Filtered log entries
   */
  getLogsByType(type) {
    return this.logs.filter(log => log.type === type);
  }

  /**
   * Check if any log contains the specified pattern.
   *
   * @param {string} pattern - String to search for
   * @returns {boolean} True if pattern found
   */
  contains(pattern) {
    return this.logs.some(log => log.text.includes(pattern));
  }

  /**
   * Assert that logs contain the specified pattern.
   * Throws an error if not found.
   *
   * @param {string} pattern - String that must be present
   * @param {string} message - Optional custom error message
   */
  assertContains(pattern, message = null) {
    if (!this.contains(pattern)) {
      const errorMsg = message || `Console logs should contain "${pattern}" but did not.\nCaptured logs:\n${this.formatLogs()}`;
      throw new Error(errorMsg);
    }
  }

  /**
   * Assert that logs do NOT contain the specified pattern.
   * Throws an error if found.
   *
   * @param {string} pattern - String that must NOT be present
   * @param {string} message - Optional custom error message
   */
  assertNotContains(pattern, message = null) {
    if (this.contains(pattern)) {
      const errorMsg = message || `Console logs should NOT contain "${pattern}" but did.\nMatching logs:\n${this.formatLogs(this.getLogsMatching(pattern))}`;
      throw new Error(errorMsg);
    }
  }

  /**
   * Assert that no errors were logged.
   *
   * @param {string[]} ignore - Optional patterns to ignore
   */
  assertNoErrors(ignore = []) {
    const errors = this.getLogsByType('error').filter(log => {
      return !ignore.some(pattern => log.text.includes(pattern));
    });

    if (errors.length > 0) {
      throw new Error(`Console errors were logged:\n${this.formatLogs(errors)}`);
    }
  }

  /**
   * Format logs as a readable string.
   *
   * @param {Array} logs - Logs to format (defaults to all)
   * @returns {string} Formatted log string
   */
  formatLogs(logs = null) {
    const logsToFormat = logs || this.logs;
    return logsToFormat.map(log => {
      return `[${log.timestamp}] [${log.type.toUpperCase()}] ${log.text}`;
    }).join('\n');
  }

  /**
   * Save logs to a file.
   *
   * @param {string} filePath - Path to save logs to
   */
  async saveToFile(filePath) {
    const dir = path.dirname(filePath);

    // Ensure directory exists
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    const content = [
      `# Console Logs: ${this.name}`,
      `# Captured: ${new Date().toISOString()}`,
      `# Total entries: ${this.logs.length}`,
      '',
      this.formatLogs(),
    ].join('\n');

    fs.writeFileSync(filePath, content);
  }

  /**
   * Clear all captured logs.
   */
  clear() {
    this.logs = [];
  }

  /**
   * Get a summary of captured logs.
   *
   * @returns {Object} Summary with counts by type
   */
  getSummary() {
    const summary = {
      total: this.logs.length,
      byType: {},
    };

    this.logs.forEach(log => {
      summary.byType[log.type] = (summary.byType[log.type] || 0) + 1;
    });

    return summary;
  }

  /**
   * Print logs to console (for debugging).
   */
  print() {
    console.log(`\n=== Console Logs: ${this.name} ===`);
    console.log(this.formatLogs());
    console.log('=== End Logs ===\n');
  }
}

/**
 * Create console captures for both browsers in a pair.
 *
 * @param {Object} creator - Creator browser object with page property
 * @param {Object} joiner - Joiner browser object with page property
 * @returns {Object} Object with creatorLogs and joinerLogs
 */
function createCapturePair(creator, joiner) {
  const creatorLogs = new ConsoleCapture(creator.page, 'creator');
  const joinerLogs = new ConsoleCapture(joiner.page, 'joiner');

  creatorLogs.captureAll();
  joinerLogs.captureAll();

  return { creatorLogs, joinerLogs };
}

module.exports = {
  ConsoleCapture,
  createCapturePair,
};
