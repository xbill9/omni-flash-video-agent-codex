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

update_codex_mcp_config() {
    local config_file="$CURRENT_DIR/.codex/config.toml"

    if [ ! -f "$config_file" ]; then
        echo "⚠️  Could not find $config_file to update."
        return 0
    fi

    if CONFIG_FILE="$config_file" CURRENT_DIR="$CURRENT_DIR" PYTHON_BIN="$PYTHON_BIN" GEMINI_API_KEY="$GEMINI_API_KEY" "$PYTHON_BIN" -c '
import json
import os
from pathlib import Path

config_file = Path(os.environ["CONFIG_FILE"])
current_dir = os.environ["CURRENT_DIR"]
python_bin = os.environ["PYTHON_BIN"]
gemini_api_key = os.environ["GEMINI_API_KEY"]

section = "[mcp_servers.omni-video-agent]"
server_path = os.path.join(current_dir, "server.py")
server_lines = [
    section,
    f"command = {json.dumps(python_bin)}",
    f"args = [{json.dumps(server_path)}]",
    "enabled = true",
]

lines = config_file.read_text().splitlines()
out = []
i = 0
inserted = False

while i < len(lines):
    line = lines[i]
    if line.strip() == section:
        out.extend(server_lines)
        inserted = True
        i += 1
        while i < len(lines) and not lines[i].lstrip().startswith("["):
            i += 1
        continue
    out.append(line)
    i += 1

if not inserted:
    if out and out[-1].strip():
        out.append("")
    out.extend(server_lines)

config_file.write_text("\n".join(out).rstrip() + "\n")
'
    then
        echo "✅ Updated $config_file with path and env keys."
    else
        echo "❌ Failed to update $config_file."
        return 1
    fi
}

update_codex_mcp_config
