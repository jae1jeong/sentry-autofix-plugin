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
cp -r "$SCRIPT_DIR/plugins/sentry-autofix/.claude-plugin" "$PLUGIN_DIR/"
cp -r "$SCRIPT_DIR/plugins/sentry-autofix/skills" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/plugins/sentry-autofix/.mcp.json" "$PLUGIN_DIR/"

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

if command -v claude &> /dev/null; then
  # Check if already registered
  if claude mcp list 2>/dev/null | grep -q "sentry"; then
    echo "Sentry MCP already registered"
  else
    claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
    echo "Sentry MCP registered (OAuth — 첫 사용 시 브라우저 인증)"
  fi
else
  echo "claude CLI not found. 수동으로 실행하세요:"
  echo "  claude mcp add --transport http sentry https://mcp.sentry.dev/mcp"
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
