import { test, expect } from 'vitest';
import { parseImageCount } from './route';

test('missing param → default of 3', () => {
  expect(parseImageCount(null)).toBe(3);
});

test('non-numeric → default of 3 (no more silent NaN → 0 images)', () => {
  expect(parseImageCount('abc')).toBe(3);
  expect(parseImageCount('')).toBe(3);
});

test('zero and negatives clamp up to 1', () => {
  expect(parseImageCount('0')).toBe(1);
  expect(parseImageCount('-4')).toBe(1);
});

test('oversized value clamps to the max of 20 (no unbounded fan-out)', () => {
  expect(parseImageCount('100000')).toBe(20);
});

test('normal in-range value passes through', () => {
  expect(parseImageCount('5')).toBe(5);
});
