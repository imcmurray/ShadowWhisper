module.exports = {
  APP_URL: 'http://localhost:8080',
  VIEWPORT: { width: 1280, height: 720 },
  TIMEOUTS: {
    flutterLoad: 60000,
    flutterRender: 5000,
    roomCreation: 3000,
    zkProof: 8000,
    p2pConnection: 15000,
    messageDelivery: 5000,
    shortWait: 500,
    mediumWait: 1000,
    longWait: 3000,
  },
  BROWSER_ARGS: [
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-accelerated-2d-canvas',
    '--no-first-run',
    '--disable-gpu',
  ],
  SCREENSHOT_DIR: './screenshots',
};
