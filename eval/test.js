import test from 'node:test';
import assert from 'node:assert/strict';
import { add } from '../app/calc.js';

test('T-001 add returns the sum', () => {
  assert.equal(add(2, 3), 5);
});
