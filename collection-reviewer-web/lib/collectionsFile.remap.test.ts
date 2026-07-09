import { test, expect } from 'vitest';
import { remapProgress } from './collectionsFile';

const cols = (...names: string[]) => names.map(name => ({ name }));

test('name still present → its new index', () => {
  expect(remapProgress('B', cols('A', 'B', 'C'), 0)).toBe(1);
});

test('name removed → clamps the old index to the last valid position', () => {
  expect(remapProgress('X', cols('A', 'B'), 5)).toBe(1);
});

// Regression for the "silently reset to 0" bug: a stale/out-of-range index (oldName === null)
// must clamp to the nearest valid index, not fall through to 0.
test('stale out-of-range index (null name) → clamps to last, not 0', () => {
  expect(remapProgress(null, cols('A', 'B', 'C'), 9)).toBe(2);
});

test('null name with an in-range index is preserved by the clamp', () => {
  expect(remapProgress(null, cols('A', 'B', 'C'), 1)).toBe(1);
});

test('negative index clamps up to 0', () => {
  expect(remapProgress(null, cols('A', 'B'), -3)).toBe(0);
});

test('empty new collection list → 0', () => {
  expect(remapProgress('A', [], 4)).toBe(0);
});
