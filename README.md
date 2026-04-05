# Matrix

An AI agent framework powered by [Ollama](https://ollama.com) and the `gemma4` model, designed for M4 Macs (and Linux).

## Install & Run — one command

```sh
curl -fsSL https://raw.githubusercontent.com/laynr/matrix.py/main/install.sh | sh
```

The installer will:
- Install **Ollama** if not present (via Homebrew on macOS, or the official script on Linux)
- Pull the **gemma4** model
- Install **Python 3** if missing
- Clone this repo to `~/.matrix`
- Set up a virtual environment
- Register a `matrix` command in `/usr/local/bin`
- Start the agent

After the first install, just run:

```sh
matrix
```

## REPL commands

| Command | Action |
|---------|--------|
| `reload` | Rescan `tools/` and register any new tools immediately |
| `quit` / Ctrl-C | Exit |

## Tools included

| Tool | What it does |
|------|-------------|
| `get_time` | Returns the current date and time |
| `create_file` | Creates a text file at a given path with given content |
| `create_tool` | Generates a new tool file and hot-registers it in the current session |

## Adding your own tools

Drop a Python file into the `tools/` directory. It needs exactly two things at module level:

```python
TOOL_DEFINITION = {
    "type": "function",
    "function": {
        "name": "my_tool",
        "description": "What this tool does.",
        "parameters": {
            "type": "object",
            "properties": {
                "input": {"type": "string", "description": "The input value"}
            },
            "required": ["input"],
        },
    },
}

def execute(params: dict) -> str:
    return f"You said: {params['input']}"
```

Then type `reload` in the REPL — it's live immediately, no restart needed.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MATRIX_MODEL` | `gemma4` | Ollama model to use |
| `MATRIX_HOME` | `~/.matrix` | Install directory (when using curl install) |

```sh
MATRIX_MODEL=gemma4:26b matrix
```

## Project layout

```
matrix/
├── install.sh        # bootstrapper — install + run
├── main.py           # REPL entry point
├── agent/
│   ├── tools.py      # dynamic tool loader + registry
│   └── loop.py       # Ollama chat loop with tool dispatch
└── tools/
    ├── get_time.py
    ├── create_file.py
    └── create_tool.py
```
