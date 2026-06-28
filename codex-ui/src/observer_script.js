// Selectors probed to locate the Codex composer. Codex (owl) is React-based and
// likely uses a ProseMirror editor or a <textarea>; we try them in priority
// order and fall back to generic contenteditable / role=textbox matches.
const INPUT_SELECTORS = [
  '.ProseMirror',
  '[data-testid="composer-textarea"]',
  '[data-testid*="composer" i]',
  'textarea:not([disabled])',
  '[contenteditable="true"]',
  '[role="textbox"]'
];

const SEND_SELECTORS = [
  '[data-testid="send-button"]',
  '[data-testid*="send" i]',
  'button[aria-label*="send" i]',
  'button[aria-label*="发送" i]',
  'button[aria-label*="提交" i]',
  'button[type="submit"]'
];

function rectSnapshot(rect) {
  return {
    width: Math.round(rect.width),
    height: Math.round(rect.height),
    top: Math.round(rect.top),
    bottom: Math.round(rect.bottom),
    left: Math.round(rect.left)
  };
}

function isVisibleRect(rect) {
  return (
    rect.width > 0 &&
    rect.height > 0 &&
    rect.top >= 0 &&
    rect.bottom <= window.innerHeight
  );
}

export function createProbeScript() {
  return `
(() => {
  const INPUT_SELECTORS = ${JSON.stringify(INPUT_SELECTORS)};
  const SEND_SELECTORS = ${JSON.stringify(SEND_SELECTORS)};
  const seen = new Set();

  function describeInput(el, source) {
    const rect = el.getBoundingClientRect();
    return {
      source,
      tag: el.tagName,
      role: el.getAttribute('role') || '',
      ariaLabel: el.getAttribute('aria-label') || '',
      placeholder: el.getAttribute('placeholder') || '',
      dataTestId: el.getAttribute('data-testid') || '',
      contentEditable: el.isContentEditable,
      classes: (el.className && el.className.toString) ? el.className.toString().slice(0, 160) : '',
      value: (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') ? (el.value || '').slice(0, 200) : (el.innerText || '').slice(0, 200),
      rect: { width: Math.round(rect.width), height: Math.round(rect.height), top: Math.round(rect.top), bottom: Math.round(rect.bottom) },
      visible: rect.width > 0 && rect.height > 0 && rect.top >= 0 && rect.bottom <= window.innerHeight
    };
  }

  function describeButton(el) {
    const rect = el.getBoundingClientRect();
    return {
      tag: el.tagName,
      type: el.getAttribute('type') || '',
      ariaLabel: el.getAttribute('aria-label') || '',
      dataTestId: el.getAttribute('data-testid') || '',
      text: (el.innerText || '').trim().slice(0, 40),
      classes: (el.className && el.className.toString) ? el.className.toString().slice(0, 120) : '',
      rect: { width: Math.round(rect.width), height: Math.round(rect.height), top: Math.round(rect.top), bottom: Math.round(rect.bottom) },
      visible: rect.width > 0 && rect.height > 0 && rect.top >= 0 && rect.bottom <= window.innerHeight
    };
  }

  const inputCandidates = [];
  for (const sel of INPUT_SELECTORS) {
    let nodes = [];
    try { nodes = [...document.querySelectorAll(sel)]; } catch {}
    for (const el of nodes) {
      if (seen.has(el)) continue;
      seen.add(el);
      inputCandidates.push(describeInput(el, sel));
    }
  }

  const sendButtons = [];
  const seenBtn = new Set();
  for (const sel of SEND_SELECTORS) {
    let nodes = [];
    try { nodes = [...document.querySelectorAll(sel)]; } catch {}
    for (const el of nodes) {
      if (seenBtn.has(el)) continue;
      seenBtn.add(el);
      sendButtons.push(describeButton(el));
    }
  }

  return JSON.stringify({
    url: location.href,
    title: document.title || '',
    inputCandidates: inputCandidates.sort((a, b) => b.rect.bottom - a.rect.bottom),
    sendButtons: sendButtons.sort((a, b) => Number(b.visible) - Number(a.visible))
  });
})();
`;
}

