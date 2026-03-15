# gh-clanker

A `gh` CLI wrapper that appends a configurable suffix to PR, issue, and release bodies.

## How it works

When `GH_CLANKER_SUFFIX` is set, the wrapper intercepts body/notes arguments for these commands and appends the suffix:

| Command | Intercepted flags |
|---|---|
| `pr create/edit/comment/review/merge` | `--body` `-b` `--body-file` `-F` |
| `issue create/edit/comment` | `--body` `-b` `--body-file` `-F` |
| `release create/edit` | `--notes` `-n` `--notes-file` |

For `pr create` without an explicit body, it applies the suffix via a post-create `pr edit`.

Everything else passes through to the real `gh` untouched.

## Install

```bash
cp gh ~/.local/bin/gh
chmod +x ~/.local/bin/gh
```

Make sure `~/.local/bin` is on your `PATH` before the Homebrew `gh`.

## Activate

Set `GH_CLANKER_SUFFIX` to the exact text you want appended. The value should include any leading newlines you want between the body and the suffix.

```bash
# In your shell profile:
export GH_CLANKER_SUFFIX=$'\n\nt. Clanker :robot:'
```

Unset the variable to disable (all commands pass through to real `gh`).

## Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "GH_CLANKER_SUFFIX": "\n\nt. Clanker :robot:"
  }
}
```

## License

MIT
