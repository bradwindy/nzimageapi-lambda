import { NextRequest, NextResponse } from 'next/server';
import { fetchImageForCollection } from '@/lib/lambda';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const DEFAULT_COUNT = 3;
const MAX_COUNT = 20;

// Parse the `count` query param into a sane, bounded number of images to fetch.
// Guards two footguns: a non-numeric value (parseInt → NaN → Array.from silently
// yields length 0 → "no images"), and an unbounded value (spawning thousands of
// concurrent lambda fetches). Falls back to the default on anything invalid.
export function parseImageCount(raw: string | null): number {
  if (raw === null) return DEFAULT_COUNT;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n)) return DEFAULT_COUNT;
  return Math.min(Math.max(n, 1), MAX_COUNT);
}

// Parallel-fetch `count` images for a collection via the local Swift lambda.
// Returns all results with statusCode===200 and a non-null large_thumbnail_url.
// Returns 200 with returned:0 if no usable images — the UI handles that case.
export async function GET(request: NextRequest) {
  const collection = request.nextUrl.searchParams.get('collection');
  const count = parseImageCount(request.nextUrl.searchParams.get('count'));

  if (!collection) {
    return NextResponse.json({ error: 'collection param required' }, { status: 400 });
  }

  const TIMEOUT_MS = 45_000; // TAPUHI / weserv.nl cache misses can be slow

  const imagePromises = Array.from({ length: count }, () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    return fetchImageForCollection(collection, controller.signal).finally(() =>
      clearTimeout(timer),
    );
  });

  const results = await Promise.allSettled(imagePromises);

  const images = results
    .flatMap(r =>
      r.status === 'fulfilled' && r.value !== null ? [r.value] : [],
    )
    .filter(img => img.statusCode === 200 && img.large_thumbnail_url != null);

  return NextResponse.json({ images, requested: count, returned: images.length });
}
