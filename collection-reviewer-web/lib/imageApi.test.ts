import { afterEach, expect, test, vi } from 'vitest';
import { fetchImageForCollection } from './imageApi';

afterEach(() => {
  vi.unstubAllGlobals();
});

test('drops record URLs that are not http(s), since ImageCard renders them as links', async () => {
  vi.stubGlobal(
    'fetch',
    vi.fn(async () =>
      Response.json({
        landing_url: 'javascript:alert(1)',
        object_url: 'data:text/html,<b>x</b>',
        large_thumbnail_url: 'https://example.com/large.jpg',
        thumbnail_url: 'http://example.com/thumb.jpg',
      }),
    ),
  );

  const image = await fetchImageForCollection('X');

  expect(image?.landing_url).toBeUndefined();
  expect(image?.object_url).toBeUndefined();
  expect(image?.large_thumbnail_url).toBe('https://example.com/large.jpg');
  expect(image?.thumbnail_url).toBe('http://example.com/thumb.jpg');
});
