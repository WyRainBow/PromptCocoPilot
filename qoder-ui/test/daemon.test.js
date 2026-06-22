import test from 'node:test';
import assert from 'node:assert/strict';
import { findAgentsWindowTarget, parseBindingPayload } from '../src/daemon.js';

test('findAgentsWindowTarget returns Qoder agents window page target', () => {
  const target = findAgentsWindowTarget([
    { type: 'page', url: 'qoder://x/out/other', webSocketDebuggerUrl: 'ws://a' },
    { type: 'page', url: 'qoder://x/out/lingma/agents-window/index.html', webSocketDebuggerUrl: 'ws://b' }
  ]);

  assert.equal(target.webSocketDebuggerUrl, 'ws://b');
});

test('findAgentsWindowTarget falls back to Qoder workbench page target', () => {
  const target = findAgentsWindowTarget([
    {
      type: 'page',
      url: 'vscode-file://vscode-app/Applications/Qoder.app/Contents/Resources/app/out/vs/code/electron-browser/workbench/workbench.html',
      webSocketDebuggerUrl: 'ws://workbench'
    }
  ]);

  assert.equal(target.webSocketDebuggerUrl, 'ws://workbench');
});

test('parseBindingPayload ignores other bindings and parses diagnostics', () => {
  assert.equal(parseBindingPayload({ name: 'other', payload: '{}' }), undefined);
  assert.deepEqual(
    parseBindingPayload({
      name: 'promptCocoPilotQoder',
      payload: JSON.stringify({
        type: 'optimize-request',
        requestId: 3,
        draft: '那这个怎么改',
        context: 'Visible Qoder context',
        beforeLength: 12
      })
    }),
    {
      type: 'optimize-request',
      requestId: 3,
      draft: '那这个怎么改',
      context: 'Visible Qoder context',
      beforeLength: 12
    }
  );
});
