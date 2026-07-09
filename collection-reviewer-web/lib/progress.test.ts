import { test, expect, afterEach, vi } from 'vitest';
import fs from 'fs/promises';
import os from 'os';
import path from 'path';

const dirs: string[] = [];

afterEach(async () => {
  vi.unstubAllEnvs();
  vi.resetModules();
  while (dirs.length) await fs.rm(dirs.pop()!, { recursive: true, force: true });
});

// Import progress.ts against a throwaway REPO_ROOT so its PROGRESS_PATH points into a temp dir.
async function loadProgressWithTempRoot() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'progress-'));
  dirs.push(root);
  await fs.mkdir(path.join(root, 'Research'), { recursive: true });
  vi.stubEnv('REPO_ROOT', root);
  vi.resetModules(); // force paths.ts to re-read REPO_ROOT
  const mod = await import('./progress');
  return { mod, progressFile: path.join(root, 'Research', '.collection-reviewer-progress'), root };
}

test('concurrent writeProgress calls serialize through the mutex with no lost/temp-file damage', async () => {
  const { mod, progressFile, root } = await loadProgressWithTempRoot();

  // Fired in order 0..9; the mutex chains them in call order, so the last-chained value wins.
  await Promise.all(Array.from({ length: 10 }, (_, i) => mod.writeProgress(i)));

  expect(await fs.readFile(progressFile, 'utf-8')).toBe('9');
  expect(await mod.readProgress()).toBe(9);
  const leftovers = (await fs.readdir(path.join(root, 'Research'))).filter(f => f.endsWith('.tmp'));
  expect(leftovers).toEqual([]);
});

test('clearProgress removes the file and is a no-op when already absent', async () => {
  const { mod, progressFile } = await loadProgressWithTempRoot();
  await mod.writeProgress(4);
  await mod.clearProgress();
  await expect(fs.access(progressFile)).rejects.toBeTruthy();
  await mod.clearProgress(); // second call must not throw
  expect(await mod.readProgress()).toBe(0);
});
