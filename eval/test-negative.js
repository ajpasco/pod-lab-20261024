import test from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../app/calc.js';

test('T-002 add handles a negative', () => {
  assert.equal(add(-1, 1), 0);
});
