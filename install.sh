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
RAW_BASE="https://raw.githubusercontent.com/laynr/matrix.py/main"
INSTALL_DIR="${MATRIX_HOME:-$HOME/.matrix}"
MODEL="${MATRIX_MODEL:-gemma4:latest}"
VENV_DIR="$INSTALL_DIR/.venv"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}[ok]${NC}    $*"; }
info() { echo -e "  ${CYAN}[setup]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[warn]${NC}  $*"; }
die()  { echo -e "  ${RED}[error]${NC} $*" >&2; exit 1; }

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║          M A T R I X             ║"
echo "  ║     AI Agent  •  Ollama          ║"
echo "  ╚══════════════════════════════════╝"
echo "  Installing to: $INSTALL_DIR"
echo "  Model: $MODEL"
echo ""

OS="$(uname -s)"

# ── Step 1: Install Ollama if missing ──────────────────────────────────────────
install_ollama_macos() {
    if command -v brew &>/dev/null; then
        info "Installing Ollama via Homebrew..."
        brew install ollama
    else
        info "Downloading Ollama for macOS (Apple Silicon)..."
        TMP=$(mktemp -d)
        curl -fsSL "https://ollama.com/download/Ollama-darwin.zip" -o "$TMP/Ollama.zip"
        unzip -q "$TMP/Ollama.zip" -d "$TMP"
        # Extract the CLI binary from the app bundle
        OLLAMA_BIN="$TMP/Ollama.app/Contents/Resources/ollama"
        if [ -f "$OLLAMA_BIN" ]; then
            sudo mkdir -p /usr/local/bin
            sudo cp "$OLLAMA_BIN" /usr/local/bin/ollama
            sudo chmod +x /usr/local/bin/ollama
            ok "Ollama binary installed to /usr/local/bin/ollama"
        else
            die "Could not find ollama binary in Ollama.app. Please install manually from https://ollama.com"
        fi
        rm -rf "$TMP"
    fi
}

install_ollama_linux() {
    info "Installing Ollama via official install script..."
    curl -fsSL https://ollama.com/install.sh | sh
}

if command -v ollama &>/dev/null; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null | head -1)"
else
    warn "Ollama not found — installing..."
    case "$OS" in
        Darwin) install_ollama_macos ;;
        Linux)  install_ollama_linux ;;
        *)      die "Unsupported OS: $OS. Install Ollama manually from https://ollama.com" ;;
    esac
    command -v ollama &>/dev/null || die "Ollama installation failed."
    ok "Ollama installed: $(ollama --version 2>/dev/null | head -1)"
fi

# ── Step 2: Ensure Ollama service is running ───────────────────────────────────
ensure_ollama_running() {
    if ollama list &>/dev/null; then
        return 0
    fi
    info "Starting Ollama service..."
    if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
        brew services start ollama 2>/dev/null || true
        sleep 2
    else
        ollama serve &>/dev/null &
        sleep 3
    fi
    ollama list &>/dev/null || die "Ollama service failed to start."
}
ensure_ollama_running
ok "Ollama service running"

# ── Step 3: Pull gemma model ───────────────────────────────────────────────────
if ollama list 2>/dev/null | grep -q "^$MODEL"; then
    ok "Model '$MODEL' already available"
else
    info "Pulling '$MODEL' — this may take several minutes on first run..."
    ollama pull "$MODEL" || die "Failed to pull model '$MODEL'. Check your internet connection."
    ok "Model '$MODEL' ready"
fi

# ── Step 4: Install Python 3 if missing ────────────────────────────────────────
install_python_macos() {
    if command -v brew &>/dev/null; then
        info "Installing Python 3 via Homebrew..."
        brew install python3
    else
        die "Python 3 is required. Install via: https://python.org/downloads or brew install python3"
    fi
}

install_python_linux() {
    if command -v apt-get &>/dev/null; then
        info "Installing Python 3 via apt..."
        sudo apt-get update -qq && sudo apt-get install -y python3 python3-venv python3-pip
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 python3-venv
    else
        die "Python 3 is required. Please install it manually."
    fi
}

if command -v python3 &>/dev/null; then
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    ok "Python $PY_VER found"
else
    warn "Python 3 not found — installing..."
    case "$OS" in
        Darwin) install_python_macos ;;
        Linux)  install_python_linux ;;
        *)      die "Python 3 required. Install it from https://python.org" ;;
    esac
    command -v python3 &>/dev/null || die "Python 3 installation failed."
    ok "Python 3 installed"
fi

# ── Step 5: Clone or update the Matrix repo ────────────────────────────────────
# Detect if we're already running from inside a Matrix repo clone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [ -f "$SCRIPT_DIR/main.py" ] && [ -d "$SCRIPT_DIR/agent" ]; then
    # Running from within the repo — use this directory
    INSTALL_DIR="$SCRIPT_DIR"
    VENV_DIR="$INSTALL_DIR/.venv"
    ok "Using existing repo at $INSTALL_DIR"
elif [ -d "$INSTALL_DIR/.git" ]; then
    # Already cloned — update
    info "Updating Matrix at $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull --quiet
    ok "Matrix updated"
else
    # Fresh install — clone
    info "Cloning Matrix to $INSTALL_DIR..."
    git clone --quiet "$REPO_URL" "$INSTALL_DIR"
    ok "Matrix cloned to $INSTALL_DIR"
fi

# ── Step 6: Create virtual environment ─────────────────────────────────────────
if [ ! -d "$VENV_DIR" ]; then
    info "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

info "Installing Python dependencies..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet ollama
ok "Dependencies installed"

# ── Step 7: Install the 'matrix' command ───────────────────────────────────────
LAUNCHER="$INSTALL_DIR/matrix"
cat > "$LAUNCHER" << LAUNCHER_EOF
#!/usr/bin/env bash
MATRIX_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$MATRIX_DIR/.venv/bin/python" "\$MATRIX_DIR/main.py" "\$@"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# Optionally link to /usr/local/bin if writable
if [ -w /usr/local/bin ]; then
    ln -sf "$LAUNCHER" /usr/local/bin/matrix
    ok "Installed 'matrix' command to /usr/local/bin/matrix"
elif [ -d "$HOME/.local/bin" ]; then
    ln -sf "$LAUNCHER" "$HOME/.local/bin/matrix"
    ok "Installed 'matrix' command to ~/.local/bin/matrix"
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "  ✓ Matrix is ready."
echo ""
echo "  Run again anytime with:"
echo "    matrix           (if /usr/local/bin is in your PATH)"
echo "    $LAUNCHER"
echo ""
echo "  Override model:  MATRIX_MODEL=gemma4:26b matrix"
echo ""
echo "  Starting Matrix now..."
echo ""

exec "$VENV_DIR/bin/python" "$INSTALL_DIR/main.py" </dev/tty
