#!/usr/bin/env node

/**
 * Test Runner - Central test discovery and execution for dual-browser tests
 *
 * Features:
 * - Discovers all *.spec.js files recursively in specs/
 * - Run all tests or filter by name/directory
 * - Sequential execution for easier debugging
 * - JSON report generation
 * - Proper exit codes for CI integration
 * - Auto-fix mode: automatically fix failing tests using Claude Code
 *
 * Usage:
 *   node test-runner.js                    # Run all tests
 *   node test-runner.js room-join          # Run tests matching "room-join"
 *   node test-runner.js --dir room         # Run all tests in room/ directory
 *   node test-runner.js --list             # List all available tests
 *   node test-runner.js --auto-fix         # Auto-fix failing tests
 */

const fs = require('fs');
const path = require('path');
const { Reporter } = require('./reporter');

// Configuration
const SPECS_DIR = path.join(__dirname, '..', 'specs');
const OUTPUT_DIR = path.join(__dirname, '..', 'output');
const DEFAULT_TIMEOUT = 120000; // 2 minutes per test

/**
 * Recursively find all spec files.
 *
 * @param {string} dir - Directory to search
 * @param {string[]} files - Accumulator for found files
 * @returns {string[]} Array of spec file paths
 */
function discoverTests(dir, files = []) {
  if (!fs.existsSync(dir)) {
    console.error(`Specs directory not found: ${dir}`);
    return files;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      discoverTests(fullPath, files);
    } else if (entry.name.endsWith('.spec.js')) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Load a test module and validate its structure.
 *
 * @param {string} filePath - Path to spec file
 * @returns {Object|null} Test module or null if invalid
 */
function loadTest(filePath) {
  try {
    const testModule = require(filePath);

    // Validate required properties
    if (!testModule.name || typeof testModule.name !== 'string') {
      console.warn(`Warning: ${filePath} missing 'name' property`);
      return null;
    }

    if (!testModule.run || typeof testModule.run !== 'function') {
      console.warn(`Warning: ${filePath} missing 'run' function`);
      return null;
    }

    return {
      name: testModule.name,
      run: testModule.run,
      timeout: testModule.timeout || DEFAULT_TIMEOUT,
      filePath,
      relativePath: path.relative(SPECS_DIR, filePath),
    };
  } catch (error) {
    console.error(`Error loading ${filePath}: ${error.message}`);
    return null;
  }
}

/**
 * Run a single test with timeout handling.
 *
 * @param {Object} test - Test object with name and run function
 * @returns {Object} Test result with enhanced error info for auto-fix
 */
async function runTest(test) {
  const startTime = Date.now();
  const result = {
    name: test.name,
    file: test.relativePath,
    status: 'pending',
    duration: 0,
    error: null,
    stackTrace: null,      // For auto-fix bug reports
    consoleLogs: null,     // Will be populated if available
    screenshots: [],       // Will be populated if available
  };

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`Running: ${test.name}`);
  console.log(`File: ${test.relativePath}`);
  console.log(`${'─'.repeat(60)}`);

  try {
    // Create timeout promise
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => {
        reject(new Error(`Test timed out after ${test.timeout}ms`));
      }, test.timeout);
    });

    // Race the test against timeout
    await Promise.race([test.run(), timeoutPromise]);

    result.status = 'passed';
    console.log(`✓ PASSED (${Date.now() - startTime}ms)`);
  } catch (error) {
    result.status = 'failed';
    result.error = error.message;
    result.stackTrace = error.stack || null;
    console.error(`✗ FAILED: ${error.message}`);

    // Print stack trace for debugging
    if (error.stack) {
      console.error('\nStack trace:');
      console.error(error.stack.split('\n').slice(1, 5).join('\n'));
    }
  }

  result.duration = Date.now() - startTime;
  return result;
}

/**
 * Filter tests based on command-line arguments.
 *
 * @param {Object[]} tests - All discovered tests
 * @param {Object} options - Filter options
 * @returns {Object[]} Filtered tests
 */
function filterTests(tests, options) {
  let filtered = tests;

  // Filter by directory
  if (options.dir) {
    filtered = filtered.filter(t =>
      t.relativePath.startsWith(options.dir + path.sep) ||
      t.relativePath.startsWith(options.dir + '/')
    );
  }

  // Filter by name pattern
  if (options.pattern) {
    const pattern = options.pattern.toLowerCase();
    filtered = filtered.filter(t =>
      t.name.toLowerCase().includes(pattern) ||
      t.relativePath.toLowerCase().includes(pattern)
    );
  }

  return filtered;
}

/**
 * Parse command-line arguments.
 *
 * @returns {Object} Parsed options
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    pattern: null,
    dir: null,
    list: false,
    help: false,
    autoFix: false,
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--list' || arg === '-l') {
      options.list = true;
    } else if (arg === '--dir' || arg === '-d') {
      options.dir = args[++i];
    } else if (arg === '--auto-fix' || arg === '--autofix') {
      options.autoFix = true;
    } else if (!arg.startsWith('-')) {
      options.pattern = arg;
    }
  }

  return options;
}

/**
 * Print help message.
 */
