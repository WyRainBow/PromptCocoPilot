import fs from 'node:fs';
import { getQoderPaths, readDevToolsPort } from './qoder_paths.js';
import { DevToolsClient } from './devtools_client.js';
import { createOptimizeInputObserverScript } from './observer_script.js';

export const BINDING_NAME = 'promptCocoPilotQoder';

export function findAgentsWindowTarget(targets) {
  const agentsWindowTarget = targets.find((candidate) =>
    candidate.type === 'page' &&
    candidate.webSocketDebuggerUrl &&
    String(candidate.url || '').includes('/out/lingma/agents-window/')
  );
  if (agentsWindowTarget) return agentsWindowTarget;

  const target = targets.find((candidate) =>
    candidate.type === 'page' &&
    candidate.webSocketDebuggerUrl &&
    String(candidate.url || '').includes('/out/vs/code/electron-browser/workbench/workbench.html')
  );
  if (!target) throw new Error('Qoder agents window DevTools target was not found');
  return target;
}

export function parseBindingPayload(params) {
  if (params?.name !== BINDING_NAME) return undefined;
  const payload = JSON.parse(params.payload || '{}');
  const parsed = { type: String(payload.type || 'diagnostic') };
  if (payload.requestId != null) parsed.requestId = payload.requestId;
  if (payload.draft != null) parsed.draft = String(payload.draft);
  if (payload.context != null) parsed.context = String(payload.context);
  if (payload.source != null) parsed.source = String(payload.source);
  if (payload.beforeLength != null) parsed.beforeLength = payload.beforeLength;
  if (payload.afterLength != null) parsed.afterLength = payload.afterLength;
  if (payload.message != null) parsed.message = payload.message;
  return parsed;
}

export async function getDevToolsTargets(port) {
  const response = await fetch(`http://127.0.0.1:${port}/json/list`);
  if (!response.ok) throw new Error(`DevTools target list failed: ${response.status}`);
  return response.json();
}

export async function attachAndRunOnce({ paths = getQoderPaths() } = {}) {
  const port = process.env.QODER_DEVTOOLS_PORT
    ? Number(process.env.QODER_DEVTOOLS_PORT)
    : readDevToolsPort(fs.readFileSync(paths.devToolsActivePort, 'utf8'));
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('QODER_DEVTOOLS_PORT must be a positive integer');
  }
  const target = findAgentsWindowTarget(await getDevToolsTargets(port));
  const client = new DevToolsClient(target.webSocketDebuggerUrl);
  await client.connect();
  client.on('Runtime.bindingCalled', (params) => {
    const payload = parseBindingPayload(params);
    if (!payload) return;
    const suffix = payload.beforeLength == null ? '' : ` beforeLength=${payload.beforeLength}`;
    console.log(`[prompt-coco-qoder] ${payload.type}${suffix}`);
  });

  await client.send('Runtime.enable');
  await client.send('Runtime.addBinding', { name: BINDING_NAME });
  await client.send('Page.addScriptToEvaluateOnNewDocument', {
    source: createOptimizeInputObserverScript(BINDING_NAME)
  });
  await client.send('Runtime.evaluate', {
    expression: createOptimizeInputObserverScript(BINDING_NAME),
    awaitPromise: false
  });

  const pollTimer = setInterval(() => {
    void drainPendingOptimizeRequests(client).catch((error) => {
      console.error(`[prompt-coco-qoder] poll-error: ${error.message}`);
    });
  }, 500);
  client.onCloseCleanup = () => clearInterval(pollTimer);

  console.log('[prompt-coco-qoder] attached to Qoder agents window');
  return client;
}

async function drainPendingOptimizeRequests(client) {
  const response = await client.send('Runtime.evaluate', {
    expression: `(() => {
      const pending = window.__promptCocoPilotQoderPendingRequests || [];
      window.__promptCocoPilotQoderPendingRequests = [];
      return pending;
    })()`,
    awaitPromise: false,
    returnByValue: true
  });
  const requests = response.result?.result?.value || [];
  for (const request of requests) {
    if (request?.type === 'optimize-request') {
      await handleOptimizeRequest(client, request);
    }
  }
}

async function handleOptimizeRequest(client, payload) {
  try {
    const response = await fetch('http://127.0.0.1:8765/enhance', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        draft: payload.draft,
        context: payload.context,
        ...(payload.source ? { source: payload.source } : {})
      })
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || `HTTP ${response.status}`);
    await applyOptimizeResult(client, payload.requestId, {
      enhanced: result.enhanced
    });
    console.log(`[prompt-coco-qoder] optimize-success beforeLength=${payload.beforeLength ?? 0}`);
  } catch (error) {
    try {
      await applyOptimizeResult(client, payload.requestId, {
        error: '服务未开'
      });
    } catch (applyError) {
      console.error(`[prompt-coco-qoder] apply-error: ${applyError.message}`);
    }
    console.error(`[prompt-coco-qoder] optimize-error: ${error.message}`);
  }
}

async function applyOptimizeResult(client, requestId, payload) {
  await client.send('Runtime.evaluate', {
    expression: `window.__promptCocoPilotQoderApply?.(${JSON.stringify(requestId)}, ${JSON.stringify(payload)})`,
    awaitPromise: false
  });
}

export async function runDaemon() {
  let delayMs = 1000;
  for (;;) {
    let client;
    try {
      client = await attachAndRunOnce();
      delayMs = 1000;
      await new Promise((resolve) => {
        const keepAlive = setInterval(() => {}, 1000);
        client.ws.onclose = () => {
          clearInterval(keepAlive);
          client.onCloseCleanup?.();
          resolve();
        };
        client.ws.onerror = () => {
          clearInterval(keepAlive);
          client.onCloseCleanup?.();
          resolve();
        };
      });
      console.log('[prompt-coco-qoder] DevTools connection closed; reconnecting');
    } catch (error) {
      console.error(`[prompt-coco-qoder] attach failed: ${error.message}`);
    } finally {
      client?.close();
    }
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    delayMs = Math.min(delayMs * 2, 15000);
  }
}
