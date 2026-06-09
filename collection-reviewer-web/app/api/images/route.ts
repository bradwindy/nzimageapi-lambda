import { NextRequest, NextResponse } from 'next/server';
import { fetchImageForCollection } from '@/lib/lambda';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// Parallel-fetch `count` images for a collection via the local Swift lambda.
// Returns all results with statusCode===200 and a non-null large_thumbnail_url.
// Returns 200 with returned:0 if no usable images — the UI handles that case.
export async function GET(request: NextRequest) {
  const collection = request.nextUrl.searchParams.get('collection');
  const count = parseInt(request.nextUrl.searchParams.get('count') ?? '3', 10);

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
