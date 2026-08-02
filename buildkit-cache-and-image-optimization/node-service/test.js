'use strict';

const assert = require('node:assert/strict');
const lodash = require('lodash');

const values = lodash.shuffle([1, 2, 3, 4, 5]);

assert.equal(values.length, 5);
assert.deepEqual([...values].sort(), [1, 2, 3, 4, 5]);

console.log('application test: PASS');
