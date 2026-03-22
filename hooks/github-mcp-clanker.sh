#!/usr/bin/env bash
# github-mcp-clanker — Claude Code PreToolUse hook that appends a suffix to GitHub MCP
# body/message fields. Activated by GH_CLANKER_SUFFIX (same env var as the CLI wrapper).
# Requires: jq

set -euo pipefail

[[ -z "${GH_CLANKER_SUFFIX:-}" ]] && exit 0

# Single jq invocation: reads stdin once, handles tool dispatch + field rewrite in one pass.
# SUFFIX_TRIMMED computed in jq to avoid bash string surgery with newlines.
jq \
  --arg suffix "$GH_CLANKER_SUFFIX" \
  '
  # Map tool name → field to suffix
  (.tool_name // "") as $t |
  (if   $t == "mcp__github__create_or_update_file" or $t == "mcp__github__push_files" then "message"
   elif ($t | startswith("mcp__github__")) and ($t |
     . == "mcp__github__create_pull_request" or
     . == "mcp__github__update_pull_request" or
     . == "mcp__github__add_issue_comment" or
     . == "mcp__github__add_comment_to_pending_review" or
     . == "mcp__github__add_reply_to_pull_request_comment" or
     . == "mcp__github__issue_write" or
     . == "mcp__github__pull_request_review_write")
   then "body"
   else null end) as $field |

  if $field == null then empty
  else
    ($suffix | ltrimstr("\n") | ltrimstr("\n") | ltrimstr(" ")) as $suffix_trimmed |
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
  end
  '
