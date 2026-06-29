#!/usr/bin/env python3
"""Launch the pywebview floating enhance window.

Must be run with a Python that has pywebview installed (Homebrew python3.12):
  /opt/homebrew/bin/python3.12 claude-ui/bin/claude-webview.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src'))

from floating_webview import run
run()
