import test from 'node:test';
import assert from 'node:assert/strict';
import { createOptimizeInputObserverScript } from '../src/observer_script.js';

test('observer script injects optimize input button beside Qoder Prompt Enhance', () => {
  const script = createOptimizeInputObserverScript('promptCocoPilotQoder');

  assert.match(script, /优化输入/);
  assert.match(script, /Prompt Enhance/);
  assert.match(script, /chat-input-contenteditable/);
  assert.match(script, /window\[binding\]/);
  assert.match(script, /type: 'optimize-request'/);
  assert.match(script, /__promptCocoPilotQoderPendingRequests/);
  assert.match(script, /__promptCocoPilotQoderApply/);
});

test('observer script version changes can replace old injection', () => {
  const script = createOptimizeInputObserverScript();

  assert.match(script, /__promptCocoPilotQoderAbortController/);
  assert.match(script, /abortController/);
  assert.match(script, /qoder-optimize-input-button/);
});
