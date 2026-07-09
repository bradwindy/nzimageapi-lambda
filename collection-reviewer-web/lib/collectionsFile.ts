import fs from 'fs/promises';
import { atomicWrite } from './atomicWrite';
import { DETAILS_PATH, PROGRESS_PATH } from './paths';
import type {
  CollectionEntry,
  ParsedFile,
  DecisionStatus,
  MergeResult,
} from './types';
import { STATUS_EMOJI } from './types';
import type { FacetEntry } from './digitalnz';

// ---------------------------------------------------------------------------
// Write mutex — serialises all file writes so rapid clicks can't interleave
// read-modify-write cycles. Module-scoped: persists across requests in the
// same Next.js server process. Run only one writer (CLI or web) at a time —
// parity with the CLI's own lack of cross-process file locking.
// ---------------------------------------------------------------------------
let writeMutexChain: Promise<void> = Promise.resolve();

export function withWriteMutex<T>(fn: () => Promise<T>): Promise<T> {
  // Always run fn after the previous chain settles, regardless of its outcome.
  const result: Promise<T> = writeMutexChain.then(fn, fn);
  writeMutexChain = result.then(
    () => undefined,
    () => undefined,
  );
  return result;
}

// ---------------------------------------------------------------------------
// Parser — faithful port of parseCollectionsFile (CollectionReviewer/main.swift:110-176)
//
// Key invariants (must match Swift exactly so the progress integer stays valid):
//   • Collection start: line startsWith('"') AND includes('": ')
//   • Name: between first " (exclusive) and the NEXT " found in line.slice(1)
//   • Count: line.slice(1 + endQuoteRelIdx + 3).trim()  — mirrors Swift offsetBy:3
//   • Field: line startsWith('- ') AND contains ':', split on FIRST ':'
//   • Blank line ends block ONLY IF the block already has ≥1 field
//   • Non-"- " non-blank lines within a block are IGNORED (TAPUHI continuation)
//   • Last open block is closed at EOF
// ---------------------------------------------------------------------------
export function parseCollectionsFile(content: string): ParsedFile {
  const lines = content.split('\n');
  const collections: CollectionEntry[] = [];
  let current: CollectionEntry | null = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (line.startsWith('"') && line.includes('": ')) {
      // Close previous block (endLineNumber = current line - 1)
      if (current !== null) {
        current.endLineNumber = i - 1;
        collections.push(current);
      }

      // Extract name: between char 1 and the next " found in line.slice(1)
      const rest = line.slice(1);
      const endQuoteRel = rest.indexOf('"');
      if (endQuoteRel !== -1) {
        const name = rest.slice(0, endQuoteRel);
        // Skip past closing-quote + ": " (3 chars) — mirrors Swift offsetBy:3
        const countStart = 1 + endQuoteRel + 3;
        const count = line.slice(countStart).trim();

        current = {
          name,
          count,
          lineNumber: i,
          fields: [],
          statusLineNumber: -1,
          currentStatus: '',
          endLineNumber: -1,
        };
      }
    } else if (current !== null) {
      if (line.startsWith('- ')) {
        const fieldContent = line.slice(2);
        const colonIdx = fieldContent.indexOf(':');
        if (colonIdx !== -1) {
          const key = fieldContent.slice(0, colonIdx);
          const value = fieldContent.slice(colonIdx + 1).trim();
          current.fields.push({ key, value, lineNumber: i });
          if (key === 'Status') {
            current.statusLineNumber = i;
            current.currentStatus = value;
          }
        }
        // Lines starting with "- " but no colon are ignored (as in Swift)
      } else if (line.trim() === '' && current.fields.length > 0) {
        // Blank line after fields ends the block
        current.endLineNumber = i - 1;
        collections.push(current);
        current = null;
      }
      // Non-"- " non-blank lines (e.g. TAPUHI continuation lines) are ignored
    }
  }

  // Close any still-open block at EOF
  if (current !== null) {
    current.endLineNumber = lines.length - 1;
    collections.push(current);
  }

  return { lines, collections };
}

