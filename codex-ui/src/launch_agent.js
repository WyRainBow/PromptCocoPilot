import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export function getLaunchAgentPaths(homeDir = process.env.HOME, rootDir = process.cwd()) {
  const launchAgentsDir = path.join(homeDir, 'Library/LaunchAgents');
  const logDir = path.join(homeDir, 'Library/Logs/prompt-coco-codex');
  const label = 'local.prompt-coco-codex-optimize-input';
  return {
    label,
    launchAgentsDir,
    logDir,
    plistPath: path.join(launchAgentsDir, `${label}.plist`),
    nodePath: process.execPath,
    entryPath: path.join(rootDir, 'codex-ui/bin/codex-optimize-input.js'),
    logPath: path.join(logDir, 'codex-optimize-input.log'),
    errorLogPath: path.join(logDir, 'codex-optimize-input.err.log'),
    supportDir: process.env.CODEX_USER_DATA_DIR ||
      path.join(homeDir, 'Library/Application Support/Codex')
  };
}

function xmlEscape(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

export function createLaunchAgentPlist({ label, nodePath, entryPath, logPath, errorLogPath, supportDir }) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${xmlEscape(label)}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${xmlEscape(nodePath)}</string>
    <string>${xmlEscape(entryPath)}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CODEX_USER_DATA_DIR</key>
    <string>${xmlEscape(supportDir)}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${xmlEscape(logPath)}</string>
  <key>StandardErrorPath</key>
  <string>${xmlEscape(errorLogPath)}</string>
</dict>
</plist>
`;
}

export function installLaunchAgent({ homeDir = process.env.HOME, rootDir = process.cwd() } = {}) {
  const paths = getLaunchAgentPaths(homeDir, rootDir);
  fs.mkdirSync(paths.launchAgentsDir, { recursive: true });
  fs.mkdirSync(paths.logDir, { recursive: true });
  fs.writeFileSync(paths.plistPath, createLaunchAgentPlist(paths), 'utf8');

  const domain = `gui/${process.getuid()}`;
  try {
    execFileSync('launchctl', ['bootout', domain, paths.plistPath], { stdio: 'ignore' });
  } catch {
    // Not loaded yet.
  }
  execFileSync('launchctl', ['bootstrap', domain, paths.plistPath], { stdio: 'ignore' });
  execFileSync('launchctl', ['enable', `${domain}/${paths.label}`], { stdio: 'ignore' });
  return paths;
}

export function uninstallLaunchAgent({ homeDir = process.env.HOME, rootDir = process.cwd() } = {}) {
  const paths = getLaunchAgentPaths(homeDir, rootDir);
  const domain = `gui/${process.getuid()}`;
  try {
    execFileSync('launchctl', ['bootout', domain, paths.plistPath], { stdio: 'ignore' });
  } catch {
    // Already unloaded.
  }
  if (fs.existsSync(paths.plistPath)) fs.unlinkSync(paths.plistPath);
  return paths;
}
