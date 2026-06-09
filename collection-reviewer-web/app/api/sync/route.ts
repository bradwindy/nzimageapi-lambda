import { NextResponse } from 'next/server';
import { mergeCollections, withWriteMutex } from '@/lib/collectionsFile';
import { fetchCollectionFacets } from '@/lib/digitalnz';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST() {
  return withWriteMutex(async () => {
    const facets = await fetchCollectionFacets();
    const result = await mergeCollections(facets);
    return NextResponse.json(result);
  });
}
