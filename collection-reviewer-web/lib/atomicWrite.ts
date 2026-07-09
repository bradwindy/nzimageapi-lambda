import fs from 'fs/promises';
import { randomBytes } from 'crypto';

// Matches Swift's String.write(toFile:atomically:encoding:) behaviour.
// The temp file gets a unique per-write name (pid + random) so two concurrent
// writers of the same target can never clobber each other's temp file (which
// would make one rename hit ENOENT). On any failure the temp file is unlinked
// so a crashed write never leaves a stale `*.tmp` behind.
export async function atomicWrite(filePath: string, content: string): Promise<void> {
  const tmpPath = `${filePath}.${process.pid}.${randomBytes(6).toString('hex')}.tmp`;
  try {
    await fs.writeFile(tmpPath, content, 'utf-8');
    await fs.rename(tmpPath, filePath);
  } catch (err) {
    await fs.unlink(tmpPath).catch(() => {});
    throw err;
  }
}
