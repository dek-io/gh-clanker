# gh-clanker

Signs agent-authored GitHub content with a configurable suffix. Deterministic — code, not an LLM instruction.

## How it works

Two mechanisms, one env var (`GH_CLANKER_SUFFIX`):

| Mechanism | Intercepts | When |
|---|---|---|
| **CLI wrapper** (`cli/gh`) | `gh pr create`, `gh issue comment`, etc. | Agent shells out to `gh` CLI |
| **Claude Code hook** (`hooks/github-mcp-clanker.sh`) | `mcp__github__*` tool calls | Agent uses GitHub MCP tools |

Both append the suffix to body/message fields. Unset the env var to disable — both become passthrough.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/dek-io/gh-clanker/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/dek-io/gh-clanker.git
cd gh-clanker && ./install.sh
```

The installer:

1. Copies `cli/gh` → `~/.local/bin/gh`
2. Copies `hooks/github-mcp-clanker.sh` → `~/.claude/hooks/`
3. Adds `GH_CLANKER_SUFFIX` env var and PreToolUse hook to `~/.claude/settings.json` (idempotent)

Requires `jq` for the hook and settings patching.

### Manual setup

If you prefer not to use the installer:

```bash
# CLI wrapper
cp cli/gh ~/.local/bin/gh && chmod +x ~/.local/bin/gh
# Ensure ~/.local/bin is on PATH before the real gh

# Claude Code hook
cp hooks/github-mcp-clanker.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/github-mcp-clanker.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "env": {
    "GH_CLANKER_SUFFIX": "\n\nt. Clanker :robot:"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^mcp__github__(create_pull_request|update_pull_request|add_issue_comment|add_comment_to_pending_review|add_reply_to_pull_request_comment|issue_write|pull_request_review_write|create_or_update_file|push_files)$",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/github-mcp-clanker.sh"
          }
        ]
      }
    ]
  }
}
```

## Configuration

The suffix defaults to `\n\nt. Clanker :robot:`. To customize, edit `GH_CLANKER_SUFFIX` in `~/.claude/settings.json`:

```json
{
  "env": {
    "GH_CLANKER_SUFFIX": "\n\n— sent by my agent"
  }
}
```

For shell usage outside Claude Code, export it in your profile:

```bash
export GH_CLANKER_SUFFIX=$'\n\nt. Clanker :robot:'
```

## Covered operations

### CLI wrapper

| Command | Intercepted flags |
|---|---|
| `pr create/edit/comment/review/merge` | `--body` `-b` `--body-file` `-F` |
| `issue create/edit/comment` | `--body` `-b` `--body-file` `-F` |
| `release create/edit` | `--notes` `-n` `--notes-file` |

For `pr create` without an explicit body, it applies the suffix via a post-create `pr edit`.

### Claude Code hook

| MCP tool | Field |
|---|---|
| `create_pull_request` | `body` |
| `update_pull_request` | `body` |
| `add_issue_comment` | `body` |
| `add_comment_to_pending_review` | `body` |
| `add_reply_to_pull_request_comment` | `body` |
| `issue_write` | `body` |
| `pull_request_review_write` | `body` |
| `create_or_update_file` | `message` |
| `push_files` | `message` |

The hook only modifies fields that are already present — it won't inject a `body` into a title-only issue update.

## How the hook works

The Claude Code hook is a [PreToolUse hook](https://docs.anthropic.com/en/docs/claude-code/hooks) that:

1. Receives the tool call as JSON on stdin (tool name + input params)
2. Matches against GitHub MCP write operations
3. Checks if the body/message field exists, is a string, and isn't already suffixed
4. Outputs `updatedInput` JSON to rewrite the field before Claude Code executes the tool

If the field is absent, null, or already suffixed, the hook exits 0 with no output (passthrough).

## License

MIT
