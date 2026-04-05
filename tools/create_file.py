"""Tool: create a text-based file on disk."""

import os
from pathlib import Path

TOOL_DEFINITION = {
    "type": "function",
    "function": {
        "name": "create_file",
        "description": (
            "Creates a text file at the given path with the provided content. "
            "Fails if the file already exists unless overwrite is true."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Absolute or relative path where the file should be created.",
                },
                "content": {
                    "type": "string",
                    "description": "Text content to write into the file.",
                },
                "overwrite": {
                    "type": "boolean",
                    "description": "If true, overwrite an existing file. Default: false.",
                },
            },
            "required": ["path", "content"],
        },
    },
}


def execute(params: dict) -> str:
    path = Path(params["path"])
    content = params.get("content", "")
    overwrite = params.get("overwrite", False)

    if path.exists() and not overwrite:
        return f"Error: '{path}' already exists. Pass overwrite=true to replace it."

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return f"Created '{path}' ({len(content)} chars)."
