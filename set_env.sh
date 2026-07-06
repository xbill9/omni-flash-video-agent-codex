#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CURRENT_DIR="$SCRIPT_DIR"
KEY_FILE="$HOME/gemini.key"

find_python() {
    if [ -x "$HOME/.pyenv/shims/python" ]; then
        printf '%s\n' "$HOME/.pyenv/shims/python"
        return 0
    fi

    if command -v python >/dev/null 2>&1; then
        command -v python
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        command -v python3
        return 0
    fi

    if [ "$(uname -s)" = "Darwin" ]; then
        for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 /usr/bin/python3; do
            if [ -x "$candidate" ]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi

    return 1
}

PYTHON_BIN="$(find_python)" || {
    echo "ERROR: python3 is required. On macOS, install it with: brew install python"
    return 1 2>/dev/null || exit 1
}

echo "🐍 Using Python: $PYTHON_BIN"

# Install Python dependencies from requirements.txt
install_dependencies() {
    local req_file="$CURRENT_DIR/requirements.txt"

    if [ ! -f "$req_file" ]; then
        echo "⚠️  No requirements.txt found at $req_file; skipping dependency install."
        return 0
    fi

    echo "📦 Installing Python dependencies from requirements.txt..."
    if "$PYTHON_BIN" -m pip install --disable-pip-version-check -q -r "$req_file"; then
        echo "✅ Python dependencies installed."
    else
        echo "❌ Failed to install Python dependencies. Try running: $PYTHON_BIN -m pip install -r \"$req_file\""
        return 1
    fi
}

install_dependencies || echo "⚠️  Continuing despite dependency install failure."

# Check if the key file exists
if [ -f "$KEY_FILE" ]; then
    GEMINI_API_KEY=$(cat "$KEY_FILE")
else
    read -r -p "Enter Gemini KEY: " GEMINI_API_KEY
    printf '%s\n' "$GEMINI_API_KEY" > "$KEY_FILE"
fi

chmod 600 "$KEY_FILE" 2>/dev/null || true

# Export GEMINI_API_KEY as primary, and GOOGLE_API_KEY for backward compatibility
export GEMINI_API_KEY
export GOOGLE_API_KEY="$GEMINI_API_KEY"

echo "✅ Environment variables GEMINI_API_KEY and GOOGLE_API_KEY successfully exported."

# Write keys to .env file (never hardcode in mcp_config.json)
ENV_FILE="$CURRENT_DIR/.env"

cat > "$ENV_FILE" <<EOF
GEMINI_API_KEY=$GEMINI_API_KEY
GOOGLE_API_KEY=$GEMINI_API_KEY
EOF

set -a
source "$ENV_FILE"
set +a

echo "✅ Written API keys to $ENV_FILE"

update_claude_mcp_config() {
    local config_file="$CURRENT_DIR/.mcp.json"

    if CONFIG_FILE="$config_file" CURRENT_DIR="$CURRENT_DIR" PYTHON_BIN="$PYTHON_BIN" "$PYTHON_BIN" -c '
import json
import os
from pathlib import Path

config_file = Path(os.environ["CONFIG_FILE"])
current_dir = os.environ["CURRENT_DIR"]
python_bin = os.environ["PYTHON_BIN"]

server_name = "omni-video-agent"
server_path = os.path.join(current_dir, "server.py")

if config_file.exists():
    try:
        data = json.loads(config_file.read_text() or "{}")
    except json.JSONDecodeError:
        data = {}
else:
    data = {}

servers = data.setdefault("mcpServers", {})
server = servers.setdefault(server_name, {})
server["command"] = python_bin
server["args"] = [server_path]

config_file.write_text(json.dumps(data, indent=2) + "\n")
'
    then
        echo "✅ Updated $config_file with python path and server path."
    else
        echo "❌ Failed to update $config_file."
        return 1
    fi
}

update_claude_mcp_config