export async function readAndParse(): Promise<ParsedFile> {
  const content = await fs.readFile(DETAILS_PATH, 'utf-8');
  return parseCollectionsFile(content);
}

// ---------------------------------------------------------------------------
// Writer — faithful port of updateCollectionInFile (CollectionReviewer/main.swift:180-220)
//
// EXACT algorithm (order matters):
//   1. Re-read file fresh (content may have changed since the caller parsed)
//   2. If statusLineNumber != -1 and line includes "- Status: ", replace it.
//      Else splice a new "- Status: <emoji>" at lineNumber+1.
//   3. Re-join + re-split (Swift does this to recompute line offsets after insert)
//   4. insertIndex = lineNumber+1; advance while lines[insertIndex].startsWith('- ')
//   5. If notes: splice "- Review [<ts>]: <notes>" at insertIndex
//   6. Atomic write
//
// Timestamp: yyyy-MM-dd HH:mm in LOCAL time — must byte-match Swift's
// DateFormatter("yyyy-MM-dd HH:mm"). Do NOT use toISOString() (UTC) or Intl.
// ---------------------------------------------------------------------------
export async function updateCollectionInFile(
  collection: CollectionEntry,
  status: DecisionStatus,
  notes: string | null,
): Promise<void> {
  // Step 1: re-read fresh (matches Swift: var content = try String(contentsOfFile:...))
  const content = await fs.readFile(DETAILS_PATH, 'utf-8');
  let lines = content.split('\n');

  const emoji = STATUS_EMOJI[status];

  // Step 2: update or insert status line
  if (collection.statusLineNumber !== -1) {
    if (lines[collection.statusLineNumber]?.includes('- Status: ')) {
      lines[collection.statusLineNumber] = `- Status: ${emoji}`;
    }
  } else {
    lines.splice(collection.lineNumber + 1, 0, `- Status: ${emoji}`);
  }

  // Step 3: re-join + re-split (Swift recomputes offsets after potential insert)
  lines = lines.join('\n').split('\n');

  // Step 4: find insert index for notes (scan past all "- " lines)
  let insertIndex = collection.lineNumber + 1;
  while (insertIndex < lines.length && lines[insertIndex].startsWith('- ')) {
    insertIndex++;
  }

  // Step 5: insert timestamped note if provided
  if (notes && notes.trim() !== '') {
    const ts = formatLocalTimestamp(new Date());
    lines.splice(insertIndex, 0, `- Review [${ts}]: ${notes}`);
  }

  // Step 6: atomic write
  await atomicWrite(DETAILS_PATH, lines.join('\n'));
}

// Format yyyy-MM-dd HH:mm in LOCAL time.
// Hand-formatted to byte-match Swift's DateFormatter("yyyy-MM-dd HH:mm").
// Do NOT use toISOString() (gives UTC) or Intl (locale-variable separators).
function formatLocalTimestamp(date: Date): string {
  const y = date.getFullYear();
  const mo = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  const h = String(date.getHours()).padStart(2, '0');
  const mi = String(date.getMinutes()).padStart(2, '0');
  return `${y}-${mo}-${d} ${h}:${mi}`;
}

// Resolve the reviewer's saved progress index onto the post-merge collection list.
// `oldName` is the collection name captured at the pre-merge index (or null if the
// index was stale / out of range). Every branch clamps into [0, last] so a stale
// index is pinned to the nearest valid position rather than silently reset to 0.
export function remapProgress(
  oldName: string | null,
  newCollections: { name: string }[],
  oldIndex: number,
): number {
  const last = Math.max(newCollections.length - 1, 0);
  const clamp = (i: number) => Math.min(Math.max(i, 0), last);
  if (oldName === null) return clamp(oldIndex); // stale/out-of-range index → clamp, not 0
  const idx = newCollections.findIndex(c => c.name === oldName);
  return idx !== -1 ? idx : clamp(oldIndex); // collection removed → clamp to nearest
}

