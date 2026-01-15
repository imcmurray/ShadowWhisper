/**
 * Test Reporter - Generate JSON reports for test runs
 *
 * Produces machine-readable JSON reports that can be used for:
 * - CI integration
 * - Historical tracking
 * - Dashboard visualization
 */

const fs = require('fs');
const path = require('path');

class Reporter {
  constructor() {
    this.startTime = Date.now();
  }

  /**
   * Generate a JSON report from test results.
   *
   * @param {Object[]} results - Array of test results
   * @param {string} outputDir - Directory to write report to
   * @returns {Object} Summary of the test run
   */
  generateReport(results, outputDir) {
    const endTime = Date.now();
    const duration = endTime - this.startTime;

    const summary = {
      total: results.length,
      passed: results.filter(r => r.status === 'passed').length,
      failed: results.filter(r => r.status === 'failed').length,
      skipped: results.filter(r => r.status === 'skipped').length,
      duration,
    };

    const report = {
      timestamp: new Date().toISOString(),
      duration,
      summary,
      tests: results.map(r => ({
        name: r.name,
        file: r.file,
        status: r.status,
        duration: r.duration,
        error: r.error || null,
      })),
    };

    // Write JSON report
    const reportPath = path.join(outputDir, 'reports', 'test-results.json');
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    // Also write a latest.json symlink/copy for easy access
    const latestPath = path.join(outputDir, 'reports', 'latest.json');
    fs.writeFileSync(latestPath, JSON.stringify(report, null, 2));

    // Generate console-friendly summary
    this.printSummary(summary, results);

    return summary;
  }

  /**
   * Print a console-friendly summary.
   *
   * @param {Object} summary - Summary stats
   * @param {Object[]} results - Test results
   */
  printSummary(summary, results) {
    const failedTests = results.filter(r => r.status === 'failed');

    if (failedTests.length > 0) {
      console.log('\nFailed Tests:');
      for (const test of failedTests) {
        console.log(`  ✗ ${test.name}`);
        console.log(`    ${test.error}`);
      }
    }

    // Color-coded pass rate
    const passRate = summary.total > 0
      ? Math.round((summary.passed / summary.total) * 100)
      : 0;

    let status;
    if (summary.failed === 0) {
      status = 'ALL TESTS PASSED';
    } else {
      status = `${summary.failed} TEST(S) FAILED`;
    }

    console.log(`\n${status} (${passRate}% pass rate)`);
  }

  /**
   * Generate an HTML report (bonus feature).
   *
   * @param {Object[]} results - Array of test results
   * @param {string} outputDir - Directory to write report to
   */
  generateHtmlReport(results, outputDir) {
    const summary = {
      total: results.length,
      passed: results.filter(r => r.status === 'passed').length,
      failed: results.filter(r => r.status === 'failed').length,
    };

    const passRate = summary.total > 0
      ? Math.round((summary.passed / summary.total) * 100)
      : 0;

    const html = `<!DOCTYPE html>
<html>
<head>
  <title>Test Results - ${new Date().toLocaleDateString()}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; }
    h1 { color: #333; }
    .summary { background: #f5f5f5; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
    .summary-stat { display: inline-block; margin-right: 30px; }
    .summary-stat .value { font-size: 24px; font-weight: bold; }
    .summary-stat .label { color: #666; }
    .passed { color: #22c55e; }
    .failed { color: #ef4444; }
    .test-list { list-style: none; padding: 0; }
    .test-item { padding: 15px; border-bottom: 1px solid #eee; }
    .test-item:hover { background: #f9f9f9; }
    .test-name { font-weight: 500; }
    .test-file { color: #666; font-size: 12px; margin-left: 10px; }
    .test-duration { float: right; color: #999; }
    .test-error { color: #ef4444; margin-top: 10px; font-family: monospace; font-size: 12px; }
    .icon { margin-right: 8px; }
  </style>
</head>
<body>
  <h1>Test Results</h1>
  <p>Generated: ${new Date().toISOString()}</p>

  <div class="summary">
    <div class="summary-stat">
      <div class="value">${summary.total}</div>
      <div class="label">Total</div>
    </div>
    <div class="summary-stat passed">
      <div class="value">${summary.passed}</div>
      <div class="label">Passed</div>
    </div>
    <div class="summary-stat failed">
      <div class="value">${summary.failed}</div>
      <div class="label">Failed</div>
    </div>
    <div class="summary-stat">
      <div class="value">${passRate}%</div>
      <div class="label">Pass Rate</div>
    </div>
  </div>

  <h2>Tests</h2>
  <ul class="test-list">
    ${results.map(r => `
    <li class="test-item">
      <span class="icon ${r.status}">${r.status === 'passed' ? '✓' : '✗'}</span>
      <span class="test-name ${r.status}">${r.name}</span>
      <span class="test-file">${r.file}</span>
      <span class="test-duration">${r.duration}ms</span>
      ${r.error ? `<div class="test-error">${escapeHtml(r.error)}</div>` : ''}
    </li>
    `).join('')}
  </ul>
</body>
</html>`;

    const reportPath = path.join(outputDir, 'reports', 'test-results.html');
    fs.writeFileSync(reportPath, html);
  }
}

/**
 * Escape HTML special characters.
 *
 * @param {string} text - Text to escape
 * @returns {string} Escaped text
 */
function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = { Reporter };
