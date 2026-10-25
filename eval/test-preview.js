import test from 'node:test';
import assert from 'node:assert/strict';
import { multiply } from '../app/calc.js';

// A row landed before its story: it fails by absence until app/calc.js exports multiply.
test('T-003 multiply returns the product', () => {
  assert.equal(multiply(2, 3), 6);
});
