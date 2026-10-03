/**
 * Flutter Controller
 *
 * Manages the Flutter development server lifecycle:
 * - Find running Flutter process
 * - Gracefully stop it
 * - Restart on the same port
 * - Wait for ready state
 */

const { spawn, exec } = require('child_process');
const http = require('http');
const path = require('path');
const autoFixConfig = require('../config/auto-fix.config');

class FlutterController {
  constructor(options = {}) {
    this.port = options.port || autoFixConfig.flutterPort;
    this.device = options.device || autoFixConfig.flutterDevice;
    this.appUrl = `http://localhost:${this.port}`;
    this.projectRoot = options.projectRoot || path.join(__dirname, '..', '..', '..', '..');
    this.startupTimeout = options.startupTimeout || autoFixConfig.flutterStartupTimeout;
    this.shutdownTimeout = options.shutdownTimeout || autoFixConfig.flutterShutdownTimeout;
    this.flutterProcess = null;
    this.verbose = options.verbose !== false;
  }

  log(message) {
    if (this.verbose) {
      console.log(`[FlutterController] ${message}`);
    }
  }

  /**
   * Restart the Flutter app (stop then start).
   */
  async restart() {
    this.log('Restarting Flutter app...');

    await this.stop();
    await this.start();
    await this.waitForReady();

    this.log('Flutter app is ready');
  }

  /**
   * Stop any Flutter process using the port.
   */
  async stop() {
    this.log(`Stopping processes on port ${this.port}...`);

    return new Promise((resolve) => {
      // Find processes using the port
      exec(`lsof -ti:${this.port}`, (error, stdout) => {
        if (error || !stdout.trim()) {
          this.log('No process found on port');
          resolve();
          return;
        }

        const pids = stdout.trim().split('\n').filter(Boolean);
        this.log(`Found PIDs: ${pids.join(', ')}`);

        // Kill each process
        for (const pid of pids) {
          try {
            const pidNum = parseInt(pid, 10);
            if (!isNaN(pidNum)) {
              process.kill(pidNum, 'SIGTERM');
              this.log(`Sent SIGTERM to PID ${pidNum}`);
            }
          } catch (e) {
            // Process may already be dead
            this.log(`Could not kill PID ${pid}: ${e.message}`);
          }
        }

        // Wait for processes to terminate
        setTimeout(() => {
          // Force kill if still running
          exec(`lsof -ti:${this.port}`, (err, remaining) => {
            if (remaining && remaining.trim()) {
              const remainingPids = remaining.trim().split('\n').filter(Boolean);
              for (const pid of remainingPids) {
                try {
                  const pidNum = parseInt(pid, 10);
                  if (!isNaN(pidNum)) {
                    process.kill(pidNum, 'SIGKILL');
                    this.log(`Sent SIGKILL to PID ${pidNum}`);
                  }
                } catch (e) {
                  // Ignore
                }
              }
            }
            setTimeout(resolve, 1000);
          });
        }, 3000);
      });
    });
  }

  /**
   * Start Flutter dev server.
   */
  async start() {
    this.log(`Starting Flutter on port ${this.port}...`);

    return new Promise((resolve, reject) => {
      this.flutterProcess = spawn('flutter', [
        'run',
        '-d', this.device,
        '--web-port', this.port.toString(),
      ], {
        cwd: this.projectRoot,
        detached: true,
        stdio: ['ignore', 'pipe', 'pipe'],
      });

      // Don't wait for process to exit
      this.flutterProcess.unref();

      let started = false;
      let output = '';

      this.flutterProcess.stdout.on('data', (data) => {
        const text = data.toString();
        output += text;

        // Check for Flutter startup indicators
        if (!started && (
          text.includes('Flutter run key commands') ||
          text.includes('Syncing files to device') ||
          text.includes('lib/main.dart is being served')
        )) {
          started = true;
          this.log('Flutter process started');
          resolve();
        }
      });

      this.flutterProcess.stderr.on('data', (data) => {
        const text = data.toString();
        if (this.verbose && !text.includes('Waiting for')) {
          console.log(`[Flutter stderr] ${text.trim()}`);
        }
      });

      this.flutterProcess.on('error', (err) => {
        if (!started) {
          reject(new Error(`Failed to start Flutter: ${err.message}`));
        }
      });

      this.flutterProcess.on('exit', (code) => {
        if (!started && code !== 0) {
          reject(new Error(`Flutter exited with code ${code}`));
        }
      });

      // Timeout handling
      setTimeout(() => {
        if (!started) {
          this.log('Flutter startup timeout - checking if app is responding anyway...');
          // Don't reject immediately, let waitForReady handle it
          resolve();
        }
      }, this.startupTimeout);
    });
  }

  /**
   * Wait for the app to be ready by polling the URL.
   */
  async waitForReady() {
    this.log(`Waiting for app at ${this.appUrl}...`);

    const startTime = Date.now();
    const checkInterval = 2000;

    while (Date.now() - startTime < this.startupTimeout) {
      try {
        const isReady = await this.checkHealth();
        if (isReady) {
          // Additional wait for Flutter to fully render
          this.log('App responding, waiting for full render...');
          await new Promise(r => setTimeout(r, 5000));
          return true;
        }
      } catch (e) {
        // Not ready yet
      }

      this.log(`Waiting... (${Math.floor((Date.now() - startTime) / 1000)}s)`);
      await new Promise(r => setTimeout(r, checkInterval));
    }

    throw new Error('Flutter app did not become ready in time');
  }

  /**
   * Check if the app is responding.
   */
  checkHealth() {
    return new Promise((resolve) => {
      const req = http.get(this.appUrl, (res) => {
        resolve(res.statusCode === 200);
      });

      req.on('error', () => resolve(false));
      req.setTimeout(5000, () => {
        req.destroy();
        resolve(false);
      });
    });
  }

  /**
   * Check if Flutter is currently running.
   */
  async isRunning() {
    return this.checkHealth();
  }
}

module.exports = FlutterController;
