/**
 * Claude Invoker
 *
 * Invokes Claude Code CLI to analyze bug reports and apply fixes.
 * Uses --print mode for non-interactive operation.
 */

const { spawn } = require('child_process');
const path = require('path');
const autoFixConfig = require('../config/auto-fix.config');

class ClaudeInvoker {
  constructor(options = {}) {
    this.projectRoot = options.projectRoot || path.join(__dirname, '..', '..', '..', '..');
    this.timeout = options.timeout || autoFixConfig.claudeTimeout;
    this.model = options.model || autoFixConfig.claudeModel;
    this.verbose = options.verbose !== false;
  }

  log(message) {
    if (this.verbose) {
      console.log(`[ClaudeInvoker] ${message}`);
    }
  }

  /**
   * Request a fix from Claude Code CLI.
   */
  async requestFix(bugReport) {
    const prompt = this.buildPrompt(bugReport);

    this.log('Invoking Claude Code CLI...');
    this.log(`Working directory: ${this.projectRoot}`);

    return new Promise((resolve) => {
      let output = '';
      let errorOutput = '';
      let timedOut = false;

      const claude = spawn('claude', [
        '--print',
        '--model', this.model,
        prompt,
      ], {
        cwd: this.projectRoot,
        env: { ...process.env },
        stdio: ['ignore', 'pipe', 'pipe'],
      });

      claude.stdout.on('data', (data) => {
        const text = data.toString();
        output += text;
        if (this.verbose) {
          // Print progress indicators
          if (text.includes('Reading') || text.includes('Editing') || text.includes('Writing')) {
            console.log(`[Claude] ${text.trim()}`);
          }
        }
      });

      claude.stderr.on('data', (data) => {
        errorOutput += data.toString();
      });

      claude.on('close', (code) => {
        if (timedOut) return;

        if (code === 0) {
          const fixApplied = this.detectFixApplied(output);
          this.log(`Claude finished. Fix applied: ${fixApplied}`);

          resolve({
            success: true,
            output,
            fixApplied,
            filesChanged: this.extractChangedFiles(output),
          });
        } else {
          this.log(`Claude exited with code ${code}`);
          resolve({
            success: false,
            error: errorOutput || `Claude exited with code ${code}`,
            output,
          });
        }
      });

      claude.on('error', (err) => {
        if (timedOut) return;

        this.log(`Failed to spawn Claude: ${err.message}`);
        resolve({
          success: false,
          error: `Failed to spawn Claude: ${err.message}`,
        });
      });

      // Timeout handling
      const timeoutId = setTimeout(() => {
        timedOut = true;
        this.log('Claude invocation timed out');
        claude.kill('SIGTERM');

        setTimeout(() => {
          try {
            claude.kill('SIGKILL');
          } catch (e) {
            // Already dead
          }
        }, 5000);

        resolve({
          success: false,
          error: `Claude invocation timed out after ${this.timeout / 1000}s`,
          output,
        });
      }, this.timeout);

      // Clear timeout on successful completion
      claude.on('close', () => {
        clearTimeout(timeoutId);
      });
    });
  }

  /**
   * Build the prompt for Claude based on the bug report.
   */
  buildPrompt(bugReport) {
    const errorLogs = bugReport.consoleLogs.errors
      .map(e => e.text)
      .join('\n') || 'No errors captured';

    const warningLogs = bugReport.consoleLogs.warnings
      .map(w => w.text)
      .slice(0, 10) // Limit warnings
      .join('\n') || 'No warnings captured';

    const suggestedFiles = bugReport.analysis.suggestedFiles
      .map(f => `- ${f}`)
      .join('\n') || '- Check lib/core/networking/ for P2P issues\n- Check lib/features/ for UI issues';

    const hints = bugReport.analysis.hints
      .map(h => `- ${h}`)
      .join('\n') || '- Review the error message carefully';

    return `
You are fixing a failing E2E test in a Flutter web application (ShadowWhisper).
This is an automated fix request - apply the fix directly without asking questions.

## Bug Report

**Test Name:** ${bugReport.test.name}
**Test File:** ${bugReport.test.file}
**Error Type:** ${bugReport.error.type}
**Likely Category:** ${bugReport.analysis.likelyCategory}

### Error Message
\`\`\`
${bugReport.error.message}
\`\`\`

${bugReport.error.stackTrace ? `### Stack Trace\n\`\`\`\n${bugReport.error.stackTrace}\n\`\`\`\n` : ''}

### Console Errors (from browser)
\`\`\`
${errorLogs}
\`\`\`

### Console Warnings (first 10)
\`\`\`
${warningLogs}
\`\`\`

### Test Source Code
\`\`\`javascript
${bugReport.test.sourceCode}
\`\`\`

### Suggested Files to Check
${suggestedFiles}

### Hints
${hints}

## Your Task

1. Analyze the error and identify the root cause
2. Find and read the relevant source file(s) that need modification
3. Apply a minimal, targeted fix to resolve the issue
4. Do NOT add comments explaining the fix - just fix the code

Important context:
- This is a Flutter web app with P2P WebRTC communication
- Tests use Playwright with coordinate-based clicking (Flutter renders to canvas)
- If the issue is in test code (tests/e2e/), fix the test file
- If the issue is in app code (lib/), fix the Dart source files
- The app uses Riverpod for state management
- P2P networking uses WebRTC data channels

Please analyze and fix this issue now.
`.trim();
  }

  /**
   * Detect if a fix was actually applied based on output.
   */
  detectFixApplied(output) {
    const fixIndicators = [
      'edited',
      'modified',
      'changed',
      'updated',
      'wrote',
      'created',
      'fixed',
      'edit',
    ];

    const lowerOutput = output.toLowerCase();
    return fixIndicators.some(indicator => lowerOutput.includes(indicator));
  }

  /**
   * Extract file names that were changed.
   */
  extractChangedFiles(output) {
    const files = [];

    // Look for common patterns in Claude output
    const patterns = [
      /(?:edited|modified|updated|wrote|created)\s+[`"]?([^\s`"]+\.(dart|js))[`"]?/gi,
      /file:\s*([^\s]+\.(dart|js))/gi,
    ];

    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(output)) !== null) {
        if (match[1]) {
          files.push(match[1]);
        }
      }
    }

    return [...new Set(files)];
  }

  /**
   * Check if Claude CLI is available.
   */
  async isAvailable() {
    return new Promise((resolve) => {
      const check = spawn('which', ['claude']);
      check.on('close', (code) => {
        resolve(code === 0);
      });
      check.on('error', () => {
        resolve(false);
      });
    });
  }
}

module.exports = ClaudeInvoker;
