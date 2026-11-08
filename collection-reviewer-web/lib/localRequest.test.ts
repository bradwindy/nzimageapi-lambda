import { describe, expect, it } from 'vitest';
import { isLocalSameOriginRequest } from './localRequest';

const local = (extra: Record<string, string> = {}) => new Headers({ host: 'localhost:3000', ...extra });

describe('isLocalSameOriginRequest', () => {
  it('allows the app calling its own API', () => {
    expect(isLocalSameOriginRequest(local({ origin: 'http://localhost:3000', 'sec-fetch-site': 'same-origin' }))).toBe(true);
    expect(isLocalSameOriginRequest(new Headers({ host: '127.0.0.1:3000' }))).toBe(true);
  });

  it('rejects a cross-site request from another page the developer has open', () => {
    expect(isLocalSameOriginRequest(local({ origin: 'https://evil.example', 'sec-fetch-site': 'cross-site' }))).toBe(false);
    expect(isLocalSameOriginRequest(local({ origin: 'https://evil.example' }))).toBe(false);
    expect(isLocalSameOriginRequest(local({ 'sec-fetch-site': 'same-site' }))).toBe(false);
    expect(isLocalSameOriginRequest(local({ origin: 'null' }))).toBe(false);
  });

  it('rejects a DNS-rebinding request, which the browser sees as same-origin', () => {
    const rebound = new Headers({ host: 'evil.example:3000', origin: 'http://evil.example:3000', 'sec-fetch-site': 'same-origin' });
    expect(isLocalSameOriginRequest(rebound)).toBe(false);
  });

  it('rejects a request with no Host header', () => {
    expect(isLocalSameOriginRequest(new Headers())).toBe(false);
  });
});
