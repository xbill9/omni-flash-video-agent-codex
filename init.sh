#!/bin/bash
#
# init.sh — one-shot setup for the Omni Flash Video Agent.
#
# Runs set_env.sh, which:
#   1. Locates a usable Python interpreter.
#   2. Installs Python dependencies from requirements.txt.
#   3. Reads (or prompts for) the Gemini API key and exports GEMINI_API_KEY / GOOGLE_API_KEY.
#   4. Writes the keys to .env.
#   5. Wires up the MCP server path in .mcp.json (Claude).
#
# To persist the exported environment variables in your current shell, source this
# script instead of executing it:
#
#     source ./init.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# If sourced, source set_env.sh so the exported vars land in the caller's shell.
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    source "$SCRIPT_DIR/set_env.sh"
else
    exec "$SCRIPT_DIR/set_env.sh"
fi
