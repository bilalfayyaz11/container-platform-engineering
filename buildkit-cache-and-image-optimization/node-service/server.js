'use strict';

const express = require('express');
const lodash = require('lodash');

const app = express();
const port = Number(process.env.PORT || 3000);

app.get('/health', (_request, response) => {
  response.json({
    status: 'healthy',
    service: 'container-build-node-service'
  });
});

app.get('/', (_request, response) => {
  response.json({
    message: 'BuildKit cache optimization is active',
    shuffled: lodash.shuffle([1, 2, 3, 4, 5]),
    timestamp: new Date().toISOString()
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`service listening on port ${port}`);
});
