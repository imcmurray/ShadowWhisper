/**
 * Auto-Fix Configuration
 *
 * Settings for the automated bug-fixing workflow.
 */

module.exports = {
  // Retry limits
  maxRetries: 2,

  // Timeouts (ms)
  claudeTimeout: 300000,        // 5 minutes per fix attempt
  flutterStartupTimeout: 90000, // 90 seconds to start Flutter
  flutterShutdownTimeout: 10000, // 10 seconds to stop

  // Claude settings
  claudeModel: 'sonnet',        // Fast model for fixes

  // Flutter settings
  flutterPort: 8080,
  flutterDevice: 'chrome',

  // Output
  saveBugReports: true,
  bugReportsDir: 'output/bug-reports',

  // Behavior
  stopOnFirstFix: false,        // Continue fixing other tests
  rerunAllAfterFix: false,      // Just rerun the fixed test
  verbose: true,                // Show detailed logs
};
