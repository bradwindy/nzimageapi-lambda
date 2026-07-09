import fs from 'fs/promises';
import { PROGRESS_PATH } from './paths';
import { atomicWrite } from './atomicWrite';
import { withWriteMutex } from './collectionsFile';

export async function readProgress(): Promise<number> {
  // Lock-free: atomicWrite's rename means a reader always sees either the whole
  // old file or the whole new file, never a partial write.
  try {
    const content = await fs.readFile(PROGRESS_PATH, 'utf-8');
    return parseInt(content.trim(), 10) || 0;
  } catch {
    return 0;
  }
}

// Progress writes must go through the same mutex as the collections-file writers
// (mergeCollections in /api/sync also writes PROGRESS_PATH), otherwise a sync and
// a progress write race and clobber each other's index / temp file.
export async function writeProgress(index: number): Promise<void> {
  await withWriteMutex(() => atomicWrite(PROGRESS_PATH, String(index)));
}

export async function clearProgress(): Promise<void> {
  await withWriteMutex(async () => {
    try {
      await fs.unlink(PROGRESS_PATH);
    } catch {
      // file may not exist
    }
  });
}
