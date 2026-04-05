"""Tool: create a new tool for the Matrix framework."""

import os
from pathlib import Path

TOOL_DEFINITION = {
    "type": "function",
    "function": {
        "name": "create_tool",
        "description": (
            "Creates a new tool Python file in the tools/ directory and immediately "
            "registers it so it can be used in this session. "
            "The file must define TOOL_DEFINITION (Ollama function schema) and "
            "execute(params: dict) -> str at module level."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Snake_case name for the tool (e.g. 'search_web'). Used as the file name.",
                },
                "code": {
                    "type": "string",
                    "description": (
                        "Complete Python source for the tool file. "
                        "Must include TOOL_DEFINITION dict and execute(params) function."
                    ),
                },
            },
            "required": ["name", "code"],
        },
    },
}

_TOOLS_DIR = Path(__file__).parent


def execute(params: dict) -> str:
    name = params["name"].strip().replace(" ", "_")
    code = params["code"]

    if not name or not name.isidentifier():
        return f"Error: '{name}' is not a valid Python identifier."

    tool_path = _TOOLS_DIR / f"{name}.py"
    if tool_path.exists():
        return f"Error: tool '{name}' already exists at {tool_path}."

    tool_path.write_text(code, encoding="utf-8")

    # Hot-reload into the live registry
    from agent import tools as tool_registry
    ok = tool_registry.load_tool(str(tool_path))

    if ok:
        return f"Tool '{name}' created at {tool_path} and registered successfully."
    else:
        tool_path.unlink(missing_ok=True)
        return (
            f"Tool file was written but failed to register. "
            f"Check that the code defines TOOL_DEFINITION and execute(). "
            f"File removed."
        )
