import { readAndParse } from '@/lib/collectionsFile';
import { readProgress } from '@/lib/progress';
import Reviewer from './reviewer';

export const dynamic = 'force-dynamic';

// Server component: reads collections + progress server-side for instant
// resume-on-first-paint without waiting for client-side API calls.
export default async function Page() {
  const [{ collections }, currentIndex] = await Promise.all([
    readAndParse(),
    readProgress(),
  ]);

  const initialCollections = collections.map((c, index) => ({
    index,
    name: c.name,
    count: c.count,
    status: c.currentStatus,
    fields: c.fields.map(f => ({ key: f.key, value: f.value })),
  }));

  return (
    <Reviewer initialCollections={initialCollections} initialIndex={currentIndex} />
  );
}
