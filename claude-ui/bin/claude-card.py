#!/usr/bin/env python3
"""Launch Invoko-style minimal enhance card.

Hold Fn to show floating card → enhance → apply → close.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src'))

from invoko_card import run

if __name__ == '__main__':
    run()
