/**
 * Bug Report Generator
 *
 * Creates comprehensive, structured bug reports from test failures
 * that can be consumed by Claude Code for automated fixing.
 */

const fs = require('fs');
const path = require('path');
const autoFixConfig = require('../config/auto-fix.config');

class BugReportGenerator {
  constructor(options = {}) {
    this.outputDir = options.outputDir || path.join(__dirname, '..', 'output');
    this.reportsDir = path.join(this.outputDir, 'bug-reports');
    this.specsDir = path.join(__dirname, '..', 'specs');
    this.verbose = options.verbose !== false;
  }

  log(message) {
    if (this.verbose) {
      console.log(`[BugReportGenerator] ${message}`);
    }
  }

  /**
   * Generate a bug report from a failed test result.
   */
  async generate(failedTestResult) {
    const {
      name,
      file,
      error,
      duration,
      stackTrace,
      consoleLogs,
      screenshots,
    } = failedTestResult;

    this.log(`Generating bug report for: ${name}`);

    // Read the test source code for context
    const testSourceCode = this.readTestSource(file);

    // Extract relevant file references from error/stack
    const relevantFiles = this.extractRelevantFiles(stackTrace || error || '');

    const bugReport = {
      id: `bug-${Date.now()}`,
      timestamp: new Date().toISOString(),

      // Test Information
      test: {
        name,
        file,
        sourceCode: testSourceCode,
        duration,
      },

      // Error Details
      error: {
        message: error || 'Unknown error',
        stackTrace: stackTrace || null,
        type: this.classifyError(error),
      },

      // Console Logs
      consoleLogs: {
        creator: consoleLogs?.creator || [],
        joiner: consoleLogs?.joiner || [],
        errors: this.filterLogsByType(consoleLogs, 'error'),
        warnings: this.filterLogsByType(consoleLogs, 'warning'),
      },

      // Screenshots
      screenshots: screenshots || [],

      // Context
      context: {
        relevantFiles,
        appUrl: 'http://localhost:8080',
        testFramework: 'Playwright (coordinate-based Flutter testing)',
        projectType: 'Flutter web app with P2P WebRTC',
      },

      // Analysis (computed hints for the fixing agent)
      analysis: {
        likelyCategory: this.categorizeFailure(error, consoleLogs),
        suggestedFiles: this.suggestFiles(error, consoleLogs, relevantFiles),
        hints: this.generateHints(error, consoleLogs),
      },
    };

    return bugReport;
  }

  /**
   * Read the test source code file.
   */
  readTestSource(relativeFile) {
    try {
      // Handle both relative and absolute paths
      let fullPath;
      if (path.isAbsolute(relativeFile)) {
        fullPath = relativeFile;
      } else {
        fullPath = path.join(this.specsDir, relativeFile);
      }

      if (fs.existsSync(fullPath)) {
        return fs.readFileSync(fullPath, 'utf8');
      }

      // Try without specs dir
      fullPath = path.join(__dirname, '..', relativeFile);
      if (fs.existsSync(fullPath)) {
        return fs.readFileSync(fullPath, 'utf8');
      }

      return `[Could not find test source file: ${relativeFile}]`;
    } catch (e) {
      return `[Could not read test source: ${e.message}]`;
    }
  }

