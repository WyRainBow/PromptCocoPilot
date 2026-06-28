import { getCodexPaths } from './codex_paths.js';
import { discoverDevToolsPort } from './codex_launcher.js';
import { DevToolsClient } from './devtools_client.js';
import { createOptimizeInputObserverScript, createProbeScript } from './observer_script.js';

export const BINDING_NAME = 'promptCocoPilotCodex';
export const ENHANCE_ENDPOINT = process.env.ENHANCE_ENDPOINT || 'http://127.0.0.1:8765/enhance';

// Codex's renderer URL is not yet pinned down (unlike Qoder's
// /out/lingma/agents-window/). These are background/devtools pages we skip.
const BACKGROUND_URL = /^(devtools:|chrome-extension:|chrome:|about:blank|\s*$)/;

export function findCodexMainWindowTarget(targets) {
  const pages = (targets || []).filter(
    (candidate) => candidate.type === 'page' && candidate.webSocketDebuggerUrl
  );
  if (!pages.length) throw new Error('No Codex renderer page target was found');

  const looksLikeShell = (url) =>
    !BACKGROUND_URL.test(url) &&
    (url.startsWith('app://') ||
      url.startsWith('file://') ||
      /codex/i.test(url) ||
      /owl/i.test(url) ||
      /^https?:\/\/(localhost|127\.0\.0\.1)/.test(url));

  const shell = pages.find((candidate) => looksLikeShell(String(candidate.url || '')));
  if (shell) return shell;

  const nonBackground = pages.filter((candidate) => !BACKGROUND_URL.test(String(candidate.url || '')));
  if (nonBackground.length) return nonBackground[0];
  return pages[0];
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

export async function attachAndRunOnce({ paths = getCodexPaths(), probe = false } = {}) {
  const port = await discoverDevToolsPort({ paths });
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('CODEX_DEVTOOLS_PORT must be a positive integer');
  }
  const target = findCodexMainWindowTarget(await getDevToolsTargets(port));
  const client = new DevToolsClient(target.webSocketDebuggerUrl);
  await client.connect();
  client.targetUrl = target.url;
  client.on('Runtime.bindingCalled', (params) => {
    const payload = parseBindingPayload(params);
    if (!payload) return;
    const suffix = payload.beforeLength == null ? '' : ` beforeLength=${payload.beforeLength}`;
    console.log(`[prompt-coco-codex] ${payload.type}${suffix}`);
  });

  if (probe) {
    const result = await probeDom(client);
    console.log(JSON.stringify(result, null, 2));
    client.close();
    return client;
  }

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
      console.error(`[prompt-coco-codex] poll-error: ${error.message}`);
    });
  }, 500);
  client.onCloseCleanup = () => clearInterval(pollTimer);

  console.log(`[prompt-coco-codex] attached to Codex main window (${target.url || 'unknown url'})`);
  return client;
}

async function probeDom(client) {
  const response = await client.send('Runtime.evaluate', {
    expression: createProbeScript(),
    awaitPromise: false,
    returnByValue: true
  });
  const value = response.result?.result?.value;
  return typeof value === 'string' ? JSON.parse(value) : value;
}

async function drainPendingOptimizeRequests(client) {
  const response = await client.send('Runtime.evaluate', {
    expression: `(() => {
      const pending = window.__promptCocoPilotCodexPendingRequests || [];
      window.__promptCocoPilotCodexPendingRequests = [];
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
    const response = await fetch(ENHANCE_ENDPOINT, {
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
    console.log(`[prompt-coco-codex] optimize-success beforeLength=${payload.beforeLength ?? 0}`);
  } catch (error) {
    try {
      await applyOptimizeResult(client, payload.requestId, {
        error: '服务未开'
      });
    } catch (applyError) {
      console.error(`[prompt-coco-codex] apply-error: ${applyError.message}`);
    }
    console.error(`[prompt-coco-codex] optimize-error: ${error.message}`);
  }
}

async function applyOptimizeResult(client, requestId, payload) {
  await client.send('Runtime.evaluate', {
    expression: `window.__promptCocoPilotCodexApply?.(${JSON.stringify(requestId)}, ${JSON.stringify(payload)})`,
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
      console.log('[prompt-coco-codex] DevTools connection closed; reconnecting');
    } catch (error) {
      console.error(`[prompt-coco-codex] attach failed: ${error.message}`);
    } finally {
      client?.close();
    }
    await new Promise((resolve) => setTimeout(resolve, delayMs));
    delayMs = Math.min(delayMs * 2, 15000);
  }
}
