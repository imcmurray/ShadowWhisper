/**
 * Auto-Fix Orchestrator
 *
 * Coordinates the automated bug-fixing workflow:
 * 1. Receive failing test results
 * 2. Generate bug reports
 * 3. Invoke Claude Code for fixes
 * 4. Restart Flutter app
 * 5. Re-run tests
 * 6. Track resolution
 */

const path = require('path');
const BugReportGenerator = require('./bug-report-generator');
const ClaudeInvoker = require('./claude-invoker');
const FlutterController = require('./flutter-controller');
const autoFixConfig = require('../config/auto-fix.config');

class AutoFixOrchestrator {
  constructor(options = {}) {
    this.maxRetries = options.maxRetries || autoFixConfig.maxRetries;
    this.outputDir = options.outputDir || path.join(__dirname, '..', 'output');
    this.projectRoot = options.projectRoot || path.join(__dirname, '..', '..', '..', '..');
    this.verbose = options.verbose !== false;

    this.flutterController = new FlutterController({
      projectRoot: this.projectRoot,
      verbose: this.verbose,
    });

    this.bugReportGenerator = new BugReportGenerator({
      outputDir: this.outputDir,
      verbose: this.verbose,
    });

    this.claudeInvoker = new ClaudeInvoker({
      projectRoot: this.projectRoot,
      verbose: this.verbose,
    });

    this.resolutionLog = [];
  }

  log(message) {
    if (this.verbose) {
      console.log(`[AutoFix] ${message}`);
    }
  }

  /**
   * Attempt to fix a failing test.
   *
   * @param {Object} failedTestResult - The failed test result with error info
   * @param {Object} testModule - The test module for re-running
   * @param {Function} runTestFn - Function to run a single test
   * @returns {Object} Resolution result
   */
  async attemptFix(failedTestResult, testModule, runTestFn) {
    const testName = failedTestResult.name;
    let attempt = 0;
    let fixed = false;

    this.log(`\n${'═'.repeat(60)}`);
    this.log(`AUTO-FIX: ${testName}`);
    this.log(`${'═'.repeat(60)}`);

    while (attempt < this.maxRetries && !fixed) {
      attempt++;
      this.log(`\nAttempt ${attempt}/${this.maxRetries}`);

      try {
        // Step 1: Generate bug report
        this.log('Generating bug report...');
        const bugReport = await this.bugReportGenerator.generate(failedTestResult);

        // Step 2: Save bug report for reference
        await this.bugReportGenerator.save(bugReport);

        // Step 3: Check if Claude is available
        const claudeAvailable = await this.claudeInvoker.isAvailable();
        if (!claudeAvailable) {
          this.log('ERROR: Claude CLI not found in PATH');
          this.logResolution(testName, attempt, 'claude_not_found', 'Claude CLI not available');
          break;
        }

        // Step 4: Invoke Claude Code to fix
        this.log('Invoking Claude to fix...');
        const fixResult = await this.claudeInvoker.requestFix(bugReport);

        if (!fixResult.success) {
          this.log(`Claude failed: ${fixResult.error}`);
          this.logResolution(testName, attempt, 'claude_error', fixResult.error);

          // Update the failed result with new info for next attempt
          failedTestResult = {
            ...failedTestResult,
            error: `Previous fix attempt failed: ${fixResult.error}. Original error: ${failedTestResult.error}`,
          };
          continue;
        }

        if (!fixResult.fixApplied) {
          this.log('Claude did not apply any changes');
          this.logResolution(testName, attempt, 'no_fix_applied', 'Claude completed but made no changes');
          continue;
        }

        this.log(`Fix applied. Files changed: ${fixResult.filesChanged.join(', ') || 'unknown'}`);

        // Step 5: Restart Flutter app
        this.log('Restarting Flutter app...');
        try {
          await this.flutterController.restart();
        } catch (restartError) {
          this.log(`Flutter restart failed: ${restartError.message}`);
          this.logResolution(testName, attempt, 'restart_failed', restartError.message);
          continue;
        }

        // Step 6: Re-run the failing test
        this.log('Re-running test...');
        const rerunResult = await runTestFn(testModule);

        if (rerunResult.status === 'passed') {
          fixed = true;
          this.logResolution(testName, attempt, 'fixed', null, fixResult.filesChanged);
          this.log(`\n${'★'.repeat(20)}`);
          this.log(`SUCCESS: ${testName} is now passing!`);
          this.log(`${'★'.repeat(20)}`);
        } else {
          this.log(`Test still failing: ${rerunResult.error}`);
          this.logResolution(testName, attempt, 'still_failing', rerunResult.error);

          // Update for next attempt
          failedTestResult = {
            ...failedTestResult,
            ...rerunResult,
          };
        }
      } catch (error) {
        this.log(`Unexpected error: ${error.message}`);
        this.logResolution(testName, attempt, 'error', error.message);
      }
    }

    if (!fixed) {
      this.log(`\n✗ Could not fix ${testName} after ${attempt} attempts`);
    }

    return {
      testName,
      fixed,
      attempts: attempt,
      resolution: this.resolutionLog.filter(r => r.testName === testName),
    };
  }

  /**
   * Log a resolution attempt.
   */
  logResolution(testName, attempt, status, error, filesChanged = []) {
    this.resolutionLog.push({
      timestamp: new Date().toISOString(),
      testName,
      attempt,
      status,
      error,
      filesChanged,
    });
  }

  /**
   * Get the full resolution log.
   */
  getResolutionLog() {
    return this.resolutionLog;
  }

  /**
   * Get a summary of all fix attempts.
   */
  getSummary() {
    const testNames = [...new Set(this.resolutionLog.map(r => r.testName))];

    return {
      totalTests: testNames.length,
      fixed: testNames.filter(name =>
        this.resolutionLog.some(r => r.testName === name && r.status === 'fixed')
      ).length,
      notFixed: testNames.filter(name =>
        !this.resolutionLog.some(r => r.testName === name && r.status === 'fixed')
      ).length,
      details: testNames.map(name => {
        const attempts = this.resolutionLog.filter(r => r.testName === name);
        const lastAttempt = attempts[attempts.length - 1];
        return {
          testName: name,
          attempts: attempts.length,
          finalStatus: lastAttempt?.status || 'unknown',
          error: lastAttempt?.error,
        };
      }),
    };
  }

  /**
   * Print a summary of the auto-fix results.
   */
  printSummary() {
    const summary = this.getSummary();

    console.log('\n' + '═'.repeat(60));
    console.log('AUTO-FIX SUMMARY');
    console.log('═'.repeat(60));
    console.log(`Total tests attempted: ${summary.totalTests}`);
    console.log(`Fixed: ${summary.fixed}`);
    console.log(`Not fixed: ${summary.notFixed}`);

    if (summary.details.length > 0) {
      console.log('\nDetails:');
      for (const detail of summary.details) {
        const icon = detail.finalStatus === 'fixed' ? '✓' : '✗';
        console.log(`  ${icon} ${detail.testName}`);
        console.log(`    Status: ${detail.finalStatus}`);
        console.log(`    Attempts: ${detail.attempts}`);
        if (detail.error) {
          console.log(`    Error: ${detail.error.substring(0, 100)}...`);
        }
      }
    }

    console.log('═'.repeat(60));

    return summary;
  }
}

module.exports = AutoFixOrchestrator;
