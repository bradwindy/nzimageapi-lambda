'use client';

import { useState } from 'react';
import type { LambdaImageResponse } from '@/lib/types';

// Plain <img> (not next/image) — image hosts are arbitrary external sources
// and proxies; wildcard hostnames are disallowed in next/image remotePatterns.
export default function ImageCard({ image }: { image: LambdaImageResponse }) {
  const [loaded, setLoaded] = useState(false);
  const [errored, setErrored] = useState(false);

  return (
    <div className="image-card">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={image.large_thumbnail_url}
        alt={image.title ?? 'Collection image'}
        referrerPolicy="no-referrer"
        className={!loaded ? 'img-loading' : errored ? 'img-error' : undefined}
        onLoad={() => setLoaded(true)}
        onError={() => { setLoaded(true); setErrored(true); }}
      />
      <div className="img-meta">
        {image.title && <span className="img-title" title={image.title}>{image.title}</span>}
        <div className="img-links">
          {image.landing_url && (
            <a href={image.landing_url} target="_blank" rel="noreferrer noopener">
              Landing
            </a>
          )}
          {image.object_url && (
            <a href={image.object_url} target="_blank" rel="noreferrer noopener">
              Object
            </a>
          )}
          <a
            href={image.large_thumbnail_url}
            target="_blank"
            rel="noreferrer noopener"
          >
            Image
          </a>
        </div>
      </div>
    </div>
  );
}
