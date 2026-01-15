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
 *
 * Usage:
 *   node test-runner.js                    # Run all tests
 *   node test-runner.js room-join          # Run tests matching "room-join"
 *   node test-runner.js --dir room         # Run all tests in room/ directory
 *   node test-runner.js --list             # List all available tests
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
 * @returns {Object} Test result
 */
async function runTest(test) {
  const startTime = Date.now();
  const result = {
    name: test.name,
    file: test.relativePath,
    status: 'pending',
    duration: 0,
    error: null,
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
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--list' || arg === '-l') {
      options.list = true;
    } else if (arg === '--dir' || arg === '-d') {
      options.dir = args[++i];
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

Examples:
  node test-runner.js                    # Run all tests
  node test-runner.js room-join          # Run tests matching "room-join"
  node test-runner.js --dir room         # Run tests in room/ subdirectory
  node test-runner.js --list             # List all tests without running

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
  const dirs = ['screenshots', 'logs', 'reports'].map(d => path.join(OUTPUT_DIR, d));
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

  console.log(`\nRunning ${testsToRun.length} test(s)...`);
  console.log(`${'═'.repeat(60)}`);

  // Run tests
  const reporter = new Reporter();
  const results = [];

  for (const test of testsToRun) {
    const result = await runTest(test);
    results.push(result);
  }

  // Generate report
  console.log(`\n${'═'.repeat(60)}`);
  console.log('TEST RUN COMPLETE');
  console.log(`${'═'.repeat(60)}`);

  const summary = reporter.generateReport(results, OUTPUT_DIR);

  // Print summary
  console.log(`\nResults: ${summary.passed} passed, ${summary.failed} failed, ${summary.total} total`);
  console.log(`Duration: ${(summary.duration / 1000).toFixed(1)}s`);
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
