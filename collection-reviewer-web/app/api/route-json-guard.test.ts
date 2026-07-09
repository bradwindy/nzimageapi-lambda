import { test, expect } from 'vitest';
import { NextRequest } from 'next/server';
import { POST as decisionPOST } from './decision/route';
import { POST as progressPOST } from './progress/route';

function jsonRequest(url: string, body: string): NextRequest {
  return new NextRequest(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body,
  });
}

// Regression: an unguarded `await request.json()` throws a SyntaxError and produces a raw 500.
// Both write routes must catch the parse failure and return a clean 400 instead.

test('POST /api/decision with a malformed body returns 400, not a throw', async () => {
  const res = await decisionPOST(jsonRequest('http://localhost/api/decision', 'this is not json'));
  expect(res.status).toBe(400);
});

test('POST /api/progress with a malformed body returns 400, not a throw', async () => {
  const res = await progressPOST(jsonRequest('http://localhost/api/progress', 'this is not json'));
  expect(res.status).toBe(400);
});

// A body of "null" (or a bare primitive) parses successfully but is not an object;
// destructuring it would throw a TypeError outside the try/catch → a raw 500.
test('POST /api/decision with a valid-JSON null body returns 400, not a throw', async () => {
  const res = await decisionPOST(jsonRequest('http://localhost/api/decision', 'null'));
  expect(res.status).toBe(400);
});

test('POST /api/progress with a valid-JSON null body returns 400, not a throw', async () => {
  const res = await progressPOST(jsonRequest('http://localhost/api/progress', 'null'));
  expect(res.status).toBe(400);
});
