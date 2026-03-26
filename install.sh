#!/bin/bash
set -e

PLUGIN_NAME="sentry-autofix"
PLUGIN_DIR="$HOME/.claude/plugins/local/$PLUGIN_NAME"
SETTINGS="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Sentry Autofix Plugin Install ==="

# 1. Prerequisites
echo "[1/5] Checking prerequisites..."

missing=""
if ! command -v gh &> /dev/null; then
  missing="$missing\n  - gh CLI (brew install gh)"
fi
if ! command -v git &> /dev/null; then
  missing="$missing\n  - git"
fi

if [ -n "$missing" ]; then
  echo -e "Missing:$missing"
  exit 1
fi

if ! gh auth status &> /dev/null 2>&1; then
  echo "gh CLI not authenticated. Run: gh auth login"
  exit 1
fi

echo "OK"

# 2. Install plugin
echo "[2/5] Installing plugin..."

if [ -d "$PLUGIN_DIR" ]; then
  echo "Existing installation found. Updating..."
  rm -rf "$PLUGIN_DIR"
fi

mkdir -p "$PLUGIN_DIR"
cp -r "$SCRIPT_DIR/.claude-plugin" "$PLUGIN_DIR/"
cp -r "$SCRIPT_DIR/skills" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/.mcp.json" "$PLUGIN_DIR/"
[ -f "$SCRIPT_DIR/README.md" ] && cp "$SCRIPT_DIR/README.md" "$PLUGIN_DIR/"

echo "Installed to $PLUGIN_DIR"

# 3. Enable plugin
echo "[3/5] Enabling plugin..."

if [ -f "$SETTINGS" ] && command -v jq &> /dev/null; then
  tmp=$(mktemp)
  jq '.enabledPlugins["sentry-autofix@local"] = true' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "Plugin enabled in settings.json"
else
  echo "Add manually to $SETTINGS:"
  echo '  "enabledPlugins": { "sentry-autofix@local": true }'
fi

# 4. Register Sentry MCP server
echo "[4/5] Registering Sentry MCP server..."

SENTRY_MCP_URL="https://mcp.sentry.dev/mcp"

if [ -f "$SETTINGS" ] && command -v jq &> /dev/null; then
  # Check if sentry MCP is already registered
  if jq -e '.mcpServers.sentry' "$SETTINGS" &> /dev/null; then
    echo "Sentry MCP already registered"
  else
    tmp=$(mktemp)
    jq '.mcpServers.sentry = {"type": "http", "url": "'"$SENTRY_MCP_URL"'"}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "Sentry MCP registered: $SENTRY_MCP_URL"
  fi
else
  echo "Add manually to $SETTINGS:"
  echo '  "mcpServers": { "sentry": { "type": "http", "url": "'"$SENTRY_MCP_URL"'" } }'
fi

# 5. Done
echo "[5/5] Done!"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code"
echo "  2. In your project: /sentry-scan"
echo "     (First run opens Sentry OAuth in browser)"
echo "  3. Auto mode: /loop 12h /sentry-fix"
echo ""
