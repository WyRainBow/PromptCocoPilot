import test from 'node:test';
import assert from 'node:assert/strict';
import { isCodexRunning, launchCodexWithDebugPort, defaultDevToolsPort, discoverDevToolsPort } from '../src/codex_launcher.js';

test('defaultDevToolsPort is re-exported from codex_launcher for the bin entrypoint', () => {
  assert.equal(typeof defaultDevToolsPort, 'function');
  const port = defaultDevToolsPort();
  assert.ok(Number.isInteger(port) && port > 0, 'default port must be a positive integer');
});

test('isCodexRunning returns true when pgrep finds a pid', () => {
  assert.equal(isCodexRunning(() => '89584\n'), true);
});

test('isCodexRunning returns false when pgrep finds nothing', () => {
  assert.equal(
    isCodexRunning(() => {
      throw new Error('no match');
    }),
    false
  );
});

test('launchCodexWithDebugPort rejects invalid ports', () => {
  assert.throws(() => launchCodexWithDebugPort(0, { run: () => '' }), /positive integer/);
});

test('launchCodexWithDebugPort refuses when Codex already runs without a debug port', () => {
  assert.throws(
    () => launchCodexWithDebugPort(9222, { run: () => '89584\n' }),
    /already running without a debug port/
  );
});

test('launchCodexWithDebugPort opens Codex with the flag when it is not running', () => {
  const calls = [];
  const run = (cmd, args) => {
    calls.push([cmd, ...args]);
    if (cmd === 'pgrep') return ''; // no match
    return '';
  };
  const port = launchCodexWithDebugPort(9222, { run });
  assert.equal(port, 9222);
  const openCall = calls.find(([cmd]) => cmd === 'open');
  assert.ok(openCall, 'expected an open invocation');
  assert.ok(openCall.includes('--remote-debugging-port=9222'));
});

test('discoverDevToolsPort scans candidates and returns the one hosting a Codex renderer', async () => {
  const fakeFetch = async (url) => {
    if (url.includes('9222')) {
      return { ok: true, json: async () => [{ type: 'page', url: 'chrome://newtab', title: 'New Tab' }] };
    }
    if (url.includes('9333')) {
      return { ok: true, json: async () => [{ type: 'page', url: 'app://-/index.html', title: 'Codex' }] };
    }
    throw new Error('ECONNREFUSED');
  };
  const original = globalThis.fetch;
  globalThis.fetch = fakeFetch;
  try {
    const port = await discoverDevToolsPort({
      paths: { devToolsActivePort: '/nonexistent/devtools-port' },
      candidates: [9222, 9333]
    });
    assert.equal(port, 9333);
  } finally {
    globalThis.fetch = original;
  }
});

test('discoverDevToolsPort prefers an explicit env port over scanning', async () => {
  process.env.CODEX_DEVTOOLS_PORT = '7777';
  try {
    const port = await discoverDevToolsPort({ candidates: [9333] });
    assert.equal(port, 7777);
  } finally {
    delete process.env.CODEX_DEVTOOLS_PORT;
  }
});
