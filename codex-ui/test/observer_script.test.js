import test from 'node:test';
import assert from 'node:assert/strict';
import { createOptimizeInputObserverScript, createProbeScript } from '../src/observer_script.js';

test('observer script injects an optimize input button for Codex', () => {
  const script = createOptimizeInputObserverScript('promptCocoPilotCodex');

  assert.match(script, /优化输入/);
  assert.match(script, /ProseMirror/);
  assert.match(script, /composer/);
  assert.match(script, /window\[binding\]/);
  assert.match(script, /type: 'optimize-request'/);
  assert.match(script, /__promptCocoPilotCodexPendingRequests/);
  assert.match(script, /__promptCocoPilotCodexApply/);
  assert.match(script, /codex-optimize-input-button/);
});

test('observer script supports versioned replacement of a previous injection', () => {
  const script = createOptimizeInputObserverScript();

  assert.match(script, /__promptCocoPilotCodexAbortController/);
  assert.match(script, /abortController/);
});

test('observer script writes text through both native setter (textarea) and execCommand (contenteditable)', () => {
  const script = createOptimizeInputObserverScript();

  assert.match(script, /setNativeValue/);
  assert.match(script, /HTMLTextAreaElement/);
  assert.match(script, /execCommand\('insertText'/);
});

test('probe script reports input and send-button candidates', () => {
  const script = createProbeScript();

  assert.match(script, /inputCandidates/);
  assert.match(script, /sendButtons/);
  assert.match(script, /ProseMirror/);
});
