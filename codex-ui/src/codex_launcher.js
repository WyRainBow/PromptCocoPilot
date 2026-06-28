import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { getCodexPaths, defaultDevToolsPort, readDevToolsPort } from './codex_paths.js';

// Re-exported so the bin entrypoint can import everything Codex-launch related
// from a single module.
export { defaultDevToolsPort };

// Codex ships WITHOUT a remote-debugging port enabled (unlike Qoder, which
// writes DevToolsActivePort on its own). Before we can inject anything we must
// relaunch Codex with --remote-debugging-port=<port>. These helpers do that.

function defaultRun(cmd, args) {
  return execFileSync(cmd, args, { encoding: 'utf8' });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function isCodexRunning(run = defaultRun) {
  // The main process is `/Applications/Codex.app/Contents/MacOS/Codex`.
  // Helper / GPU / service processes live under .../Frameworks/...Helpers/...,
  // so this pattern matches only the main process.
  try {
    const out = run('pgrep', ['-f', 'Codex.app/Contents/MacOS/Codex']);
    return String(out).trim().length > 0;
  } catch {
    return false;
  }
}

export function devToolsPortFileExists({ paths = getCodexPaths() } = {}) {
  return fs.existsSync(paths.devToolsActivePort);
}

export function launchCodexWithDebugPort(
  port,
  { run = defaultRun, paths = getCodexPaths() } = {}
) {
  const portNum = Number(port);
  if (!Number.isInteger(portNum) || portNum <= 0) {
    throw new Error('debug port must be a positive integer');
  }
  if (isCodexRunning(run) && !devToolsPortFileExists({ paths })) {
    throw new Error(
      'Codex is already running without a debug port. Quit Codex completely (Cmd+Q), then run `codex:launch` again.'
    );
  }
  // `open -a Codex --args ...` forwards the flag to the Electron main process.
  run('open', ['-a', paths.appBundleName, '--args', `--remote-debugging-port=${portNum}`]);
  return portNum;
}

export function readActiveDevToolsPort({ paths = getCodexPaths() } = {}) {
  return readDevToolsPort(fs.readFileSync(paths.devToolsActivePort, 'utf8'));
}

async function isCodexDebugPort(port) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, {
      signal: AbortSignal.timeout(600)
    });
    if (!response.ok) return false;
    const targets = await response.json();
    return (targets || []).some(
      (target) =>
        target.type === 'page' &&
        (/app:\/\//.test(String(target.url || '')) ||
          /codex/i.test(String(target.title || '')) ||
          /owl/i.test(String(target.title || '')))
    );
  } catch {
    return false;
  }
}

// Resolve the Codex debug port without forcing the user to remember an env var.
// Order: CODEX_DEVTOOLS_PORT env > DevToolsActivePort file > scan known ports
// for a renderer whose url starts with app:// (Codex's scheme).
export async function discoverDevToolsPort({
  paths = getCodexPaths(),
  candidates = [9333, 9222, 9229, 8315, 9339, 9444]
} = {}) {
  if (process.env.CODEX_DEVTOOLS_PORT) {
    const port = Number(process.env.CODEX_DEVTOOLS_PORT);
    if (Number.isInteger(port) && port > 0) return port;
  }
  try {
    return readActiveDevToolsPort({ paths });
  } catch {
    // DevToolsActivePort is missing (e.g. Codex was launched by running the
    // executable directly). Fall through to scanning known debug ports.
  }
  for (const port of candidates) {
    if (await isCodexDebugPort(port)) return port;
  }
  throw new Error(
    'Could not discover a Codex debug port. Launch Codex with ' +
      '`/Applications/Codex.app/Contents/MacOS/Codex --remote-debugging-port=9333 &` first.'
  );
}

export async function waitForDevToolsPort(
  { paths = getCodexPaths(), timeoutMs = 20000, intervalMs = 500 } = {}
) {
  const start = Date.now();
  let lastError = null;
  while (Date.now() - start < timeoutMs) {
    try {
      return readActiveDevToolsPort({ paths });
    } catch (error) {
      lastError = error;
    }
    await sleep(intervalMs);
  }
  throw new Error(
    `DevToolsActivePort did not appear within ${timeoutMs}ms ` +
      `(last error: ${lastError?.message || 'none'}). ` +
      `Make sure Codex launched via \`codex:launch\`.`
  );
}

export async function ensureCodexWithDebugPort(
  { run = defaultRun, paths = getCodexPaths(), port = defaultDevToolsPort() } = {}
) {
  try {
    return readActiveDevToolsPort({ paths });
  } catch {
    // Port file missing — launch Codex with the flag and wait for it.
    launchCodexWithDebugPort(port, { run, paths });
    return waitForDevToolsPort({ paths });
  }
}
