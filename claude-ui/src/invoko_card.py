"""Invoko-inspired minimal prompt enhancer card.

Hold Fn (or configurable hotkey) → show floating card → enhance → apply to current input.
No separate window, just a context-aware card overlay.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from session_reader import get_current_context

ENHANCE_URL = os.environ.get('ENHANCE_ENDPOINT', 'http://127.0.0.1:8765/enhance')
_HERE  = os.path.dirname(os.path.abspath(__file__))
_SERVER_PY = os.path.normpath(os.path.join(_HERE, '..', '..', 'mcp-server', 'http_server.py'))


# ── HTML / CSS / JS ─────────────────────────────────────────────────────────────

HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:       rgba(20, 20, 20, 0.95);
  --border:   rgba(255, 255, 255, 0.1);
  --accent:   #6366f1;
  --green:    #22c55e;
  --text:     #e2e8f0;
  --muted:    #71717a;
  --result:   #86efac;
}

html, body { height: 100%; }

body {
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  background: transparent;
  color: var(--text);
  font-size: 13px;
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  -webkit-app-region: drag;
}

button, textarea, .no-drag { -webkit-app-region: no-drag; }

/* ── card design ── */
.card {
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.4);
  backdrop-filter: blur(20px);
  min-width: 280px;
  max-width: 360px;
}

.header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 10px; padding-bottom: 8px;
  border-bottom: 1px solid var(--border);
}

.title { font-weight: 600; font-size: 13px; display: flex; align-items: center; gap: 6px; }
.badge { font-size: 10px; padding: 2px 6px; border-radius: 10px; background: var(--border); color: var(--muted); }
.close { background: none; border: none; font-size: 16px; color: var(--muted); cursor: pointer; padding: 0 4px; }
.close:hover { color: var(--text); }

.sess-info { font-size: 11px; color: var(--muted); margin-bottom: 8px; display: flex; align-items: center; gap: 5px; }

textarea {
  -webkit-user-select: text; user-select: text;
  width: 100%; background: rgba(0,0,0,0.3);
  color: var(--text); border: 1px solid var(--border);
  border-radius: 8px; padding: 8px 10px;
  font-size: 12px; font-family: inherit;
  resize: none; outline: none; line-height: 1.4;
  margin-bottom: 8px;
}
textarea:focus { border-color: var(--accent); }
#draft  { min-height: 48px; }
#result { min-height: 56px; color: var(--result); }

.btn-row { display: flex; gap: 6px; }
.btn {
  flex: 1; padding: 8px; border-radius: 8px;
  border: none; cursor: pointer; font-size: 12px; font-weight: 500;
  transition: all 0.15s;
}
.btn:disabled { opacity: .4; cursor: not-allowed; }
.btn-primary   { background: var(--accent); color: #fff; }
.btn-primary:hover:not(:disabled) { background: #4f52d9; }
.btn-secondary { background: rgba(255,255,255,0.05); color: #cbd5e1; border: 1px solid var(--border); }
.btn-secondary:hover:not(:disabled) { background: rgba(255,255,255,0.08); }

#status { font-size: 10px; color: var(--muted); min-height: 14px; text-align: center; }
#status.err { color: var(--red); }
#status.ok  { color: var(--green); }
</style>
</head>
<body>

<div class="card">
  <div class="header">
    <div class="title">
      <span>✨</span>
      <span>Enhance</span>
    </div>
    <button class="close" onclick="closeCard()">×</button>
  </div>

  <div class="sess-info" id="sess-info">
    <span id="sess-label">检测会话中…</span>
  </div>

  <textarea id="draft" placeholder="输入你想发送给 Claude 的草稿…"></textarea>

  <div class="btn-row">
    <button class="btn btn-primary" id="enhance-btn" onclick="enhance()">▶</button>
    <button class="btn btn-secondary" id="apply-btn" disabled onclick="applyAndClose()">应用并关闭</button>
  </div>

  <div id="status"></div>

  <textarea id="result" readonly placeholder="增强结果…"></textarea>
</div>

<script>
let _enhanced = '';

const $ = id => document.getElementById(id);

function closeCard() {
  window.pywebview.api.close_window();
}

function setStatus(msg, cls = '') {
  $('status').textContent = msg;
  $('status').className = cls;
}

async function enhance() {
  const draft = $('draft').value.trim();
  if (!draft) { setStatus('请先输入草稿', 'err'); return; }
  const btn = $('enhance-btn');
  btn.disabled = true; btn.textContent = '…';
  setStatus('');
  try {
    const r = await window.pywebview.api.enhance(draft);
    if (r.error) {
      setStatus('⚠ ' + r.error, 'err');
    } else {
      _enhanced = r.enhanced;
      $('result').value = _enhanced;
      $('apply-btn').disabled = false;
      setStatus('✓ 增强完成', 'ok');
    }
  } catch(e) { setStatus('错误: ' + e, 'err'); }
  btn.disabled = false; btn.textContent = '▶';
}

function applyAndClose() {
  window.pywebview.api.apply_to_clipboard(_enhanced);
  closeCard();
}

async function init() {
  const info = await window.pywebview.api.get_session();
  $('sess-label').textContent = info.label;

  // Auto-seed draft from selection or clipboard
  const draft = await window.pywebview.api.get_selection_or_clipboard();
  if (draft && draft.trim() && draft.length < 400)
    $('draft').value = draft.trim();
  $('draft').focus();
  $('draft').select();
}

window.addEventListener('pywebviewready', init);
</script>
</body>
</html>
"""


