import { NextRequest, NextResponse } from 'next/server';
import { readProgress, writeProgress, clearProgress } from '@/lib/progress';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET() {
  const currentIndex = await readProgress();
  return NextResponse.json({ currentIndex });
}

export async function POST(request: NextRequest) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'invalid JSON body' }, { status: 400 });
  }
  const { index } = body as { index?: unknown };
  if (typeof index !== 'number') {
    return NextResponse.json({ error: 'index must be a number' }, { status: 400 });
  }
  await writeProgress(index);
  return NextResponse.json({ currentIndex: index });
}

// Called on completion — mirrors CLI's clearProgress()
export async function DELETE() {
  await clearProgress();
  return NextResponse.json({ cleared: true });
}
