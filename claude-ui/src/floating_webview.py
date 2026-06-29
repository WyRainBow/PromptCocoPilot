"""Dynamic Island style floating "优化输入" panel (CodeIsland inspired).

Launch with: /opt/homebrew/bin/python3.12 claude-ui/bin/claude-webview.py
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

# Collapsed "notch" size — docks into the MacBook notch area (top-center, y=0).
# 200x36 sits flush under the menu bar / notch like CodeIsland / Invoko.
_NOTCH_W, _NOTCH_H = 200, 36


def _screen_size():
    """Return (width, height) of the main screen via pyobjc."""
    try:
        from AppKit import NSScreen
        f = NSScreen.mainScreen().frame()
        return int(f.size.width), int(f.size.height)
    except Exception:
        return 1512, 982  # fallback (MacBook Pro 14")


# ── HTML / CSS / JS ─────────────────────────────────────────────────────────────

HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:       #000000;
  --surface:  #0a0a0a;
  --border:   #1a1a1a;
  --accent:   #6366f1;
  --green:    #22c55e;
  --red:      #ef4444;
  --text:     #e2e8f0;
  --muted:    #71717a;
  --result:   #86efac;
}

html, body { height: 100%; }

body {
  font-family: 'SF Mono', 'Menlo', monospace;
  background: var(--bg);
  color: var(--text);
  font-size: 12px;
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  -webkit-app-region: drag;
}

button, textarea, select, .no-drag { -webkit-app-region: no-drag; }

/* ── island bar (collapsed state) ── */
.island-bar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 12px; height: 36px;
  background: linear-gradient(180deg, #1a1a1a 0%, #0a0a0a 100%);
  border: 1px solid #2a2a2a;
  border-radius: 20px;
  flex-shrink: 0;
  box-shadow: 0 4px 20px rgba(0,0,0,0.5);
}
.island-left { display: flex; align-items: center; gap: 8px; }
.island-icon { font-size: 14px; }
.island-text { font-size: 11px; color: var(--muted); white-space: nowrap; }
.island-right { display: flex; align-items: center; gap: 6px; }

.dot { width: 6px; height: 6px; border-radius: 50%; background: var(--muted); }
.dot.on  { background: var(--green); box-shadow: 0 0 6px var(--green); }
.dot.off { background: var(--red); }

.btn-xs {
  background: none; border: 1px solid #2a2a2a; border-radius: 12px;
  color: var(--muted); cursor: pointer; font-size: 10px;
  padding: 2px 6px; transition: all 0.15s;
}
.btn-xs:hover { border-color: var(--accent); color: var(--text); }

/* ── expanded content (hidden by default) ── */
.content-panel {
  display: none;
  padding: 10px 12px;
  gap: 8px;
  overflow: hidden;
  flex-direction: column;
}

.content-panel.show { display: flex; }

.row { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--muted); }
select {
  background: var(--surface); color: var(--text);
  border: 1px solid var(--border); border-radius: 8px;
  padding: 3px 8px; font-size: 11px; outline: none;
  flex: 1; cursor: pointer;
}

textarea {
  -webkit-user-select: text; user-select: text;
  width: 100%; background: var(--surface);
  color: var(--text); border: 1px solid var(--border);
  border-radius: 8px; padding: 7px 9px;
  font-size: 11px; font-family: inherit;
  resize: none; outline: none; line-height: 1.4;
}
textarea:focus { border-color: var(--accent); }
#draft  { min-height: 56px; }
#result { min-height: 64px; color: var(--result); }

.btn {
  width: 100%; padding: 7px; border-radius: 8px;
  border: none; cursor: pointer; font-size: 11px; font-weight: 600;
  transition: all 0.15s;
}
.btn:disabled { opacity: .4; cursor: not-allowed; }
.btn-primary   { background: var(--accent); color: #fff; }
.btn-primary:hover:not(:disabled) { background: #4f52d9; }
.btn-secondary { background: var(--surface); color: #cbd5e1; border: 1px solid var(--border); }
.btn-secondary:hover:not(:disabled) { background: #151515; }

#status { font-size: 10px; color: var(--muted); min-height: 13px; display: flex; align-items: center; gap: 4px; }
#status.err { color: var(--red); }
#status.ok  { color: var(--green); }

.field { position: relative; }
.field textarea { padding-right: 30px; }
.clear-btn {
  position: absolute; top: 5px; right: 5px;
  width: 20px; height: 20px; border-radius: 10px;
  background: rgba(255,255,255,0.08); border: none;
  color: var(--muted); cursor: pointer; font-size: 11px;
  display: flex; align-items: center; justify-content: center;
  z-index: 2; opacity: 0; transition: opacity .15s, background .15s;
}
.field:hover .clear-btn { opacity: 1; }
.clear-btn:hover { background: rgba(255,255,255,0.18); color: var(--text); }
</style>
</head>
<body>

<div class="island-bar" id="bar">
  <div class="island-left">
    <span class="island-icon">✨</span>
    <span class="island-text" id="bar-text">优化输入</span>
  </div>
  <div class="island-right">
    <span class="dot" id="srv-dot"></span>
    <button class="btn-xs" onclick="toggleExpand()">▼</button>
  </div>
</div>

<div class="content-panel" id="panel">
  <div class="row">
    <select id="sess-select" onchange="switchSession()">
      <option value="">加载中…</option>
    </select>
    <button class="btn-xs" onclick="refreshSessions()">↻</button>
  </div>

  <div class="field">
    <textarea id="draft" placeholder="输入你想发送给 Claude 的草稿…"></textarea>
    <button class="clear-btn" onclick="clearDraft()" title="清空草稿">✕</button>
  </div>

  <button class="btn btn-primary" id="enhance-btn" onclick="enhance()">▶ 增强</button>

  <div id="status"></div>

  <div class="field">
    <textarea id="result" readonly placeholder="增强结果会显示在这里…"></textarea>
    <button class="clear-btn" onclick="clearResult()" title="清空结果">✕</button>
  </div>

  <button class="btn btn-secondary" id="copy-btn" disabled onclick="copyResult()">复制结果</button>
</div>

<script>
let _enhanced = '', _expanded = false;

const $ = id => document.getElementById(id);

function setStatus(msg, cls = '') {
  $('status').textContent = msg;
  $('status').className = cls;
}

function setSrv(alive) {
  $('srv-dot').className = 'dot ' + (alive ? 'on' : 'off');
}

async function toggleExpand() {
  _expanded = !_expanded;
  await window.pywebview.api.toggle_expand(_expanded);
  $('panel').className = _expanded ? 'content-panel show' : 'content-panel';
  $('bar').querySelector('button').textContent = _expanded ? '▲' : '▼';
  if (_expanded) {
    $('bar-text').textContent = $('sess-select').value.split('/').pop() || '优化输入';
  } else {
    $('bar-text').textContent = '优化输入';
  }
}

async function checkServer() {
  const ok = await window.pywebview.api.server_alive();
  setSrv(ok);
  return ok;
}

async function enhance() {
  const draft = $('draft').value.trim();
  if (!draft) { setStatus('请先输入草稿', 'err'); return; }
  const btn = $('enhance-btn');
  btn.disabled = true; btn.textContent = '增强中…';
  setStatus('');
  try {
    const r = await window.pywebview.api.enhance(draft);
    if (r.error) {
      setStatus('⚠ ' + r.error, 'err');
    } else {
      _enhanced = r.enhanced;
      $('result').value = _enhanced;
      $('copy-btn').disabled = false;
      setStatus('✓ 完成', 'ok');
    }
  } catch(e) { setStatus('错误: ' + e, 'err'); }
  btn.disabled = false; btn.textContent = '▶ 增强';
}

async function refreshSessions() {
  const select = $('sess-select');
  const current = select.value;
  select.innerHTML = '<option value="">加载中…</option>';
  try {
    const sessions = await window.pywebview.api.list_sessions();
    if (sessions.length === 0) {
      select.innerHTML = '<option value="">无活跃会话</option>';
      return;
    }
    select.innerHTML = '';
    sessions.forEach(s => {
      const opt = document.createElement('option');
      opt.value = s.cwd;
      opt.textContent = `${s.name} · ${s.messages}`;
      select.appendChild(opt);
    });
    if (current && sessions.find(s => s.cwd === current)) {
      select.value = current;
    } else if (sessions.length > 0) {
      select.value = sessions[0].cwd;
      await switchSession();
    }
  } catch(e) { console.error(e); }
}

async function switchSession() {
  const cwd = $('sess-select').value;
  if (!cwd) return;
  try {
    await window.pywebview.api.select_session(cwd);
    if (_expanded) {
      $('bar-text').textContent = cwd.split('/').pop();
    }
  } catch(e) { console.error(e); }
}

function clearDraft() {
  $('draft').value = '';
  $('draft').focus();
}

function clearResult() {
  $('result').value = '';
  _enhanced = '';
  $('copy-btn').disabled = true;
  const s = $('status'); if (s) { s.textContent = ''; s.className = ''; }
}

async function copyResult() {
  await window.pywebview.api.copy_to_clipboard(_enhanced);
  $('copy-btn').textContent = '已复制 ✓';
  setTimeout(() => $('copy-btn').textContent = '复制结果', 1500);
}

async function init() {
  for (let i = 0; i < 6; i++) {
    if (await checkServer()) break;
    await new Promise(r => setTimeout(r, 600));
  }
  refreshSessions();
  const clip = await window.pywebview.api.get_clipboard();
  if (clip && clip.trim() && clip.length < 600)
    $('draft').value = clip.trim();
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

    def toggle_expand(self, expanded: bool) -> None:
        """Resize + reposition. Collapsed docks into the notch (top-center)."""
        if not self._window:
            return
        sw, _sh = _screen_size()
        if expanded:
            w, h = 380, 300
            self._window.resize(w, h)
            self._window.move((sw - w) // 2, 0)
        else:
            # Collapse back into the notch area (top-center, flush with top)
            self._window.resize(_NOTCH_W, _NOTCH_H)
            self._window.move((sw - _NOTCH_W) // 2, 0)

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

    def server_alive(self) -> bool:
        try:
            health_url = ENHANCE_URL.replace('/enhance', '/')
            urllib.request.urlopen(health_url, timeout=1)
            return True
        except Exception:
            return False

    def get_clipboard(self) -> str:
        try:
            return subprocess.run(['pbpaste'], capture_output=True, text=True).stdout[:600]
        except Exception:
            return ''

    def copy_to_clipboard(self, text: str) -> None:
        subprocess.run(['pbcopy'], input=text.encode(), check=False)

    def list_sessions(self) -> list[dict]:
        """List all active Claude Code sessions for manual selection."""
        from session_reader import _load_all_sessions, _find_jsonl, _parse_conversation
        sessions = []
        for s in _load_all_sessions()[:10]:
            cwd = s.get('cwd', '')
            session_id = s.get('sessionId', '')
            if not cwd or not session_id:
                continue
            jsonl_path = _find_jsonl(s)
            if not jsonl_path:
                continue
            conv = _parse_conversation(jsonl_path, 12)
            name = cwd.split('/')[-1] if cwd else '未知项目'
            status = s.get('status', '')
            sessions.append({
                'cwd': cwd,
                'name': name,
                'status': status,
                'messages': len(conv),
                'id': session_id,
            })
        return sessions

    def select_session(self, cwd: str) -> dict:
        """Load conversation for a specific session by cwd."""
        from session_reader import _find_jsonl, _parse_conversation, _load_all_sessions
        for s in _load_all_sessions():
            if s.get('cwd') == cwd:
                jsonl_path = _find_jsonl(s)
                if jsonl_path:
                    conv = _parse_conversation(jsonl_path, 12)
                    self._conversation = conv
                    name = cwd.split('/')[-1] if cwd else '未知项目'
                    return {'label': f'📍 {name}  ·  {len(conv)} 条对话', 'cwd': cwd}
        return {'label': '未找到会话', 'cwd': ''}


# ── Server auto-start ───────────────────────────────────────────────────────────

def _ensure_server_ready(api: Api, timeout: float = 5.0):
    """Start http_server.py if not alive, then wait until it responds."""
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

    sw, _sh = _screen_size()
    window = webview.create_window(
        '✨ 优化输入',
        html=HTML,
        js_api=api,
        width=_NOTCH_W,
        height=_NOTCH_H,        # collapsed: docked into notch
        x=(sw - _NOTCH_W) // 2, # centered horizontally
        y=0,                    # flush with top (notch / menu bar)
        resizable=False,
        on_top=True,
        background_color='#000000',
        frameless=True,
    )
    api.set_window(window)
    webview.start(debug=False)


if __name__ == '__main__':
    run()
