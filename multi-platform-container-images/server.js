'use strict';

const express = require('express');
const os = require('node:os');

const app = express();
const port = Number(process.env.PORT || 3000);

app.disable('x-powered-by');

app.get('/', (_request, response) => {
  response.json({
    service: 'multi-platform-runtime-api',
    message: 'Multi-platform container is operational',
    platform: os.platform(),
    architecture: os.arch(),
    hostname: os.hostname(),
    nodeVersion: process.version,
    uptimeSeconds: Math.floor(process.uptime())
  });
});

app.get('/health', (_request, response) => {
  response.status(200).json({
    status: 'healthy',
    architecture: os.arch()
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`API listening on port ${port}`);
  console.log(`Platform: ${os.platform()}`);
  console.log(`Architecture: ${os.arch()}`);
});
