#!/usr/bin/env node
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { runDaemon, attachAndRunOnce } from '../src/daemon.js';
import { installLaunchAgent, uninstallLaunchAgent } from '../src/launch_agent.js';
import { launchCodexWithDebugPort, defaultDevToolsPort } from '../src/codex_launcher.js';

const rootDir = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))));

async function main() {
  const command = process.argv[2];
  if (command === 'launch') {
    const port = defaultDevToolsPort();
    try {
      launchCodexWithDebugPort(port);
      console.log(`[prompt-coco-codex] launching Codex with --remote-debugging-port=${port}`);
      console.log('[prompt-coco-codex] once Codex is open, run `npm run codex:probe` to inspect its DOM');
    } catch (error) {
      console.error(`[prompt-coco-codex] ${error.message}`);
      process.exitCode = 1;
    }
    return;
  }
  if (command === 'probe') {
    try {
      await attachAndRunOnce({ probe: true });
    } catch (error) {
      console.error(`[prompt-coco-codex] probe failed: ${error.message}`);
      console.error('[prompt-coco-codex] hint: run `npm run codex:launch` first so Codex exposes a debug port');
      process.exitCode = 1;
    }
    return;
  }
  if (command === 'install-agent') {
    const paths = installLaunchAgent({ rootDir });
    console.log(`[prompt-coco-codex] installed LaunchAgent at ${paths.plistPath}`);
    console.log(`[prompt-coco-codex] logs: ${paths.errorLogPath}`);
    return;
  }
  if (command === 'uninstall-agent') {
    const paths = uninstallLaunchAgent({ rootDir });
    console.log(`[prompt-coco-codex] removed LaunchAgent at ${paths.plistPath}`);
    return;
  }
  await runDaemon();
}

main().catch((error) => {
  console.error(`[prompt-coco-codex] ${error.stack || error.message}`);
  process.exitCode = 1;
});
