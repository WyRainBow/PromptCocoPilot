"""Floating "优化输入" window using pywebview (WKWebView on macOS).

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
from session_reader import get_current_context, _cwd_to_slug

ENHANCE_URL = os.environ.get('ENHANCE_ENDPOINT', 'http://127.0.0.1:8765/enhance')
_HERE  = os.path.dirname(os.path.abspath(__file__))
_SERVER_PY = os.path.normpath(os.path.join(_HERE, '..', '..', 'mcp-server', 'http_server.py'))


# ── HTML ──────────────────────────────────────────────────────────────────────

HTML = r"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:       #0f1117;
  --surface:  #1a1d27;
  --border:   #2a2d3a;
  --accent:   #6366f1;
  --accent-h: #4f52d9;
  --green:    #22c55e;
  --red:      #ef4444;
  --text:     #e2e8f0;
  --muted:    #64748b;
  --result:   #6ee7b7;
}

html, body { height: 100%; }

body {
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  background: var(--bg);
  color: var(--text);
  font-size: 13px;
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  /* allow native window drag from body background */
  -webkit-app-region: drag;
}

/* everything interactive must opt out of dragging */
button, textarea, .no-drag { -webkit-app-region: no-drag; }

/* ── top bar ── */
.bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px 8px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.bar-left  { display: flex; align-items: center; gap: 7px; }
.bar-title { font-weight: 700; font-size: 13px; color: var(--text); }
.pill {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 1px 7px; border-radius: 20px; font-size: 11px;
  background: var(--surface); border: 1px solid var(--border);
  color: var(--muted);
}
.dot { width: 6px; height: 6px; border-radius: 50%; background: var(--muted); }
.dot.on  { background: var(--green); }
.dot.off { background: var(--red); }

.sess-row {
  display: flex; align-items: center; gap: 5px;
  padding: 5px 14px 0;
  font-size: 11px; color: var(--muted);
  flex-shrink: 0;
}
.sess-row select {
  background: var(--surface); color: var(--text);
  border: 1px solid var(--border); border-radius: 6px;
  padding: 2px 6px; font-size: 11px; cursor: pointer;
  outline: none; max-width: 140px;
}
.sess-row button {
  background: none; border: none; color: var(--muted);
  cursor: pointer; font-size: 13px; padding: 0 2px; line-height: 1;
}
.sess-row button:hover { color: var(--text); }

/* ── body ── */
.content {
  display: flex;
  flex-direction: column;
  flex: 1;
  padding: 10px 14px 12px;
  gap: 8px;
  overflow: hidden;
}

label { font-size: 11px; color: var(--muted); flex-shrink: 0; }

textarea {
  -webkit-user-select: text; user-select: text;
  width: 100%; background: var(--surface);
  color: var(--text); border: 1px solid var(--border);
  border-radius: 8px; padding: 8px 10px;
  font-size: 13px; font-family: inherit;
  resize: none; outline: none; line-height: 1.5;
  transition: border-color .15s;
}
textarea:focus { border-color: var(--accent); }
#draft  { flex: 1 1 0; min-height: 64px; }
#result { flex: 1.2 1 0; min-height: 72px; color: var(--result); }

.btn {
  width: 100%; padding: 9px; border-radius: 8px;
  border: none; cursor: pointer; font-size: 13px; font-weight: 600;
  transition: background .15s, opacity .15s;
  flex-shrink: 0;
}
.btn:disabled { opacity: .4; cursor: not-allowed; }
.btn-primary   { background: var(--accent); color: #fff; }
.btn-primary:hover:not(:disabled) { background: var(--accent-h); }
.btn-secondary { background: var(--surface); color: #cbd5e1; border: 1px solid var(--border); }
.btn-secondary:hover:not(:disabled) { background: #222535; }

#status {
  font-size: 11px; color: var(--muted);
  min-height: 15px; flex-shrink: 0;
  display: flex; align-items: center; gap: 5px;
}
#status.err { color: var(--red); }
#status.ok  { color: var(--green); }
</style>
</head>
<body>

<div class="bar">
  <div class="bar-left">
    <span class="bar-title">✨ 优化输入</span>
    <span class="pill no-drag">
      <span class="dot" id="srv-dot"></span>
      <span id="srv-label">连接中</span>
    </span>
  </div>
</div>

<div class="sess-row no-drag">
  <select id="sess-select" onchange="switchSession()">
    <option value="">加载中…</option>
  </select>
  <button onclick="refreshSessions()" title="刷新列表">↻</button>
  <span id="sess-label" style="display:none"></span>
</div>

<div class="content">
  <label>草稿</label>
  <textarea id="draft" placeholder="输入你想发送给 Claude 的草稿…"></textarea>

  <button class="btn btn-primary" id="enhance-btn" onclick="enhance()">▶ 增强</button>

  <div id="status"></div>

  <label>增强结果</label>
  <textarea id="result" readonly placeholder="增强结果会显示在这里…"></textarea>

  <button class="btn btn-secondary" id="copy-btn" disabled onclick="copyResult()">复制结果</button>
</div>

<script>
let _enhanced = '';

const $ = id => document.getElementById(id);

function setStatus(msg, cls = '') {
  $('status').textContent = msg;
  $('status').className = cls;
}

function setSrv(alive) {
  $('srv-dot').className   = 'dot ' + (alive ? 'on' : 'off');
  $('srv-label').textContent = alive ? '就绪' : '服务未运行';
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
    sessions.forEach((s, i) => {
      const opt = document.createElement('option');
      opt.value = s.cwd;
      const statusIcon = s.status === 'busy' ? '🔴' : '';
      opt.textContent = `${statusIcon}${s.name} · ${s.messages}条`;
      select.appendChild(opt);
    });
    // Restore selection if still available
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
    const info = await window.pywebview.api.select_session(cwd);
    $('sess-label').textContent = info.label;
  } catch(e) { console.error(e); }
}

async function copyResult() {
  await window.pywebview.api.copy_to_clipboard(_enhanced);
  $('copy-btn').textContent = '已复制 ✓';
  setTimeout(() => $('copy-btn').textContent = '复制结果', 1500);
}

async function init() {
  // Check server (already started in Python before window opened)
  for (let i = 0; i < 6; i++) {
    if (await checkServer()) break;
    await new Promise(r => setTimeout(r, 600));
  }

  // Load sessions list
  refreshSessions();

  // Auto-seed draft from clipboard
  const clip = await window.pywebview.api.get_clipboard();
  if (clip && clip.trim() && clip.length < 800)
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

    def list_sessions(self) -> list[dict]:
        """List all active Claude Code sessions for manual selection."""
        from session_reader import _load_all_sessions, _find_jsonl, _parse_conversation
        sessions = []
        for s in _load_all_sessions()[:10]:   # limit to 10 most recent
            cwd = s.get('cwd', '')
            session_id = s.get('sessionId', '')
            if not cwd or not session_id:
                continue
            slug = _cwd_to_slug(cwd)
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

    def server_alive(self) -> bool:
        try:
            # GET / is lighter than POST /enhance and always succeeds
            health_url = ENHANCE_URL.replace('/enhance', '/')
            urllib.request.urlopen(health_url, timeout=1)
            return True
        except Exception:
            return False

    def get_clipboard(self) -> str:
        try:
            return subprocess.run(['pbpaste'], capture_output=True, text=True).stdout[:800]
        except Exception:
            return ''

    def copy_to_clipboard(self, text: str) -> None:
        subprocess.run(['pbcopy'], input=text.encode(), check=False)


# ── Server auto-start (runs BEFORE webview opens) ────────────────────────────

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
    _ensure_server_ready(api)   # start server synchronously before window opens

    window = webview.create_window(
        '✨ 优化输入',
        html=HTML,
        js_api=api,
        width=400,
        height=460,
        on_top=True,
        resizable=True,
        min_size=(320, 360),
        background_color='#0f1117',
    )
    webview.start(debug=False)


if __name__ == '__main__':
    run()
