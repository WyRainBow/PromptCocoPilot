#!/usr/bin/env node
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { runDaemon } from '../src/daemon.js';
import { installLaunchAgent, uninstallLaunchAgent } from '../src/launch_agent.js';

const rootDir = path.dirname(path.dirname(path.dirname(fileURLToPath(import.meta.url))));

async function main() {
  const command = process.argv[2];
  if (command === 'install-agent') {
    const paths = installLaunchAgent({ rootDir });
    console.log(`[prompt-coco-qoder] installed LaunchAgent at ${paths.plistPath}`);
    return;
  }
  if (command === 'uninstall-agent') {
    const paths = uninstallLaunchAgent({ rootDir });
    console.log(`[prompt-coco-qoder] removed LaunchAgent at ${paths.plistPath}`);
    return;
  }
  await runDaemon();
}

main().catch((error) => {
  console.error(`[prompt-coco-qoder] ${error.stack || error.message}`);
  process.exitCode = 1;
});
