#!/usr/bin/env bash
# Matrix AI Agent — full bootstrapper
#
# One-liner install (fresh machine):
#   curl -fsSL https://raw.githubusercontent.com/laynr/matrix.py/main/install.sh | sh
#
# Or if you already cloned the repo:
#   ./install.sh

set -e

# ── Config ─────────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/laynr/matrix.py"
INSTALL_DIR="${MATRIX_HOME:-$HOME/.matrix}"   # $HOME is dynamic — not hardcoded
MODEL="${MATRIX_MODEL:-gemma4:latest}"
VENV_DIR="$INSTALL_DIR/.venv"

# Colors (printf only — echo -e is not portable in /bin/sh)
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "  ${GREEN}[ok]${NC}    %s\n" "$*"; }
info() { printf "  ${CYAN}[setup]${NC} %s\n" "$*"; }
warn() { printf "  ${YELLOW}[warn]${NC}  %s\n" "$*"; }
step() { printf "  %s\n" "$*"; }
die()  { printf "  ${RED}[error]${NC} %s\n" "$*" >&2; exit 1; }

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║          M A T R I X             ║"
echo "  ║     AI Agent  •  Ollama          ║"
echo "  ╚══════════════════════════════════╝"
echo "  Installing to: $INSTALL_DIR"
echo "  Model:         $MODEL"
echo ""

OS="$(uname -s)"

# ── Step 1: Install Ollama if missing ──────────────────────────────────────────
install_ollama_macos() {
    if command -v brew >/dev/null 2>&1; then
        info "Installing Ollama via Homebrew..."
        brew install ollama
    else
        info "Downloading Ollama for macOS (Apple Silicon)..."
        TMP=$(mktemp -d)
        curl -fsSL "https://ollama.com/download/Ollama-darwin.zip" -o "$TMP/Ollama.zip"
        unzip -q "$TMP/Ollama.zip" -d "$TMP"
        OLLAMA_BIN="$TMP/Ollama.app/Contents/Resources/ollama"
        if [ -f "$OLLAMA_BIN" ]; then
            sudo mkdir -p /usr/local/bin
            sudo cp "$OLLAMA_BIN" /usr/local/bin/ollama
            sudo chmod +x /usr/local/bin/ollama
            ok "Ollama binary installed to /usr/local/bin/ollama"
        else
            die "Could not find ollama binary. Install manually from https://ollama.com"
        fi
        rm -rf "$TMP"
    fi
}

install_ollama_linux() {
    info "Installing Ollama via official install script..."
    curl -fsSL https://ollama.com/install.sh | sh
}

if command -v ollama >/dev/null 2>&1; then
    ok "Ollama: $(ollama --version 2>/dev/null | head -1)"
else
    warn "Ollama not found — installing..."
    case "$OS" in
        Darwin) install_ollama_macos ;;
        Linux)  install_ollama_linux ;;
        *) die "Unsupported OS '$OS'. Install Ollama from https://ollama.com" ;;
    esac
    command -v ollama >/dev/null 2>&1 || die "Ollama installation failed."
    ok "Ollama installed: $(ollama --version 2>/dev/null | head -1)"
fi

# ── Step 2: Ensure Ollama service is running ───────────────────────────────────
info "Checking Ollama service..."
if ! ollama list >/dev/null 2>&1; then
    info "Starting Ollama service..."
    if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
        brew services start ollama 2>/dev/null || true
        sleep 3
    else
        ollama serve >/dev/null 2>&1 &
        sleep 4
    fi
    ollama list >/dev/null 2>&1 || die "Ollama service failed to start. Run 'ollama serve' manually."
fi
ok "Ollama service running"

# ── Step 3: Pull the model ─────────────────────────────────────────────────────
info "Checking model '$MODEL'..."
if ollama list 2>/dev/null | grep -q "^$MODEL"; then
    ok "Model '$MODEL' already available"
