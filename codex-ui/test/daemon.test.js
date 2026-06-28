import test from 'node:test';
import assert from 'node:assert/strict';
import { findCodexMainWindowTarget, parseBindingPayload, BINDING_NAME } from '../src/daemon.js';

test('findCodexMainWindowTarget prefers a codex/owl/app-shell url over background pages', () => {
  const target = findCodexMainWindowTarget([
    { type: 'page', url: 'about:blank', webSocketDebuggerUrl: 'ws://blank' },
    { type: 'page', url: 'app://codex/index.html', webSocketDebuggerUrl: 'ws://shell' }
  ]);
  assert.equal(target.webSocketDebuggerUrl, 'ws://shell');
});

test('findCodexMainWindowTarget matches an owl-named renderer', () => {
  const target = findCodexMainWindowTarget([
    { type: 'page', url: 'file:///owl/desktop/index.html', webSocketDebuggerUrl: 'ws://owl' }
  ]);
  assert.equal(target.webSocketDebuggerUrl, 'ws://owl');
});

test('findCodexMainWindowTarget falls back to the only non-background page', () => {
  const target = findCodexMainWindowTarget([
    { type: 'page', url: 'https://localhost:3000/chat', webSocketDebuggerUrl: 'ws://chat' }
  ]);
  assert.equal(target.webSocketDebuggerUrl, 'ws://chat');
});

test('findCodexMainWindowTarget throws when there is no page target', () => {
  assert.throws(
    () => findCodexMainWindowTarget([
      { type: 'background_page', url: 'x', webSocketDebuggerUrl: 'ws://bg' }
    ]),
    /No Codex renderer page target/
  );
});

test('parseBindingPayload ignores other bindings and parses diagnostics', () => {
  assert.equal(parseBindingPayload({ name: 'other', payload: '{}' }), undefined);
  assert.deepEqual(
    parseBindingPayload({
      name: BINDING_NAME,
      payload: JSON.stringify({
        type: 'optimize-request',
        requestId: 7,
        draft: '那这个怎么改',
        context: 'Visible Codex context',
        beforeLength: 12
      })
    }),
    {
      type: 'optimize-request',
      requestId: 7,
      draft: '那这个怎么改',
      context: 'Visible Codex context',
      beforeLength: 12
    }
  );
});
