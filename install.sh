#!/usr/bin/env bash
# gh-clanker installer — sets up the gh CLI wrapper and Claude Code hook.

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/dek-io/gh-clanker/main"
DEFAULT_SUFFIX=$'\n\nt. Clanker :robot:'

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
info() { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$1"; }

# Detect if running from clone or curl|bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null || echo ".")" && pwd)"

fetch() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$SCRIPT_DIR/$src" ]]; then
    cp "$SCRIPT_DIR/$src" "$dst"
  else
    curl -fsSL "$REPO_RAW/$src" -o "$dst"
  fi
  chmod +x "$dst"
}

# ── 1. CLI wrapper ──
fetch "cli/gh" "$HOME/.local/bin/gh"
info "Installed CLI wrapper → ~/.local/bin/gh"

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  warn "~/.local/bin is not on PATH — add it to your shell profile"
fi

# ── 2. Claude Code hook ──
fetch "hooks/github-mcp-clanker.sh" "$HOME/.claude/hooks/github-mcp-clanker.sh"
info "Installed Claude Code hook → ~/.claude/hooks/github-mcp-clanker.sh"

# ── 3. Patch Claude Code settings.json ──
SETTINGS="$HOME/.claude/settings.json"

if ! command -v jq &>/dev/null; then
  warn "jq not found — skipping settings.json patch. See README for manual setup."
  exit 0
fi

[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

MATCHER='^mcp__github__(create_pull_request|update_pull_request|add_issue_comment|add_comment_to_pending_review|add_reply_to_pull_request_comment|issue_write|pull_request_review_write|create_or_update_file|push_files)$'
HOOK_CMD='bash ~/.claude/hooks/github-mcp-clanker.sh'

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq \
  --arg suffix "$DEFAULT_SUFFIX" \
  --arg matcher "$MATCHER" \
  --arg hook_cmd "$HOOK_CMD" \
  '
  .env //= {} |
  .env.GH_CLANKER_SUFFIX //= $suffix |
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  if (.hooks.PreToolUse | map(select(.hooks[]?.command | test("github-mcp-clanker"))) | length) > 0 then
    .
  else
    .hooks.PreToolUse += [{
      matcher: $matcher,
      hooks: [{ type: "command", command: $hook_cmd }]
    }]
  end
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

info "Patched Claude Code settings → ~/.claude/settings.json"

echo ""
echo "Done. Agent-authored GitHub content will be signed with your suffix."
echo "To customize, edit GH_CLANKER_SUFFIX in ~/.claude/settings.json"
