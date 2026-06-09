import path from 'path';

// Repo root is one level up from collection-reviewer-web/.
// When running via Next.js dev server or npm scripts, process.cwd() =
// collection-reviewer-web/, so path.resolve('..') = repo root.
// Override with REPO_ROOT env var if running from a different CWD.
export const REPO_ROOT = process.env.REPO_ROOT ?? path.resolve(process.cwd(), '..');

export const DETAILS_PATH = path.join(
  REPO_ROOT,
  'Research',
  'details-of-collections.txt'
);

export const PROGRESS_PATH = path.join(
  REPO_ROOT,
  'Research',
  '.collection-reviewer-progress'
);
