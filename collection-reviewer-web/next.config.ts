import type { NextConfig } from 'next';

// Using plain <img> tags (not next/image) because image hosts are arbitrary
// external sources and proxies with wildcard hostnames.
// If ever switching to next/image, set: images: { unoptimized: true }
const nextConfig: NextConfig = {};

export default nextConfig;
