import type { ImageApiResponse } from './types';

// The nzimages-api Worker that scripts/dev.mjs runs under `wrangler dev`, with this dev-only
// consumer secret in API_CLIENT_SECRETS.
const API_URL = 'http://127.0.0.1:8787/image';
const DEV_SECRET = 'super_secret_secret';

// Returns null only when the API can't be reached. A non-200 answer comes back with its status
// and no image fields, so callers can tell "no image" from "API down".
export async function fetchImageForCollection(
  collection: string,
  signal?: AbortSignal
): Promise<ImageApiResponse | null> {
  try {
    const res = await fetch(`${API_URL}?collection=${encodeURIComponent(collection)}`, {
      headers: { secret: DEV_SECRET },
      cache: 'no-store',
      signal,
    });

    let body: Record<string, unknown> = {};
    try {
      body = await res.json();
    } catch {
      // Error responses are plain text.
    }

    return {
      statusCode: res.status,
      id: body.id as number | undefined,
      title: body.title as string | undefined,
      description: body.description as string | undefined,
      thumbnail_url: body.thumbnail_url as string | undefined,
      large_thumbnail_url: body.large_thumbnail_url as string | undefined,
      object_url: body.object_url as string | undefined,
      display_collection: body.display_collection as string | undefined,
      landing_url: body.landing_url as string | undefined,
      source_url: body.source_url as string | undefined,
    };
  } catch {
    return null;
  }
}
