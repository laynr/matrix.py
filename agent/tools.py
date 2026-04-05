"""
Tool registry and dynamic loader for Matrix.

Each tool is a Python file in the tools/ directory exposing:
  TOOL_DEFINITION  — Ollama function-calling schema dict
  execute(params: dict) -> str  — the implementation
"""

import importlib.util
import os
from pathlib import Path
from typing import Optional

registry = {}

_TOOLS_DIR = Path(__file__).parent.parent / "tools"


def load_tool(path: str) -> bool:
    """Load a single tool file into the registry. Returns True on success."""
    p = Path(path)
    if not p.exists():
        print(f"[tools] File not found: {path}")
        return False

    try:
        spec = importlib.util.spec_from_file_location(p.stem, p)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as e:
        print(f"[tools] Failed to load {p.name}: {e}")
        return False

    if not hasattr(module, "TOOL_DEFINITION") or not hasattr(module, "execute"):
        print(f"[tools] Skipping {p.name}: missing TOOL_DEFINITION or execute()")
        return False

    name = module.TOOL_DEFINITION.get("function", {}).get("name", p.stem)
    registry[name] = {
        "definition": module.TOOL_DEFINITION,
        "execute": module.execute,
        "path": str(p.resolve()),
    }
    return True


def load_all(tools_dir: Optional[str] = None) -> None:
    """Load all *.py files from the tools directory (skips __init__.py)."""
    directory = Path(tools_dir) if tools_dir else _TOOLS_DIR
    registry.clear()
    for tool_file in sorted(directory.glob("*.py")):
        if tool_file.name.startswith("_"):
            continue
        load_tool(str(tool_file))


def get_definitions() -> list:
    """Return tool definitions suitable for ollama tools= parameter."""
    return [entry["definition"] for entry in registry.values()]


def dispatch(name: str, params: dict) -> str:
    """Execute a tool by name. Returns error string on failure instead of raising."""
    if name not in registry:
        return f"Error: unknown tool '{name}'"
    try:
        return str(registry[name]["execute"](params))
    except Exception as e:
        return f"Error running '{name}': {e}"
