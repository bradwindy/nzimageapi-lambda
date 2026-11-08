import type { ImageApiResponse } from './types';

// The nzimages-api Worker that scripts/dev.mjs runs under `wrangler dev`, with this dev-only
// consumer secret in API_CLIENT_SECRETS.
const API_URL = 'http://127.0.0.1:8977/image';
const DEV_SECRET = 'super_secret_secret';

// Record URLs come from third-party institutions and are rendered as links.
function httpURL(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  try {
    const { protocol } = new URL(value);
    return protocol === 'https:' || protocol === 'http:' ? value : undefined;
  } catch {
    return undefined;
  }
}

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
      thumbnail_url: httpURL(body.thumbnail_url),
      large_thumbnail_url: httpURL(body.large_thumbnail_url),
      object_url: httpURL(body.object_url),
      display_collection: body.display_collection as string | undefined,
      landing_url: httpURL(body.landing_url),
      source_url: httpURL(body.source_url),
    };
  } catch {
    return null;
  }
}
