import path from 'node:path';

export function getCodexPaths(homeDir = process.env.HOME) {
  const supportDir = process.env.CODEX_USER_DATA_DIR ||
    path.join(homeDir, 'Library/Application Support/Codex');

  return {
    supportDir,
    // Electron writes DevToolsActivePort into the user-data dir only when the
    // app is launched with --remote-debugging-port. Codex does NOT enable this
    // by default (unlike Qoder), so this file appears only after `codex:launch`.
    devToolsActivePort: path.join(supportDir, 'DevToolsActivePort'),
    appBundlePath: process.env.CODEX_APP_PATH || '/Applications/Codex.app',
    // App name passed to `open -a <name>`.
    appBundleName: process.env.CODEX_APP_NAME || 'Codex'
  };
}

export function defaultDevToolsPort() {
  const port = Number(process.env.CODEX_DEVTOOLS_PORT || 9222);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('CODEX_DEVTOOLS_PORT must be a positive integer');
  }
  return port;
}

export function readDevToolsPort(content) {
  const firstLine = String(content || '').split(/\r?\n/)[0]?.trim();
  const port = Number(firstLine);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('DevTools port was not found in DevToolsActivePort');
  }
  return port;
}
