"""Always-on-top floating "优化输入" button for Claude Code sessions."""

import json
import os
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import scrolledtext
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(__file__))
from session_reader import get_current_context, get_session_summary

ENHANCE_URL = os.environ.get('ENHANCE_ENDPOINT', 'http://127.0.0.1:8765/enhance')

# Path to http_server.py relative to this file: ../../mcp-server/http_server.py
_HERE = os.path.dirname(os.path.abspath(__file__))
_SERVER_PY = os.path.normpath(os.path.join(_HERE, '..', '..', 'mcp-server', 'http_server.py'))


def _server_alive() -> bool:
    try:
        req = urllib.request.Request(ENHANCE_URL, data=b'{}',
                                     headers={'Content-Type': 'application/json'}, method='POST')
        urllib.request.urlopen(req, timeout=1)
        return True
    except Exception:
        return False


def _start_server():
    """Launch http_server.py as a background subprocess if not already running."""
    if _server_alive():
        return
    subprocess.Popen(
        [sys.executable, _SERVER_PY],
        cwd=os.path.dirname(_SERVER_PY),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

# ── colours ──────────────────────────────────────────────────────────────────
BG        = '#16213e'
CARD_BG   = '#0d1b2a'
BTN_BG    = '#1a4a7a'
BTN_HOV   = '#2260a0'
ACCENT    = '#e94560'
SUCCESS   = '#4caf50'
FG        = '#e0e0e0'
FG_DIM    = '#888899'
FG_GREEN  = '#7fff7f'

# ── sizes ────────────────────────────────────────────────────────────────────
PILL_W, PILL_H     = 148, 34
EXPANDED_W         = 420
EXPANDED_H         = 400
MARGIN             = 20   # px from screen edge


class _ScrolledText(scrolledtext.ScrolledText):
    """ScrolledText with a dark Aqua scrollbar aesthetic."""
    def __init__(self, parent, **kw):
        defaults = dict(
            bg=CARD_BG, fg=FG, insertbackground=FG,
            font=('Helvetica', 11), relief='flat',
            padx=6, pady=6, wrap=tk.WORD,
            selectbackground='#2d4a7a', selectforeground=FG,
            borderwidth=0, highlightthickness=1,
            highlightbackground='#2a3a5a', highlightcolor='#4a6a9a',
        )
        defaults.update(kw)
        super().__init__(parent, **defaults)


class FloatingButton:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title('✨ 优化输入')
        self.root.attributes('-topmost', True)
        self.root.configure(bg=BG)
        self.root.resizable(False, False)

        self.expanded = False
        self._conversation: list[dict] = []
        self._session_cwd: str = ''
        self._result_text: str = ''
        self._drag_ox = self._drag_oy = 0
        self._pill_btn = None

        # Position: bottom-right
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        self._px = sw - PILL_W - MARGIN
        self._py = sh - PILL_H - 120
        self.root.geometry(f'{PILL_W}x{PILL_H}+{self._px}+{self._py}')
        self.root.lift()
        self.root.focus_force()
        # macOS: tkinter windows don't auto-activate; force it via osascript
        self.root.after(200, self._macos_activate)

        # Keyboard: Escape collapses; Cmd+Q quits
        self.root.bind('<Escape>', lambda _: self._collapse())
        self.root.bind('<Command-q>', lambda _: self.root.destroy())

        self._build_pill()
        self._async_refresh()           # load session in background
        threading.Thread(target=_start_server, daemon=True).start()  # auto-start enhance server

    # ── pill (collapsed) ─────────────────────────────────────────────────────

    def _build_pill(self):
        self._clear()
        f = tk.Frame(self.root, bg=BG, padx=3, pady=3)
        f.pack(fill=tk.BOTH, expand=True)

        self._pill_btn = tk.Button(
            f, text='✨ 优化输入',
            bg=BTN_BG, fg=FG,
            activebackground=BTN_HOV, activeforeground=FG,
            font=('Helvetica', 12, 'bold'),
            relief='flat', bd=0, cursor='hand2',
            command=self._expand,
        )
        self._pill_btn.pack(fill=tk.BOTH, expand=True)
        self._check_server_status()

        self._bind_drag(f, self._pill_btn)

    # ── expanded panel ────────────────────────────────────────────────────────

    def _build_expanded(self):
        self._clear()
        outer = tk.Frame(self.root, bg=BG, padx=10, pady=10)
        outer.pack(fill=tk.BOTH, expand=True)

        # ── header
        hdr = tk.Frame(outer, bg=BG)
        hdr.pack(fill=tk.X, pady=(0, 6))

        title = tk.Label(hdr, text='✨ 优化输入', bg=BG, fg=FG,
                         font=('Helvetica', 13, 'bold'))
        title.pack(side=tk.LEFT)

        self._bind_drag(hdr, title)

        # ── session label
        self._sess_var = tk.StringVar(value=self._session_label())
        sess_row = tk.Frame(outer, bg=BG)
        sess_row.pack(fill=tk.X, pady=(0, 4))

        tk.Label(sess_row, textvariable=self._sess_var,
                 bg=BG, fg=FG_DIM, font=('Helvetica', 10)).pack(side=tk.LEFT)

        tk.Button(sess_row, text='↻', bg=BG, fg=FG_DIM,
                  activebackground=BG, activeforeground=FG,
                  font=('Helvetica', 11), relief='flat', bd=0,
                  cursor='hand2', command=self._refresh_clicked).pack(side=tk.LEFT, padx=(4, 0))

        # ── draft input
        tk.Label(outer, text='草稿', bg=BG, fg=FG_DIM,
                 font=('Helvetica', 10)).pack(anchor=tk.W, pady=(2, 1))

        self._draft = _ScrolledText(outer, height=4)
        self._draft.pack(fill=tk.X, pady=(0, 6))

        # Seed with clipboard if it looks like text
        try:
            clip = self.root.clipboard_get().strip()
            if clip and len(clip) < 2000:
                self._draft.insert('1.0', clip)
        except Exception:
            pass

        # ── enhance button
        self._enhance_btn = tk.Button(
            outer, text='▶  增强',
            bg=ACCENT, fg='white',
            activebackground='#c0304e', activeforeground='white',
            font=('Helvetica', 12, 'bold'),
            relief='flat', bd=0, cursor='hand2',
            command=self._do_enhance,
        )
        self._enhance_btn.pack(fill=tk.X, pady=(0, 4))

        # ── status
        self._status_var = tk.StringVar(value='')
        tk.Label(outer, textvariable=self._status_var,
                 bg=BG, fg=FG_DIM, font=('Helvetica', 10)).pack(anchor=tk.W)

        # ── result
        tk.Label(outer, text='增强结果', bg=BG, fg=FG_DIM,
                 font=('Helvetica', 10)).pack(anchor=tk.W, pady=(6, 1))

        self._result = _ScrolledText(outer, height=6, fg=FG_GREEN, state='disabled')
        self._result.pack(fill=tk.BOTH, expand=True, pady=(0, 6))

        # ── copy button
        self._copy_btn = tk.Button(
            outer, text='复制结果',
            bg=BTN_BG, fg=FG,
            activebackground=BTN_HOV, activeforeground=FG,
            font=('Helvetica', 11),
            relief='flat', bd=0, cursor='hand2',
            state='disabled',
            command=self._copy,
        )
        self._copy_btn.pack(fill=tk.X)

    # ── expand / collapse ─────────────────────────────────────────────────────

    def _expand(self):
        self.expanded = True
        x = self.root.winfo_x()
        y = max(MARGIN, self.root.winfo_y() - (EXPANDED_H - PILL_H))
        self.root.geometry(f'{EXPANDED_W}x{EXPANDED_H}+{x}+{y}')
        self._build_expanded()

    def _collapse(self):
        self.expanded = False
        x = self.root.winfo_x()
        y = self.root.winfo_y() + (EXPANDED_H - PILL_H)
        self.root.geometry(f'{PILL_W}x{PILL_H}+{x}+{y}')
        self._build_pill()

    # ── enhance logic ─────────────────────────────────────────────────────────

    def _do_enhance(self):
        draft = self._draft.get('1.0', tk.END).strip()
        if not draft:
            self._status_var.set('请先输入草稿')
            return

        self._enhance_btn.config(state='disabled', text='增强中…')
        self._status_var.set('正在调用增强服务…')

        def worker():
            try:
                payload: dict = {'draft': draft}
                if self._conversation:
                    payload['conversation'] = self._conversation
                data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
                req = urllib.request.Request(
                    ENHANCE_URL, data=data,
                    headers={'Content-Type': 'application/json; charset=utf-8'},
                    method='POST',
                )
                with urllib.request.urlopen(req, timeout=30) as resp:
                    body = json.loads(resp.read().decode('utf-8'))
                enhanced = body.get('enhanced', '')
                self.root.after(0, lambda: self._show_result(enhanced))
            except urllib.error.URLError:
                self.root.after(0, lambda: self._show_error(
                    '⚠ 增强服务未运行  →  请先启动 http_server.py'))
            except Exception as exc:
                self.root.after(0, lambda: self._show_error(f'错误: {exc}'))

        threading.Thread(target=worker, daemon=True).start()

    def _show_result(self, text: str):
        self._result_text = text
        self._result.config(state='normal')
        self._result.delete('1.0', tk.END)
        self._result.insert('1.0', text)
        self._result.config(state='disabled')
        self._copy_btn.config(state='normal')
        self._enhance_btn.config(state='normal', text='▶  增强')
        self._status_var.set('✓ 完成')

    def _show_error(self, msg: str):
        self._enhance_btn.config(state='normal', text='▶  增强')
        self._status_var.set(msg)

    def _copy(self):
        self.root.clipboard_clear()
        self.root.clipboard_append(self._result_text)
        self._copy_btn.config(text='已复制 ✓')
        self.root.after(1500, lambda: self._copy_btn.config(text='复制结果'))

    # ── session refresh ───────────────────────────────────────────────────────

    def _async_refresh(self):
        def worker():
            conv, cwd = get_current_context()
            self._conversation = conv
            self._session_cwd = cwd
        threading.Thread(target=worker, daemon=True).start()

    def _refresh_clicked(self):
        self._sess_var.set('刷新中…')
        def worker():
            conv, cwd = get_current_context()
            self._conversation = conv
            self._session_cwd = cwd
            self.root.after(0, lambda: self._sess_var.set(self._session_label()))
        threading.Thread(target=worker, daemon=True).start()

    def _session_label(self) -> str:
        if not self._session_cwd:
            return '未检测到活跃会话'
        name = self._session_cwd.split('/')[-1]
        n = len(self._conversation)
        return f'📍 {name}  ·  {n} 条对话'

    # ── helpers ───────────────────────────────────────────────────────────────

    def _clear(self):
        for w in self.root.winfo_children():
            w.destroy()

    def _bind_drag(self, *widgets):
        for w in widgets:
            w.bind('<ButtonPress-1>', self._drag_start)
            w.bind('<B1-Motion>', self._drag_move)

    def _drag_start(self, evt):
        self._drag_ox = evt.x_root - self.root.winfo_x()
        self._drag_oy = evt.y_root - self.root.winfo_y()

    def _drag_move(self, evt):
        x = evt.x_root - self._drag_ox
        y = evt.y_root - self._drag_oy
        self.root.geometry(f'+{x}+{y}')

    def _macos_activate(self):
        subprocess.Popen(
            ['osascript', '-e', 'tell application "Python" to activate'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )

    def _check_server_status(self):
        """Update pill button label to reflect server readiness."""
        def worker():
            import time
            for _ in range(10):          # wait up to 5s for server to start
                time.sleep(0.5)
                if _server_alive():
                    self.root.after(0, lambda: self._pill_btn and
                                    self._pill_btn.config(text='✨ 优化输入 🟢'))
                    return
            self.root.after(0, lambda: self._pill_btn and
                            self._pill_btn.config(text='✨ 优化输入 🔴'))
        threading.Thread(target=worker, daemon=True).start()

    def run(self):
        self.root.mainloop()
