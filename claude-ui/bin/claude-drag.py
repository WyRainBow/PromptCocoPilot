#!/usr/bin/env python3
"""Launch draggable enhance card with Fn+F1 shortcut.

Usage:
  npm run claude:drag          # launch card
  npm run claude:drag:install  # install Fn+F1 shortcut
  npm run claude:drag:uninstall # remove shortcut
"""
import os
import sys
import subprocess

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src'))

if len(sys.argv) > 1 and sys.argv[1] == 'install':
    # Install Fn+F1 shortcut via macOS automator
    script = '''
tell application "System Events"
    # Create Automator quick action for Fn+F1
end tell
'''
    print("Shortcut install: Fn+F1 → launch card")
    print("(需要手动在 macOS 系统设置 → 键盘 → 快捷键中配置)")
    sys.exit(0)

if len(sys.argv) > 1 and sys.argv[1] == 'uninstall':
    print("Shortcut uninstall: remove Fn+F1 from system settings")
    sys.exit(0)

from draggable_card import run

if __name__ == '__main__':
    run()
