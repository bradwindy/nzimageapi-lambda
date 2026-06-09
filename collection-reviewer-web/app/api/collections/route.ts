import { NextResponse } from 'next/server';
import { readAndParse } from '@/lib/collectionsFile';
import { readProgress } from '@/lib/progress';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// Returns the full collection list in file order with the current progress index.
// Index alignment must match the CLI progress integer — both are zero-based
// indexes into the same ordering produced by parseCollectionsFile.
export async function GET() {
  const [{ collections }, currentIndex] = await Promise.all([
    readAndParse(),
    readProgress(),
  ]);

  return NextResponse.json({
    collections: collections.map((c, index) => ({
      index,
      name: c.name,
      count: c.count,
      status: c.currentStatus,
      fields: c.fields.map(f => ({ key: f.key, value: f.value })),
    })),
    total: collections.length,
    currentIndex,
  });
}
