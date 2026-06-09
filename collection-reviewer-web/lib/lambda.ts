import type { LambdaImageResponse } from './types';

const LAMBDA_URL = 'http://127.0.0.1:7000/invoke';

// Faithful port of LambdaServerManager.makeRequest (LambdaTesting.swift:152).
// Builds an API Gateway v2 event and POSTs it to the local lambda /invoke endpoint.
export async function fetchImageForCollection(
  collection: string,
  signal?: AbortSignal
): Promise<LambdaImageResponse | null> {
  const encodedCollection = encodeURIComponent(collection);
  const now = Date.now();

  const requestBody = {
    routeKey: 'GET /image',
    version: '2.0',
    rawPath: '/image',
    stageVariables: {},
    requestContext: {
      timeEpoch: now,
      domainPrefix: 'image',
      accountId: '0123456789',
      stage: '$default',
      domainName: 'image.test.com',
      apiId: 'pb5dg6g3rg',
      requestId: `test-${now}`,
      http: {
        path: '/image',
        userAgent: 'CollectionReviewerWeb',
        method: 'GET',
        protocol: 'HTTP/1.1',
        sourceIp: '127.0.0.1',
      },
      time: new Date().toISOString(),
    },
    isBase64Encoded: false,
    headers: {
      secret: 'super_secret_secret',
      host: '127.0.0.1:7000',
      'user-agent': 'CollectionReviewerWeb',
      'content-length': '0',
    },
    queryStringParameters: { collection },
    rawQueryString: `collection=${encodedCollection}`,
  };

  try {
    const res = await fetch(LAMBDA_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
      cache: 'no-store',
      signal,
    });

    if (!res.ok) return null;

    const outer = await res.json();
    const statusCode = outer.statusCode as number;

    let body: Record<string, unknown> = {};
    if (typeof outer.body === 'string') {
      try {
        body = JSON.parse(outer.body);
      } catch {
        return null;
      }
    }

    return {
      statusCode,
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
