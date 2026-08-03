'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

test('runtime uses Node.js 24 or newer', () => {
  const majorVersion = Number(process.versions.node.split('.')[0]);
  assert.ok(majorVersion >= 24);
});

test('default application port is 3000', () => {
  assert.equal(Number(process.env.PORT || 3000), 3000);
});
