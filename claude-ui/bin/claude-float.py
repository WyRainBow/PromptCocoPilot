#!/usr/bin/env python3
"""Entry point for the Claude Code floating enhance button.

Usage:
  python3 claude-ui/bin/claude-float.py            # launch floating window
  python3 claude-ui/bin/claude-float.py session    # print current session info
"""

import os
import sys

# Make sure src/ is on the path whether run from repo root or claude-ui/
_here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_here, '..', 'src'))

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'session':
        from session_reader import get_current_context, get_session_summary
        print(get_session_summary())
        conv, cwd = get_current_context(max_messages=6)
        print(f'\ncwd: {cwd}')
        print(f'messages: {len(conv)}')
        for m in conv:
            preview = m['content'][:80].replace('\n', ' ')
            print(f'  [{m["role"]}] {preview}')
        sys.exit(0)

    from floating_window import FloatingButton
    FloatingButton().run()
