import { NextRequest, NextResponse } from 'next/server';
import {
  readAndParse,
  updateCollectionInFile,
  withWriteMutex,
} from '@/lib/collectionsFile';
import type { DecisionStatus } from '@/lib/types';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'invalid JSON body' }, { status: 400 });
  }
  const { index, status, notes } = body as {
    index: number;
    status: DecisionStatus;
    notes?: string;
  };

  if (typeof index !== 'number' || !['yes', 'no', 'unsure'].includes(status)) {
    return NextResponse.json({ error: 'invalid body' }, { status: 400 });
  }

  return withWriteMutex(async () => {
    // Re-parse immediately before write to get current line numbers
    const { collections } = await readAndParse();
    const collection = collections[index];
    if (!collection) {
      return NextResponse.json({ error: 'collection not found' }, { status: 404 });
    }

    await updateCollectionInFile(collection, status, notes ?? null);

    // Re-parse to return the updated collection state
    const { collections: updated } = await readAndParse();
    const updatedCol = updated[index];
    return NextResponse.json({
      index,
      name: updatedCol.name,
      count: updatedCol.count,
      status: updatedCol.currentStatus,
      fields: updatedCol.fields.map(f => ({ key: f.key, value: f.value })),
    });
  });
}
