import { test, expect } from 'vitest';
import { NextRequest } from 'next/server';
import { POST as decisionPOST } from './decision/route';
import { POST as progressPOST } from './progress/route';

function badJsonRequest(url: string): NextRequest {
  return new NextRequest(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: 'this is not json',
  });
}

// Regression: an unguarded `await request.json()` throws a SyntaxError and produces a raw 500.
// Both write routes must catch the parse failure and return a clean 400 instead.

test('POST /api/decision with a malformed body returns 400, not a throw', async () => {
  const res = await decisionPOST(badJsonRequest('http://localhost/api/decision'));
  expect(res.status).toBe(400);
});

test('POST /api/progress with a malformed body returns 400, not a throw', async () => {
  const res = await progressPOST(badJsonRequest('http://localhost/api/progress'));
  expect(res.status).toBe(400);
});
