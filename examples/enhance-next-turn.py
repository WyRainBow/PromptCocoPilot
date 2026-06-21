#!/usr/bin/env python3
"""Package a follow-up prompt with prior context, then optionally enhance it.

Example:
  python3 examples/enhance-next-turn.py examples/next-turn-context.json --print-context
  python3 examples/enhance-next-turn.py examples/next-turn-context.json --enhance
"""

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "mcp-server"))

from context_packaging import assemble_enhancement_context, prompt_context_from_dict
from enhance import enhance_prompt


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Enhance a next-turn prompt with conversation and code context."
    )
    parser.add_argument("input_json", help="JSON file containing draft plus context fields.")
    parser.add_argument(
        "--print-context",
        action="store_true",
        help="Print the packaged context without calling the enhancer.",
    )
    parser.add_argument(
        "--enhance",
        action="store_true",
        help="Call enhance_prompt with the packaged context.",
    )
    args = parser.parse_args()

    payload = json.loads(Path(args.input_json).read_text())
    draft = payload.get("draft", "")
    packaged_context = assemble_enhancement_context(
        draft,
        prompt_context_from_dict(payload),
    )

    if args.print_context or not args.enhance:
        print(packaged_context)

    if args.enhance:
        print("\n--- Enhanced Prompt ---")
        print(enhance_prompt(draft, packaged_context))


if __name__ == "__main__":
    main()
