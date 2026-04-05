"""Tool: get the current date and time."""

from datetime import datetime

TOOL_DEFINITION = {
    "type": "function",
    "function": {
        "name": "get_time",
        "description": "Returns the current local date and time.",
        "parameters": {
            "type": "object",
            "properties": {},
            "required": [],
        },
    },
}


def execute(params: dict) -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
