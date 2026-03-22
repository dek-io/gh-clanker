#!/usr/bin/env bash
# github-mcp-clanker — Claude Code PreToolUse hook that appends a suffix to GitHub MCP
# body/message fields. Activated by GH_CLANKER_SUFFIX (same env var as the CLI wrapper).
# Requires: jq

set -euo pipefail

SUFFIX="${GH_CLANKER_SUFFIX:-}"
[[ -z "$SUFFIX" ]] && exit 0

# Trim leading whitespace — used for dedup checks and empty-body fallback
SUFFIX_TRIMMED="${SUFFIX#"${SUFFIX%%[![:space:]]*}"}"

INPUT=$(cat)

tool_name=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

# Determine which field to suffix based on the tool
body_field=""
case "$tool_name" in
  mcp__github__create_pull_request)               body_field="body" ;;
  mcp__github__update_pull_request)               body_field="body" ;;
  mcp__github__add_issue_comment)                 body_field="body" ;;
  mcp__github__add_comment_to_pending_review)     body_field="body" ;;
  mcp__github__add_reply_to_pull_request_comment) body_field="body" ;;
  mcp__github__issue_write)                       body_field="body" ;;
  mcp__github__pull_request_review_write)         body_field="body" ;;
  mcp__github__create_or_update_file)             body_field="message" ;;
  mcp__github__push_files)                        body_field="message" ;;
  *)
    exit 0
    ;;
esac

# All string ops in jq to avoid bash newline/control-char issues:
# - Only modify if field is present (don't inject body into title-only updates)
# - endswith() after rstrip for proper suffix detection
# - Type-check: skip non-string values silently
printf '%s' "$INPUT" | jq \
  --arg field "$body_field" \
  --arg suffix "$SUFFIX" \
  --arg suffix_trimmed "$SUFFIX_TRIMMED" \
  '
  .tool_input[$field] // null |
  if . == null then
    empty
  elif type != "string" then
    empty
  elif (gsub("\\s+$"; "") | endswith($suffix_trimmed)) then
    empty
  elif . == "" then
    { hookSpecificOutput: { hookEventName: "PreToolUse", updatedInput: { ($field): $suffix_trimmed } } }
  else
    { hookSpecificOutput: { hookEventName: "PreToolUse", updatedInput: { ($field): (. + $suffix) } } }
  end
  '
