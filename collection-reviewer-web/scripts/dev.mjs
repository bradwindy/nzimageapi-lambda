#!/usr/bin/env node
/**
 * Dev supervisor — starts the Swift lambda then Next.js dev server.
 * Run via: npm run dev (incremental build), npm run dev:clean (clean build),
 *          npm run dev:reuse (skip swift build, reuse lambda if already healthy).
 *
 * Environment flags (set automatically by npm scripts):
 *   LAMBDA_CLEAN_BUILD=1   — run swift package clean before swift build
 *   LAMBDA_SKIP_BUILD=1    — skip swift build entirely
 *
 * Reads DIGITALNZ_API_KEY from repo-root .env.
 */

import { spawn, exec } from 'child_process';
import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');
const APP_DIR = path.resolve(__dirname, '..');
const LAMBDA_PORT = 7000;
const LAMBDA_BINARY = path.join(REPO_ROOT, '.build', 'debug', 'NZImageApiLambda');

let lambdaProc = null;
let nextProc = null;
let shuttingDown = false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function execPromise(cmd, opts = {}) {
  return new Promise((resolve, reject) => {
    const child = exec(cmd, { ...opts, maxBuffer: 100 * 1024 * 1024 }, (err) => {
      if (err) reject(err);
      else resolve();
    });
    child.stdout?.pipe(process.stdout);
    child.stderr?.pipe(process.stderr);
  });
}

async function loadEnv() {
  const envPath = path.join(REPO_ROOT, '.env');
  try {
    const content = await readFile(envPath, 'utf-8');
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
    const res = await fetch(`http://127.0.0.1:${LAMBDA_PORT}/invoke`, {
      method: 'POST',
      body: '{}',
      headers: { 'Content-Type': 'application/json' },
      signal: AbortSignal.timeout(2000),
    });
    return typeof res.status === 'number';
  } catch {
    return false;
  }
}

async function waitUntilHealthy(maxTries = 30, delayMs = 1000) {
  for (let i = 0; i < maxTries; i++) {
    if (await checkHealth()) return true;
    await new Promise(r => setTimeout(r, delayMs));
  }
  return false;
}

async function killPort() {
  return new Promise(resolve => {
    exec(`lsof -ti :${LAMBDA_PORT}`, (err, stdout) => {
      if (err || !stdout.trim()) return resolve();
      const pids = stdout.trim().split('\n').filter(Boolean);
      for (const pid of pids) {
        try { exec(`kill -9 ${pid}`); } catch {}
      }
      setTimeout(resolve, 600);
    });
  });
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  console.log('\n[dev] Shutting down...');
  if (nextProc) { try { nextProc.kill('SIGTERM'); } catch {} }
  if (lambdaProc) { try { lambdaProc.kill('SIGTERM'); } catch {} }
  // Give processes a moment to exit, then hard-exit
  setTimeout(() => {
    if (nextProc) { try { nextProc.kill('SIGKILL'); } catch {} }
    if (lambdaProc) { try { lambdaProc.kill('SIGKILL'); } catch {} }
    process.exit(0);
  }, 2000);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  // Load .env from repo root
  const env = await loadEnv();
  const apiKey = process.env.DIGITALNZ_API_KEY ?? env.DIGITALNZ_API_KEY;

  if (!apiKey) {
    console.error('[dev] ERROR: DIGITALNZ_API_KEY not found in .env or environment.');
    console.error('[dev] Create a .env file in the repo root with DIGITALNZ_API_KEY=<your-key>');
    process.exit(1);
  }

  const cleanBuild = process.env.LAMBDA_CLEAN_BUILD === '1';
  const skipBuild = process.env.LAMBDA_SKIP_BUILD === '1';

  // Check if a healthy lambda is already running — if so, reuse it
  const alreadyRunning = await checkHealth();
  if (alreadyRunning) {
    console.log(`[dev] Lambda already healthy on :${LAMBDA_PORT} — reusing.`);
  } else {
    // Build lambda
    if (skipBuild) {
      console.log('[dev] Skipping swift build (LAMBDA_SKIP_BUILD=1).');
    } else {
      if (cleanBuild) {
        console.log('[dev] Running swift package clean...');
        try {
          await execPromise('swift package clean', { cwd: REPO_ROOT });
        } catch (err) {
          console.warn('[dev] swift package clean failed (continuing):', err.message);
        }
      }
      console.log('[dev] Building lambda (swift build)...');
      try {
        await execPromise('swift build', { cwd: REPO_ROOT });
        console.log('[dev] Build complete.');
      } catch {
        console.error('[dev] swift build failed. Exiting.');
        process.exit(1);
      }
    }

    // Free port if occupied
    const portBusy = await new Promise(r =>
      exec(`lsof -ti :${LAMBDA_PORT}`, (err, out) => r(!err && out.trim().length > 0))
    );
    if (portBusy) {
      console.log(`[dev] Port ${LAMBDA_PORT} in use — killing existing process...`);
      await killPort();
    }

    // Spawn lambda
    console.log(`[dev] Starting lambda on :${LAMBDA_PORT}...`);
    lambdaProc = spawn(LAMBDA_BINARY, [], {
      cwd: REPO_ROOT,
      env: {
        ...process.env,
        API_CLIENT_SECRETS: 'dev:super_secret_secret',
        LOCAL_LAMBDA_SERVER_ENABLED: 'true',
        PORT: String(LAMBDA_PORT),
        DIGITALNZ_API_KEY: apiKey,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    lambdaProc.stdout.on('data', d => process.stdout.write(`[lambda] ${d}`));
    lambdaProc.stderr.on('data', d => process.stderr.write(`[lambda] ${d}`));
    lambdaProc.on('exit', (code, sig) => {
      if (!shuttingDown) {
        console.error(`[dev] Lambda exited unexpectedly (code=${code} sig=${sig}). Shutting down.`);
        shutdown();
      }
    });

    // Health-poll until ready
    console.log('[dev] Waiting for lambda to be ready...');
    const ready = await waitUntilHealthy();
    if (!ready) {
      console.error('[dev] Lambda did not become healthy in 30s. Exiting.');
      shutdown();
      return;
    }
    console.log('[dev] Lambda is ready.');
  }

  // Spawn Next.js dev server
  console.log('[dev] Starting Next.js dev server...');
  nextProc = spawn('npm', ['run', 'next-only'], {
    cwd: APP_DIR,
    env: {
      ...process.env,
      ...env,
      DIGITALNZ_API_KEY: apiKey,
      REPO_ROOT,
    },
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