# ── Python API ────────────────────────────────────────────────────────────────

class Api:
    def __init__(self):
        self._conversation: list[dict] = []
        self._window = None

    def set_window(self, window) -> None:
        self._window = window

    def close_window(self) -> None:
        if self._window:
            self._window.destroy()

    def enhance(self, draft: str) -> dict:
        payload: dict = {'draft': draft}
        if self._conversation:
            payload['conversation'] = self._conversation
        try:
            data = json.dumps(payload, ensure_ascii=False).encode()
            req = urllib.request.Request(
                ENHANCE_URL, data=data,
                headers={'Content-Type': 'application/json; charset=utf-8'},
                method='POST',
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = json.loads(resp.read().decode())
            return {'enhanced': body.get('enhanced', '')}
        except urllib.error.URLError:
            return {'error': '增强服务未运行'}
        except Exception as exc:
            return {'error': str(exc)}

    def get_session(self) -> dict:
        conv, cwd = get_current_context()
        self._conversation = conv
        name = cwd.split('/')[-1] if cwd else '未检测到会话'
        return {'label': f'📍 {name}  ·  {len(conv)} 条对话', 'cwd': cwd}

    def get_selection_or_clipboard(self) -> str:
        """Try to get selected text first, then fall back to clipboard."""
        # Try macOS selection (pbcopy is for clipboard, selection is system-wide)
        try:
            result = subprocess.run(['pbpaste'], capture_output=True, text=True)
            clip = result.stdout[:400]
            if clip and clip.strip():
                return clip
        except Exception:
            pass
        return ''

    def apply_to_clipboard(self, text: str) -> None:
        subprocess.run(['pbcopy'], input=text.encode(), check=False)


# ── Server auto-start ───────────────────────────────────────────────────────────

def _ensure_server_ready(api: Api, timeout: float = 5.0):
    if api.server_alive():
        return
    subprocess.Popen(
        [sys.executable, _SERVER_PY],
        cwd=os.path.dirname(_SERVER_PY),
        stdout=subprocess.DEVNULL,
        stderr=open('/tmp/coco-server.log', 'w'),
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        time.sleep(0.4)
        if api.server_alive():
            return


# ── Entry ─────────────────────────────────────────────────────────────────────

def run():
    import webview

    api = Api()
    _ensure_server_ready(api)

    # Center card on screen (no dock, just floating)
    window = webview.create_window(
        '✨ Enhance',
        html=HTML,
        js_api=api,
        width=320,
        height=280,
        resizable=False,
        on_top=True,
        background_color='#000000',  # black with transparency
        frameless=True,
    )
    api.set_window(window)
    webview.start(debug=False)


if __name__ == '__main__':
    run()
