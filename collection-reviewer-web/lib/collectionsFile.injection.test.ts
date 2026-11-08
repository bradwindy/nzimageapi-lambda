import { mkdtemp, mkdir, readFile, writeFile } from 'fs/promises';
import os from 'os';
import path from 'path';
import { beforeEach, expect, test, vi } from 'vitest';

// The details file is line-oriented, so a newline or quote in a written value must not create
// collections or fields. paths.ts reads REPO_ROOT at import, hence the fresh import per test.
async function withDetailsFile(content: string) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'reviewer-'));
  await mkdir(path.join(root, 'Research'));
  const details = path.join(root, 'Research', 'details-of-collections.txt');
  await writeFile(details, content);
  vi.stubEnv('REPO_ROOT', root);
  vi.resetModules();
  const lib = await import('./collectionsFile');
  return { lib, read: () => readFile(details, 'utf-8') };
}

beforeEach(() => {
  vi.unstubAllEnvs();
});

test('a multi-line review note stays one line and adds no collection', async () => {
  const { lib, read } = await withDetailsFile('"A": 1\n- Status: 🔎\n\n"B": 2\n- Status: 🔎\n');
  const { collections } = await lib.readAndParse();

  await lib.updateCollectionInFile(collections[0], 'yes', 'ok\n"Injected": 9\n- Status: ✅');

  const after = lib.parseCollectionsFile(await read()).collections;
  expect(after.map(c => c.name)).toEqual(['A', 'B']);
  expect(after[1].currentStatus).toBe(collections[1].currentStatus);
});

test('sync skips facets whose name or count would break the file format', async () => {
  const names = Array.from({ length: 50 }, (_, i) => `C${i}`);
  const { lib, read } = await withDetailsFile(names.map(n => `"${n}": 1\n- Status: 🔎\n`).join('\n'));

  await lib.mergeCollections([
    ...names.map(name => ({ name, count: 1 })),
    { name: 'Evil\n- Status: ✅', count: 1 },
    { name: 'A "quoted" name', count: 1 },
    { name: 'Bad count', count: '1\n- Status: ✅' as unknown as number },
  ]);

  const file = await read();
  expect(lib.parseCollectionsFile(file).collections.map(c => c.name)).toEqual(names);
  expect(file).not.toContain('✅');
});

test('sync keeps a tracked collection, and its notes, when its facet count is unusable', async () => {
  const names = Array.from({ length: 50 }, (_, i) => `C${i}`);
  const { lib, read } = await withDetailsFile(
    names.map(n => `"${n}": 1\n- Status: 🔎\n`).join('\n').replace('"C0": 1\n', '"C0": 1\n- Review [x]: keep me\n'),
  );

  await lib.mergeCollections([
    { name: 'C0', count: 1.5 },
    ...names.slice(1).map(name => ({ name, count: 1 })),
  ]);

  const file = await read();
  expect(lib.parseCollectionsFile(file).collections.map(c => c.name)).toEqual(names);
  expect(file).toContain('keep me');
});