// ---------------------------------------------------------------------------
// Merge (sync) — shared by the sync API route and the one-time update script.
//
// Algorithm:
//   1. Parse current file; capture name at progress index.
//   2. Fetch live facets (caller provides them).
//   3. Safeguard: abort if < 50 collections (protects against bad API response).
//   4. Update counts in-place for kept collections.
//   5. Remove absent collections (lineNumber → nextCollection.lineNumber-1).
//   6. Append new collections at end as: "<Name>": count / - Status: 🔎
//   7. Remap progress to same-name collection; clamp if removed.
//   8. Atomic write both files.
// ---------------------------------------------------------------------------
export async function mergeCollections(facets: FacetEntry[]): Promise<MergeResult> {
  if (facets.length < 50) {
    throw new Error(
      `API returned only ${facets.length} collections — aborting to prevent data loss`,
    );
  }

  const facetMap = new Map<string, number>(facets.map(f => [f.name, f.count]));

  // Read current progress (the collection name we'll remap)
  let progressIndex = 0;
  try {
    const pc = await fs.readFile(PROGRESS_PATH, 'utf-8');
    progressIndex = parseInt(pc.trim(), 10) || 0;
  } catch {
    // progress file may not exist
  }

  // Parse file
  const content = await fs.readFile(DETAILS_PATH, 'utf-8');
  const { lines, collections } = parseCollectionsFile(content);

  const progressCollectionName = collections[progressIndex]?.name ?? null;

  const toRemove = new Set(collections.filter(c => !facetMap.has(c.name)).map(c => c.name));
  const existingNames = new Set(collections.map(c => c.name));
  const toAdd = facets.filter(f => !existingNames.has(f.name));

  const added: string[] = [];
  const removed: string[] = [];
  let updated = 0;

  // Build set of line indices to remove (name line → nextCollection.lineNumber-1 or EOF)
  const linesToRemove = new Set<number>();
  for (let ci = 0; ci < collections.length; ci++) {
    const c = collections[ci];
    if (!toRemove.has(c.name)) continue;
    const start = c.lineNumber;
    const end =
      ci + 1 < collections.length
        ? collections[ci + 1].lineNumber - 1
        : lines.length - 1;
    for (let li = start; li <= end; li++) linesToRemove.add(li);
    removed.push(c.name);
  }

  // Build index of collections by their line number for count updates
  const colByLine = new Map<number, CollectionEntry>(
    collections.map(c => [c.lineNumber, c]),
  );

  // Build new lines, skipping removed and updating counts
  const newLines: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    if (linesToRemove.has(i)) continue;

    const col = colByLine.get(i);
    if (col && !toRemove.has(col.name) && facetMap.has(col.name)) {
      const newCount = formatCount(facetMap.get(col.name)!);
      if (col.count !== newCount) {
        // Replace count: keep everything up to and including ": "
        const rest = lines[i].slice(1);
        const closeQ = rest.indexOf('"');
        const prefixEnd = 1 + closeQ + 3; // skip closing-quote + ": "
        newLines.push(lines[i].slice(0, prefixEnd) + newCount);
        updated++;
        continue;
      }
    }
    newLines.push(lines[i]);
  }

  // Trim trailing blank lines before appending new collections
  while (newLines.length > 0 && newLines[newLines.length - 1].trim() === '') {
    newLines.pop();
  }

  // Append new collections
  for (const { name, count } of toAdd) {
    newLines.push('');
    newLines.push('');
    newLines.push(`"${name}": ${formatCount(count)}`);
    newLines.push('- Status: 🔎');
    added.push(name);
  }

  // Ensure file ends with a newline
  newLines.push('');

  // Atomic write of details file
  await atomicWrite(DETAILS_PATH, newLines.join('\n'));

  // Remap progress: find new index of the previously-captured collection name
  const { collections: newCollections } = parseCollectionsFile(newLines.join('\n'));

  const newProgressIndex = remapProgress(
    progressCollectionName,
    newCollections,
    progressIndex,
  );

  await atomicWrite(PROGRESS_PATH, String(newProgressIndex));

  return { added, removed, updated, progressRemappedTo: newProgressIndex };
}

// Format a count integer with US thousands separators, e.g. 367587 → "367,587"
function formatCount(n: number): string {
  return n.toLocaleString('en-US');
}
