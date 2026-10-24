#!/usr/bin/env node
/**
 * Dev supervisor: starts the nzimages-api Worker under `wrangler dev`, then the Next.js dev
 * server. If a healthy API is already listening on the port, it is reused.
 *
 * The Worker reads DIGITALNZ_API_KEY from the repo-root .env and accepts the dev-only consumer
 * secret that lib/imageApi.ts sends. CONVERTER_SIGNING_KEY is left unset, so converter-routed
 * collections show their harvested URL instead of a signed converter URL.
 */

import { spawn, exec } from 'child_process';
import { access, readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');
const APP_DIR = path.resolve(__dirname, '..');
const WORKER_DIR = path.join(REPO_ROOT, 'worker');
const ENV_PATH = path.join(REPO_ROOT, '.env');
const API_PORT = 8787;
const DEV_SECRET = 'super_secret_secret';

let apiProc = null;
let nextProc = null;
let shuttingDown = false;

async function loadEnv() {
  try {
    const content = await readFile(ENV_PATH, 'utf-8');
    const env = {};
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx === -1) continue;
      env[trimmed.slice(0, eqIdx).trim()] = trimmed.slice(eqIdx + 1).trim();
    }
    return env;
  } catch {
    return {};
  }
}

async function checkHealth() {
  try {
    const res = await fetch(`http://127.0.0.1:${API_PORT}/collections`, {
      headers: { secret: DEV_SECRET },
      signal: AbortSignal.timeout(2000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

async function waitUntilHealthy(maxTries = 60, delayMs = 1000) {
  for (let i = 0; i < maxTries; i++) {
    if (await checkHealth()) return true;
    await new Promise(r => setTimeout(r, delayMs));
  }
  return false;
}

function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('\n[dev] Shutting down...');
  if (nextProc) { try { nextProc.kill('SIGTERM'); } catch {} }
  if (apiProc) { try { apiProc.kill('SIGTERM'); } catch {} }
  setTimeout(() => {
    if (nextProc) { try { nextProc.kill('SIGKILL'); } catch {} }
    if (apiProc) { try { apiProc.kill('SIGKILL'); } catch {} }
    process.exit(0);
  }, 2000);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

async function main() {
  const env = await loadEnv();
  if (!env.DIGITALNZ_API_KEY) {
    console.error('[dev] ERROR: DIGITALNZ_API_KEY not found in the repo-root .env.');
    console.error('[dev] Create a .env file in the repo root with DIGITALNZ_API_KEY=<your-key>');
    process.exit(1);
  }

  if (await checkHealth()) {
    console.log(`[dev] nzimages-api already healthy on :${API_PORT}, reusing it.`);
  } else {
    try {
      await access(path.join(WORKER_DIR, 'node_modules'));
    } catch {
      console.error('[dev] ERROR: worker dependencies are missing. Run `npm ci` in worker/ first.');
      process.exit(1);
    }

    const portBusy = await new Promise(r =>
      exec(`lsof -ti :${API_PORT}`, (err, out) => r(!err && out.trim().length > 0))
    );
    if (portBusy) {
      console.error(`[dev] ERROR: port ${API_PORT} is in use by something that isn't a healthy nzimages-api.`);
      process.exit(1);
    }

    console.log(`[dev] Starting nzimages-api (wrangler dev) on :${API_PORT}...`);
    const args = [
      'wrangler', 'dev', '--port', String(API_PORT),
      '--env-file', ENV_PATH,
      '--var', `API_CLIENT_SECRETS:dev:${DEV_SECRET}`,
    ];
    apiProc = spawn('npx', args, { cwd: WORKER_DIR, stdio: ['ignore', 'pipe', 'pipe'] });

    apiProc.stdout.on('data', d => process.stdout.write(`[api] ${d}`));
    apiProc.stderr.on('data', d => process.stderr.write(`[api] ${d}`));
    apiProc.on('exit', (code, sig) => {
      if (!shuttingDown) {
        console.error(`[dev] nzimages-api exited unexpectedly (code=${code} sig=${sig}). Shutting down.`);
        shutdown();
      }
    });

    console.log('[dev] Waiting for nzimages-api to be ready...');
    if (!(await waitUntilHealthy())) {
      console.error('[dev] nzimages-api did not become healthy in 60s. Exiting.');
      shutdown();
      return;
    }
    console.log('[dev] nzimages-api is ready.');
  }

  console.log('[dev] Starting Next.js dev server...');
  nextProc = spawn('npm', ['run', 'next-only'], {
    cwd: APP_DIR,
    env: { ...process.env, ...env, REPO_ROOT },
    stdio: 'inherit',
    shell: true,
  });

  nextProc.on('exit', (code, sig) => {
    if (!shuttingDown) {
      console.error(`[dev] Next.js exited (code=${code} sig=${sig}). Shutting down.`);
      shutdown();
    }
  });
}

main().catch(err => {
  console.error('[dev] Fatal error:', err);
  process.exit(1);
});
