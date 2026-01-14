#!/bin/bash
docker run --rm --network host \
  -v /home/ianm/Development/ShadowWhisper/test-regression.js:/test/test-regression.js \
  -v /home/ianm/Development/ShadowWhisper/screenshots:/screenshots \
  -v /home/ianm/Development/ShadowWhisper/node_modules:/test/node_modules \
  -w /test \
  --entrypoint="" \
  mcr.microsoft.com/playwright:v1.50.1-noble \
  sh -c "Xvfb :99 -screen 0 1280x720x24 & sleep 2 && DISPLAY=:99 node /test/test-regression.js"
