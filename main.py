#!/usr/bin/env python3
"""
Matrix — AI agent powered by Ollama + gemma4.
"""

import os
import sys
from pathlib import Path

# When launched via `curl | sh` the shell's stdin is the pipe, not the
# terminal. Re-open /dev/tty so the user can actually type.
if not sys.stdin.isatty():
    try:
        sys.stdin = open("/dev/tty", "r")
    except OSError:
        pass  # No terminal available (CI, etc.) — let it fail naturally

# Ensure the project root is on sys.path
sys.path.insert(0, str(Path(__file__).parent))

from agent import tools, loop

MODEL = os.environ.get("MATRIX_MODEL", "gemma4:latest")
TOOLS_DIR = str(Path(__file__).parent / "tools")

BANNER = """
╔══════════════════════════════════╗
║          M A T R I X             ║
║     AI Agent  •  Ollama          ║
╚══════════════════════════════════╝
"""


def print_tools() -> None:
    names = list(tools.registry.keys())
    if names:
        print(f"  Tools loaded: {', '.join(names)}")
    else:
        print("  No tools loaded.")


def main() -> None:
    print(BANNER)
    print(f"  Model : {MODEL}")

    tools.load_all(TOOLS_DIR)
    print_tools()
    print()
    print("  Commands: 'reload' — rescan tools | 'quit' / Ctrl-C — exit")
    print("─" * 40)

    history = [{"role": "system", "content": loop.SYSTEM_PROMPT}]

    while True:
        try:
            user_input = input("\nYou: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            break

        if not user_input:
            continue

        if user_input.lower() in ("exit", "quit", "q"):
            print("Goodbye.")
            break

        if user_input.lower() == "reload":
            tools.load_all(TOOLS_DIR)
            print_tools()
            continue

        try:
            response = loop.run_turn(user_input, history, MODEL)
            print(f"\nMatrix: {response}")
        except Exception as e:
            print(f"\n[error] {e}")


if __name__ == "__main__":
    main()
