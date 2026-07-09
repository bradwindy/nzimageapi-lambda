import { test, expect, afterEach } from 'vitest';
import fs from 'fs/promises';
import os from 'os';
import path from 'path';
import { atomicWrite } from './atomicWrite';

const dirs: string[] = [];

async function tmpDir(): Promise<string> {
  const d = await fs.mkdtemp(path.join(os.tmpdir(), 'atomicwrite-'));
  dirs.push(d);
  return d;
}

afterEach(async () => {
  while (dirs.length) await fs.rm(dirs.pop()!, { recursive: true, force: true });
});

test('writes content that reads back exactly', async () => {
  const dir = await tmpDir();
  const target = path.join(dir, 'f.txt');
  await atomicWrite(target, 'hello world');
  expect(await fs.readFile(target, 'utf-8')).toBe('hello world');
});

test('concurrent writes to the same target all settle with no leftover temp files', async () => {
  const dir = await tmpDir();
  const target = path.join(dir, 'shared');
  // Unique temp names mean these cannot clobber each other's temp file (which would make
  // one rename hit ENOENT). All must resolve, the final file holds one written value, and
  // the directory contains no stale *.tmp.
  await Promise.all(Array.from({ length: 25 }, (_, i) => atomicWrite(target, String(i))));
  const final = await fs.readFile(target, 'utf-8');
  expect(Number.isInteger(Number(final))).toBe(true);
  const leftovers = (await fs.readdir(dir)).filter(f => f.endsWith('.tmp'));
  expect(leftovers).toEqual([]);
});

test('rejects on an unwritable path and leaves no temp file behind', async () => {
  const dir = await tmpDir();
  const target = path.join(dir, 'no-such-subdir', 'f.txt'); // parent dir does not exist
  await expect(atomicWrite(target, 'x')).rejects.toBeTruthy();
  const leftovers = (await fs.readdir(dir)).filter(f => f.endsWith('.tmp'));
  expect(leftovers).toEqual([]);
});
