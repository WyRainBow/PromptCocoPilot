export function createOptimizeInputObserverScript(bindingName = 'promptCocoPilotQoder') {
  return `
(() => {
  const version = '2026-06-22-optimize-input-binding';
  window.__promptCocoPilotQoderAbortController?.abort?.();
  const abortController = new AbortController();
  window.__promptCocoPilotQoderAbortController = abortController;
  window.__promptCocoPilotQoderInstalled = true;
  window.__promptCocoPilotQoderVersion = version;
  window.__promptCocoPilotQoderRequestSeq = window.__promptCocoPilotQoderRequestSeq || 0;
  window.__promptCocoPilotQoderPendingRequests = window.__promptCocoPilotQoderPendingRequests || [];

  const binding = ${JSON.stringify(bindingName)};

  function inputElement() {
    const candidates = [...document.querySelectorAll('.chat-input-contenteditable')]
      .map((element) => ({ element, rect: element.getBoundingClientRect() }))
      .filter(({ rect }) =>
        rect.width > 0 &&
        rect.height > 0 &&
        rect.top >= 0 &&
        rect.bottom <= window.innerHeight
      )
      .sort((a, b) => b.rect.bottom - a.rect.bottom);
    return candidates[0]?.element || null;
  }

  function inputText() {
    const input = inputElement();
    return (input?.innerText || input?.textContent || '').trim();
  }

  function visiblePromptEnhanceButton() {
    const candidates = [...document.querySelectorAll('[aria-label="Prompt Enhance"]')]
      .map((element) => ({ element, rect: element.getBoundingClientRect() }))
      .filter(({ rect }) => rect.width > 0 && rect.height > 0 && rect.top >= 0 && rect.bottom <= window.innerHeight)
      .sort((a, b) => b.rect.bottom - a.rect.bottom);
    return candidates[0]?.element || null;
  }

  function visibleContext() {
    const raw = (document.body?.innerText || '')
      .replace(/\\n{3,}/g, '\\n\\n')
      .trim();
    const MAX = 6000;
    if (raw.length <= MAX) return raw;
    // head + tail, not pure tail: keep the original task definition / setup
    // (top of the conversation) AND the most recent messages, matching the
    // structured path's head/tail behavior so long chats don't lose intent.
    const head = Math.floor(MAX * 0.6);
    const tail = MAX - head;
    return raw.slice(0, head).trim() + '\\n…[truncated]…\\n' + raw.slice(-tail).trim();
  }

  function setInputText(text) {
    const input = inputElement();
    if (!input) return false;
    input.focus();
    input.textContent = text;
    input.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      inputType: 'insertText',
      data: text
    }));
    return true;
  }

  function diagnostic(type, extra = {}) {
    try {
      window[binding](JSON.stringify({ type, capturedAt: Date.now(), ...extra }));
    } catch {
      // Binding is diagnostic-only for this feature.
    }
  }

  function ensureOptimizeStyles() {
    const existingStyle = document.getElementById('qoder-optimize-input-style');
    if (existingStyle?.dataset.promptCocoPilotVersion === version) return;
    existingStyle?.remove();
    const style = document.createElement('style');
    style.id = 'qoder-optimize-input-style';
    style.dataset.promptCocoPilotVersion = version;
    style.textContent = \`
      .qoder-optimize-input-button {
        height: 22px;
        min-width: 22px;
        border: 0;
        border-radius: 4px;
        background: transparent;
        color: var(--foreground, #555);
        font: 600 12px/22px -apple-system, BlinkMacSystemFont, sans-serif;
        cursor: pointer;
        padding: 0 6px;
      }
      .qoder-optimize-input-button:hover { background: rgba(127, 127, 127, 0.16); }
      .qoder-optimize-input-button[data-busy="true"] { cursor: wait; opacity: 0.62; }
    \`;
    document.head.appendChild(style);
  }

  window.__promptCocoPilotQoderApply = (requestId, payload) => {
    const button = document.querySelector('.qoder-optimize-input-button');
    if (payload?.enhanced) {
      setInputText(payload.enhanced);
      if (button) {
        button.textContent = '已优化';
        setTimeout(() => (button.textContent = '优化输入'), 1200);
      }
    } else if (button) {
      button.textContent = payload?.error || '优化失败';
      setTimeout(() => (button.textContent = '优化输入'), 1800);
    }
    if (button) button.dataset.busy = 'false';
  };

  function optimize(button) {
    const draft = inputText();
    if (!draft) {
      button.textContent = '先输入';
      setTimeout(() => (button.textContent = '优化输入'), 1200);
      return;
    }

    const requestId = ++window.__promptCocoPilotQoderRequestSeq;
    button.dataset.busy = 'true';
    button.textContent = '优化中';
    try {
      const request = {
        type: 'optimize-request',
        requestId,
        draft,
        context: 'Visible Qoder context (button path, head+tail truncated):\\n' + visibleContext(),
        source: 'ui-button',
        beforeLength: draft.length,
        capturedAt: Date.now()
      };
      window.__promptCocoPilotQoderPendingRequests.push(request);
      diagnostic('optimize-request', { requestId, beforeLength: draft.length });
    } catch (error) {
      diagnostic('optimize-error', { message: String(error?.message || error) });
      button.textContent = '服务未开';
      setTimeout(() => (button.textContent = '优化输入'), 1800);
    }
  }

  function ensureOptimizeButton() {
    ensureOptimizeStyles();
    const enhanceButton = visiblePromptEnhanceButton();
    const input = inputElement();
    const anchor = enhanceButton || input;
    if (!anchor) return;
    const parent = anchor.parentElement;
    if (!parent) return;
    const existingButton = parent.querySelector('.qoder-optimize-input-button');
    if (existingButton?.dataset.promptCocoPilotVersion === version) return;
    existingButton?.remove();

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'qoder-optimize-input-button';
    button.dataset.promptCocoPilotVersion = version;
    button.setAttribute('aria-label', '优化输入');
    button.title = '优化输入';
    button.textContent = '优化输入';
    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      void optimize(button);
    });
    if (enhanceButton) {
      parent.insertBefore(button, enhanceButton);
    } else {
      parent.appendChild(button);
    }
  }

  const timer = setInterval(ensureOptimizeButton, 1000);
  abortController.signal.addEventListener('abort', () => {
    clearInterval(timer);
    document.querySelectorAll('.qoder-optimize-input-button').forEach((element) => element.remove());
  });
  ensureOptimizeButton();
  diagnostic('installed');
})();
`;
}
