"""
Chat loop with Ollama tool-calling support.
"""

import ollama
from agent import tools

SYSTEM_PROMPT = (
    "You are Matrix, a helpful AI agent running on this machine. "
    "You have access to tools — use them whenever they help answer the user. "
    "Be concise and direct."
)


def run_turn(user_input: str, history: list, model: str) -> str:
    """
    Process one user turn. Appends to history in-place.
    Returns the assistant's final text response.
    """
    history.append({"role": "user", "content": user_input})

    # First call: may produce tool calls
    response = ollama.chat(
        model=model,
        messages=history,
        tools=tools.get_definitions(),
    )

    assistant_msg = response.message
    history.append({"role": "assistant", "content": assistant_msg.content or "", "tool_calls": assistant_msg.tool_calls or []})

    if not assistant_msg.tool_calls:
        return assistant_msg.content or ""

    # Execute each tool call and collect results
    for call in assistant_msg.tool_calls:
        name = call.function.name
        params = call.function.arguments or {}
        print(f"\n  [tool] {name}({params})")
        result = tools.dispatch(name, params)
        print(f"  [result] {result}")
        history.append({"role": "tool", "content": result})

    # Second call: get the final text response after tool results
    follow_up = ollama.chat(
        model=model,
        messages=history,
    )
    final_msg = follow_up.message
    history.append({"role": "assistant", "content": final_msg.content or ""})
    return final_msg.content or ""