export function createOptimizeInputObserverScript(bindingName = 'promptCocoPilotCodex') {
  return `
(() => {
  const version = '2026-06-28-codex-multi-selector';
  window.__promptCocoPilotCodexAbortController?.abort?.();
  const abortController = new AbortController();
  window.__promptCocoPilotCodexAbortController = abortController;
  window.__promptCocoPilotCodexInstalled = true;
  window.__promptCocoPilotCodexVersion = version;
  window.__promptCocoPilotCodexRequestSeq = window.__promptCocoPilotCodexRequestSeq || 0;
  window.__promptCocoPilotCodexPendingRequests = window.__promptCocoPilotCodexPendingRequests || [];

  const binding = ${JSON.stringify(bindingName)};
  const INPUT_SELECTORS = ${JSON.stringify(INPUT_SELECTORS)};
  const SEND_SELECTORS = ${JSON.stringify(SEND_SELECTORS)};

  function inputCandidates() {
    const seen = new Set();
    const out = [];
    for (const sel of INPUT_SELECTORS) {
      let nodes = [];
      try { nodes = [...document.querySelectorAll(sel)]; } catch {}
      for (const el of nodes) {
        if (seen.has(el)) continue;
        seen.add(el);
        out.push(el);
      }
    }
    return out;
  }

  function inputElement() {
    const visible = inputCandidates()
      .map((element) => ({ element, rect: element.getBoundingClientRect() }))
      .filter(({ rect }) =>
        rect.width > 0 &&
        rect.height > 0 &&
        rect.top >= 0 &&
        rect.bottom <= window.innerHeight
      )
      .sort((a, b) => b.rect.bottom - a.rect.bottom);
    return visible[0]?.element || null;
  }

  function inputText() {
    const input = inputElement();
    if (!input) return '';
    if (input.tagName === 'TEXTAREA' || input.tagName === 'INPUT') {
      return (input.value || '').trim();
    }
    return (input.innerText || input.textContent || '').trim();
  }

  function visibleContext() {
    const text = (document.body?.innerText || '')
      .replace(/\\n{3,}/g, '\\n\\n')
      .trim();
    return text.slice(Math.max(0, text.length - 6000));
  }

  function isFormInputElement(input) {
    return input.tagName === 'TEXTAREA' || input.tagName === 'INPUT';
  }

  function setNativeValue(input, text) {
    // Trigger React's onChange by going through the native value setter.
    const proto = input.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
    if (setter) {
      setter.call(input, text);
    } else {
      input.value = text;
    }
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }

  function selectAllInEditable(input) {
    const range = document.createRange();
    range.selectNodeContents(input);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
  }

  function setInputText(text) {
    const input = inputElement();
    if (!input) return false;
    input.focus();
    if (isFormInputElement(input)) {
      setNativeValue(input, text);
      return true;
    }
    // contenteditable / ProseMirror: select all, then insert via execCommand so
    // the editor's own input handling observes the change.
    selectAllInEditable(input);
    let inserted = false;
    try { inserted = document.execCommand('insertText', false, text); } catch {}
    if (!inserted || (input.innerText || '').trim() !== text.trim()) {
      input.textContent = text;
      input.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        inputType: 'insertText',
        data: text
      }));
    }
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
    const existingStyle = document.getElementById('codex-optimize-input-style');
    if (existingStyle?.dataset.promptCocoPilotVersion === version) return;
    existingStyle?.remove();
    const style = document.createElement('style');
    style.id = 'codex-optimize-input-style';
    style.dataset.promptCocoPilotVersion = version;
    style.textContent = \`
      .codex-optimize-input-button {
        position: absolute;
        right: 10px;
        bottom: 8px;
        z-index: 2147483647;
        height: 24px;
        min-width: 30px;
        border: 0;
        border-radius: 6px;
        background: rgba(20, 20, 20, 0.82);
        color: #fff;
        font: 600 12px/24px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        cursor: pointer;
        padding: 0 8px;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3);
      }
      .codex-optimize-input-button:hover { background: rgba(0, 0, 0, 0.92); }
      .codex-optimize-input-button[data-busy="true"] { cursor: wait; opacity: 0.6; }
    \`;
    document.head.appendChild(style);
  }

  window.__promptCocoPilotCodexApply = (requestId, payload) => {
    const button = document.querySelector('.codex-optimize-input-button');
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

    const requestId = ++window.__promptCocoPilotCodexRequestSeq;
    button.dataset.busy = 'true';
    button.textContent = '优化中';
    try {
      const request = {
        type: 'optimize-request',
        requestId,
        draft,
        context: 'Visible Codex context:\\n' + visibleContext(),
        beforeLength: draft.length,
        capturedAt: Date.now()
      };
      window.__promptCocoPilotCodexPendingRequests.push(request);
      diagnostic('optimize-request', { requestId, beforeLength: draft.length });
    } catch (error) {
      diagnostic('optimize-error', { message: String(error?.message || error) });
      button.textContent = '服务未开';
      setTimeout(() => (button.textContent = '优化输入'), 1800);
    }
  }

  function ensureOptimizeButton() {
    ensureOptimizeStyles();
    const input = inputElement();
    if (!input) return;
    const host = input.parentElement;
    if (!host) return;

    host.querySelectorAll('.codex-optimize-input-button').forEach((element) => {
      if (element.dataset.promptCocoPilotVersion !== version) element.remove();
    });
    const existing = host.querySelector('.codex-optimize-input-button');
    if (existing?.dataset.promptCocoPilotVersion === version) return;
    existing?.remove();

    // Anchor the absolutely-positioned button inside the composer wrapper.
    if (getComputedStyle(host).position === 'static') {
      host.style.position = 'relative';
    }

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'codex-optimize-input-button';
    button.dataset.promptCocoPilotVersion = version;
    button.setAttribute('aria-label', '优化输入');
    button.title = '优化输入';
    button.textContent = '优化输入';
    button.addEventListener('click', (event) => {
      event.preventDefault();
      event.stopPropagation();
      void optimize(button);
    });
    host.appendChild(button);
  }

  const timer = setInterval(ensureOptimizeButton, 1000);
  abortController.signal.addEventListener('abort', () => {
    clearInterval(timer);
    document.querySelectorAll('.codex-optimize-input-button').forEach((element) => element.remove());
  });
  ensureOptimizeButton();
  diagnostic('installed');
})();
`;
}