  /**
   * Extract file paths mentioned in error text.
   */
  extractRelevantFiles(errorText) {
    if (!errorText) return [];

    const patterns = [
      /lib\/[^\s:'"]+\.dart/g,      // Dart files
      /tests\/[^\s:'"]+\.js/g,      // Test files
      /specs\/[^\s:'"]+\.spec\.js/g, // Spec files
    ];

    const matches = [];
    for (const pattern of patterns) {
      const found = errorText.match(pattern) || [];
      matches.push(...found);
    }

    return [...new Set(matches)];
  }

  /**
   * Classify the error type based on message.
   */
  classifyError(error) {
    if (!error) return 'unknown';

    const lowerError = error.toLowerCase();

    if (lowerError.includes('timeout')) return 'timeout';
    if (lowerError.includes('click') || lowerError.includes('coordinate')) return 'ui_interaction';
    if (lowerError.includes('p2p') || lowerError.includes('webrtc') || lowerError.includes('ice')) return 'networking';
    if (lowerError.includes('assert')) return 'assertion';
    if (lowerError.includes('flutter') && lowerError.includes('load')) return 'flutter_load';
    if (lowerError.includes('null') || lowerError.includes('undefined')) return 'null_reference';
    if (lowerError.includes('dispose') || lowerError.includes('mounted')) return 'widget_lifecycle';

    return 'runtime';
  }

  /**
   * Categorize the failure for high-level understanding.
   */
  categorizeFailure(error, consoleLogs) {
    const allText = this.getAllText(error, consoleLogs);

    if (allText.includes('webrtc') || allText.includes('ice') || allText.includes('signaling')) {
      return 'P2P Connection Issue';
    }
    if (allText.includes('timeout')) {
      return 'Timing/Timeout Issue';
    }
    if (allText.includes('null') || allText.includes('undefined')) {
      return 'Null Reference Error';
    }
    if (allText.includes('dispose') || allText.includes('mounted')) {
      return 'Widget Lifecycle Issue';
    }
    if (allText.includes('coordinate') || allText.includes('click')) {
      return 'UI Interaction Issue';
    }
    if (allText.includes('participant')) {
      return 'Participant State Issue';
    }

    return 'General Test Failure';
  }

  /**
   * Combine all text for analysis.
   */
  getAllText(error, consoleLogs) {
    const parts = [error || ''];

    if (consoleLogs?.creator) {
      parts.push(...consoleLogs.creator.map(l => l.text || ''));
    }
    if (consoleLogs?.joiner) {
      parts.push(...consoleLogs.joiner.map(l => l.text || ''));
    }

    return parts.join(' ').toLowerCase();
  }

  /**
   * Filter console logs by type.
   */
  filterLogsByType(consoleLogs, type) {
    const allLogs = [
      ...(consoleLogs?.creator || []),
      ...(consoleLogs?.joiner || []),
    ];
    return allLogs.filter(l => l.type === type);
  }

  /**
   * Suggest files that might need fixing.
   */
  suggestFiles(error, consoleLogs, extractedFiles) {
    const suggestions = [...extractedFiles];
    const allText = this.getAllText(error, consoleLogs);

    // Add common files based on error patterns
    if (allText.includes('p2p') || allText.includes('webrtc')) {
      suggestions.push('lib/core/networking/p2p_manager.dart');
      suggestions.push('lib/core/networking/p2p_provider.dart');
      suggestions.push('lib/core/networking/peer_connection.dart');
    }

    if (allText.includes('participant')) {
      suggestions.push('lib/features/room/providers/room_provider.dart');
    }

    if (allText.includes('message') || allText.includes('chat')) {
      suggestions.push('lib/features/chat/presentation/widgets/message_list.dart');
    }

    if (allText.includes('reaction')) {
      suggestions.push('lib/core/networking/p2p_message.dart');
    }

    return [...new Set(suggestions)].slice(0, 5);
  }

  /**
   * Generate hints for the fixing agent.
   */
  generateHints(error, consoleLogs) {
    const hints = [];
    const allText = this.getAllText(error, consoleLogs);

    if (allText.includes('timeout')) {
      hints.push('Consider increasing timeout values or adding explicit waits');
      hints.push('Check if the Flutter app is rendering slowly');
    }

    if (allText.includes('p2p') || allText.includes('webrtc')) {
      hints.push('Check WebRTC connection establishment in p2p_manager.dart');
      hints.push('Verify signaling messages are being exchanged correctly');
    }

    if (allText.includes('coordinate') || allText.includes('click')) {
      hints.push('UI coordinates may have changed - check config/coordinates.js');
      hints.push('Ensure Flutter widgets are rendered at expected positions');
    }

    if (allText.includes('dispose') || allText.includes('mounted')) {
      hints.push('Check widget lifecycle - callbacks may fire after disposal');
      hints.push('Use mounted checks before setState or accessing refs');
    }

    const errors = this.filterLogsByType(consoleLogs, 'error');
    if (errors.length > 0) {
      hints.push('Console errors detected - review error logs for root cause');
    }

    if (hints.length === 0) {
      hints.push('Review the test source code and error message carefully');
    }

    return hints;
  }

  /**
   * Save the bug report to disk.
   */
  async save(bugReport) {
    if (!autoFixConfig.saveBugReports) {
      return null;
    }

    if (!fs.existsSync(this.reportsDir)) {
      fs.mkdirSync(this.reportsDir, { recursive: true });
    }

    const filename = `${bugReport.id}.json`;
    const filepath = path.join(this.reportsDir, filename);

    fs.writeFileSync(filepath, JSON.stringify(bugReport, null, 2));
    this.log(`Saved bug report: ${filepath}`);

    return filepath;
  }
}

module.exports = BugReportGenerator;
