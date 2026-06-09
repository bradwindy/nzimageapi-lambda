import fs from 'fs/promises';
import { PROGRESS_PATH } from './paths';
import { atomicWrite } from './atomicWrite';

export async function readProgress(): Promise<number> {
  try {
    const content = await fs.readFile(PROGRESS_PATH, 'utf-8');
    return parseInt(content.trim(), 10) || 0;
  } catch {
    return 0;
  }
}

export async function writeProgress(index: number): Promise<void> {
  await atomicWrite(PROGRESS_PATH, String(index));
}

export async function clearProgress(): Promise<void> {
  try {
    await fs.unlink(PROGRESS_PATH);
  } catch {
    // file may not exist
  }
}
