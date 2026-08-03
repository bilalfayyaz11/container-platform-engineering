'use strict';

const express = require('express');

const app = express();
const port = Number(process.env.PORT || 3000);

app.disable('x-powered-by');

app.get('/', (_request, response) => {
  response.json({
    service: 'container-delivery-api',
    message: 'Automated container delivery is operational',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (_request, response) => {
  response.status(200).json({
    status: 'healthy',
    uptimeSeconds: Math.floor(process.uptime())
  });
});

const server = app.listen(port, '0.0.0.0', () => {
  console.log(`Container delivery API listening on port ${port}`);
});

function shutdown(signal) {
  console.log(`${signal} received; shutting down gracefully`);

  server.close(() => process.exit(0));

  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