else
    info "Pulling '$MODEL' — this may take several minutes on first run..."
    ollama pull "$MODEL" || die "Failed to pull '$MODEL'. Check your internet connection."
    ok "Model '$MODEL' ready"
fi

# ── Step 4: Install Python 3 if missing ────────────────────────────────────────
install_python_macos() {
    if command -v brew >/dev/null 2>&1; then
        info "Installing Python 3 via Homebrew..."
        brew install python3
    else
        die "Python 3 required. Install via: https://python.org or 'brew install python3'"
    fi
}

install_python_linux() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y python3 python3-venv python3-pip
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-venv
    else
        die "Python 3 required. Install it from https://python.org"
    fi
}

if command -v python3 >/dev/null 2>&1; then
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    ok "Python $PY_VER"
else
    warn "Python 3 not found — installing..."
    case "$OS" in
        Darwin) install_python_macos ;;
        Linux)  install_python_linux ;;
        *) die "Python 3 required. Install from https://python.org" ;;
    esac
    ok "Python 3 installed"
fi

# ── Step 5: Clone or update the repo ──────────────────────────────────────────
# Detect if this script is running from inside an already-cloned repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-./install.sh}")" 2>/dev/null && pwd || echo "$PWD")"
if [ -f "$SCRIPT_DIR/main.py" ] && [ -d "$SCRIPT_DIR/agent" ]; then
    INSTALL_DIR="$SCRIPT_DIR"
    VENV_DIR="$INSTALL_DIR/.venv"
    ok "Using repo at $INSTALL_DIR"
elif [ -d "$INSTALL_DIR/.git" ]; then
    info "Updating Matrix at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull --quiet
    ok "Matrix updated"
else
    info "Cloning Matrix to $INSTALL_DIR..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    ok "Matrix cloned to $INSTALL_DIR"
fi

# ── Step 6: Python virtual environment ────────────────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    info "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

info "Installing Python dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet ollama
ok "Dependencies ready"

# ── Step 7: Install the 'matrix' command ──────────────────────────────────────
# Write the launcher script inside the install dir
LAUNCHER="$INSTALL_DIR/matrix"
cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
MATRIX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$MATRIX_DIR/.venv/bin/python" "$MATRIX_DIR/main.py" "$@"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# Pick the best place to symlink so 'matrix' works from anywhere
CMD_INSTALLED=""
for candidate in /usr/local/bin /opt/homebrew/bin "$HOME/.local/bin" "$HOME/bin"; do
    if [ -d "$candidate" ] && [ -w "$candidate" ]; then
        ln -sf "$LAUNCHER" "$candidate/matrix"
        CMD_INSTALLED="$candidate"
        break
    fi
done

# If none of the above worked, create ~/bin and add to shell profile
if [ -z "$CMD_INSTALLED" ]; then
    mkdir -p "$HOME/bin"
    ln -sf "$LAUNCHER" "$HOME/bin/matrix"
    CMD_INSTALLED="$HOME/bin"
    # Add ~/bin to PATH in shell profile if not already there
    for profile in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -f "$profile" ] && ! grep -q 'HOME/bin' "$profile" 2>/dev/null; then
            echo '' >> "$profile"
            echo '# Added by Matrix installer' >> "$profile"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$profile"
            info "Added ~/bin to PATH in $profile"
            break
        fi
    done
fi
ok "Installed 'matrix' command → $CMD_INSTALLED/matrix"

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
step "✓ Setup complete. Run 'matrix' anytime to start."
echo ""
step "  Override model:  MATRIX_MODEL=gemma4:26b matrix"
echo ""
step "Starting Matrix now..."
echo ""

# NOTE: do NOT use 'exec < /dev/tty' here — when this script is piped from
# curl, that would redirect the shell's stdin away from the pipe and hang.
# The Python process handles /dev/tty itself (see main.py).
"$VENV_DIR/bin/python" "$INSTALL_DIR/main.py"