function printHelp() {
  console.log(`
Dual-Browser E2E Test Runner

Usage:
  node test-runner.js [options] [pattern]

Options:
  -h, --help      Show this help message
  -l, --list      List all available tests
  -d, --dir DIR   Run tests only in specified directory
  --auto-fix      Automatically fix failing tests using Claude Code

Examples:
  node test-runner.js                    # Run all tests
  node test-runner.js room-join          # Run tests matching "room-join"
  node test-runner.js --dir room         # Run tests in room/ subdirectory
  node test-runner.js --list             # List all tests without running
  node test-runner.js --auto-fix         # Run and auto-fix any failures

Auto-Fix Mode:
  When --auto-fix is enabled, the runner will:
  1. Run all tests normally
  2. For each failing test, generate a bug report
  3. Invoke Claude Code CLI to analyze and fix the issue
  4. Restart the Flutter app
  5. Re-run the test to verify the fix
  6. Retry up to 2 times per failing test

Test File Format:
  module.exports = {
    name: 'My Test Name',
    timeout: 60000,  // optional, defaults to 120000ms
    run: async () => {
      // test implementation
    }
  };
`);
}

/**
 * Main entry point.
 */
async function main() {
  const options = parseArgs();

  if (options.help) {
    printHelp();
    process.exit(0);
  }

  // Ensure output directories exist
  const dirs = ['screenshots', 'logs', 'reports', 'bug-reports'].map(d => path.join(OUTPUT_DIR, d));
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }

  // Discover tests
  console.log('Discovering tests...');
  const specFiles = discoverTests(SPECS_DIR);
  const allTests = specFiles
    .map(loadTest)
    .filter(t => t !== null)
    .sort((a, b) => a.relativePath.localeCompare(b.relativePath));

  console.log(`Found ${allTests.length} test(s)`);

  if (allTests.length === 0) {
    console.log('\nNo tests found. Create spec files in specs/ directory.');
    console.log('Example: specs/room/01-room-join.spec.js');
    process.exit(0);
  }

  // List mode
  if (options.list) {
    console.log('\nAvailable tests:');
    for (const test of allTests) {
      console.log(`  ${test.relativePath} - ${test.name}`);
    }
    process.exit(0);
  }

  // Filter tests
  const testsToRun = filterTests(allTests, options);

  if (testsToRun.length === 0) {
    console.log('\nNo tests match the filter criteria.');
    if (options.pattern) {
      console.log(`Pattern: "${options.pattern}"`);
    }
    if (options.dir) {
      console.log(`Directory: "${options.dir}"`);
    }
    console.log('\nUse --list to see all available tests.');
    process.exit(1);
  }

  // Show auto-fix warning
  if (options.autoFix) {
    console.log('\n⚠️  AUTO-FIX MODE ENABLED');
    console.log('    Failing tests will be automatically analyzed and fixed using Claude Code.');
    console.log('    The Flutter app will be restarted after each fix attempt.\n');
  }

  console.log(`\nRunning ${testsToRun.length} test(s)...`);
  console.log(`${'═'.repeat(60)}`);

  // Run tests
  const reporter = new Reporter();
  const results = [];

  for (const test of testsToRun) {
    const result = await runTest(test);
    results.push(result);
  }

  // Generate initial report
  console.log(`\n${'═'.repeat(60)}`);
  console.log('TEST RUN COMPLETE');
  console.log(`${'═'.repeat(60)}`);

  let summary = reporter.generateReport(results, OUTPUT_DIR);

  // Print summary
  console.log(`\nResults: ${summary.passed} passed, ${summary.failed} failed, ${summary.total} total`);
  console.log(`Duration: ${(summary.duration / 1000).toFixed(1)}s`);

  // Auto-fix mode
  if (options.autoFix && summary.failed > 0) {
    console.log('\n' + '═'.repeat(60));
    console.log('STARTING AUTO-FIX MODE');
    console.log('═'.repeat(60));

    const AutoFixOrchestrator = require('./auto-fix-orchestrator');
    const orchestrator = new AutoFixOrchestrator({
      outputDir: OUTPUT_DIR,
      projectRoot: path.join(__dirname, '..', '..', '..', '..'),
    });

    // Get failed tests
    const failedResults = results.filter(r => r.status === 'failed');

    for (const failedResult of failedResults) {
      // Find the test module
      const testModule = testsToRun.find(t => t.name === failedResult.name);
      if (testModule) {
        const fixResult = await orchestrator.attemptFix(failedResult, testModule, runTest);

        // Update results if fixed
        if (fixResult.fixed) {
          const idx = results.findIndex(r => r.name === failedResult.name);
          if (idx !== -1) {
            results[idx] = {
              ...results[idx],
              status: 'passed',
              error: null,
              autoFixed: true,
            };
          }
        }
      }
    }

    // Print auto-fix summary
    orchestrator.printSummary();

    // Regenerate report with updated results
    summary = reporter.generateReport(results, OUTPUT_DIR);
    console.log(`\nFinal Results: ${summary.passed} passed, ${summary.failed} failed, ${summary.total} total`);
  }

  console.log(`Report: ${path.join(OUTPUT_DIR, 'reports', 'test-results.json')}`);

  // Exit with appropriate code
  process.exit(summary.failed > 0 ? 1 : 0);
}

// Run if called directly
if (require.main === module) {
  main().catch(error => {
    console.error('Test runner failed:', error);
    process.exit(1);
  });
}

module.exports = { discoverTests, loadTest, runTest, filterTests };
