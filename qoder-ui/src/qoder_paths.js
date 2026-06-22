import path from 'node:path';

export function getQoderPaths(homeDir = process.env.HOME) {
  const supportDir = process.env.QODER_SUPPORT_DIR ||
    path.join(homeDir, 'Library/Application Support/Qoder');

  return {
    supportDir,
    devToolsActivePort: path.join(supportDir, 'DevToolsActivePort')
  };
}

export function readDevToolsPort(content) {
  const firstLine = String(content || '').split(/\r?\n/)[0]?.trim();
  const port = Number(firstLine);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('DevTools port was not found in DevToolsActivePort');
  }
  return port;
}
