import { NextResponse, type NextRequest } from 'next/server';
import { isLocalSameOriginRequest } from '@/lib/localRequest';

export function proxy(request: NextRequest) {
  if (!isLocalSameOriginRequest(request.headers)) {
    return NextResponse.json({ error: 'forbidden' }, { status: 403 });
  }
  return NextResponse.next();
}

export const config = {
  matcher: '/api/:path*',
};
