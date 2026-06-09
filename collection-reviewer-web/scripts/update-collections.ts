/**
 * One-time collection list update script.
 * Run via: npm run update-collections
 * (Must be run from collection-reviewer-web/ so REPO_ROOT resolves correctly.)
 *
 * Set DIGITALNZ_API_KEY in the repo-root .env or pass it as an env var.
 * Commit Research/details-of-collections.txt before running so removals are
 * recoverable via git.
 *
 * Output: summary of added/removed/updated collections and progress remap.
 */

import fs from 'fs/promises';
import path from 'path';
import { fetchCollectionFacets } from '../lib/digitalnz';
import { mergeCollections } from '../lib/collectionsFile';
import { REPO_ROOT } from '../lib/paths';

async function main() {
  // Load DIGITALNZ_API_KEY from repo-root .env if not already set
  if (!process.env.DIGITALNZ_API_KEY) {
    const envPath = path.join(REPO_ROOT, '.env');
    try {
      const content = await fs.readFile(envPath, 'utf-8');
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith('#')) continue;
        const eqIdx = trimmed.indexOf('=');
        if (eqIdx === -1) continue;
        const key = trimmed.slice(0, eqIdx).trim();
        if (key === 'DIGITALNZ_API_KEY') {
          process.env.DIGITALNZ_API_KEY = trimmed.slice(eqIdx + 1).trim();
          break;
        }
      }
    } catch {
      // .env may not exist
    }
  }

  if (!process.env.DIGITALNZ_API_KEY) {
    console.error('ERROR: DIGITALNZ_API_KEY not set in environment or repo-root .env');
    process.exit(1);
  }

  console.log('Fetching collection facets from DigitalNZ API...');
  const facets = await fetchCollectionFacets();
  console.log(`  → ${facets.length} collections returned by API`);

  console.log('Merging with local details file...');
  const result = await mergeCollections(facets);

  console.log('\nSync complete:');
  console.log(`  Added   (${result.added.length}): ${result.added.join(', ') || 'none'}`);
  console.log(`  Removed (${result.removed.length}): ${result.removed.join(', ') || 'none'}`);
  console.log(`  Updated counts: ${result.updated}`);
  console.log(
    `  Progress remapped to index ${result.progressRemappedTo} (collection #${result.progressRemappedTo + 1})`,
  );
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
