# Permissions

Claude Code asks before running tools by default. Permissions let you pre-approve the safe ones so you spend your time on real decisions, not clicking "allow" on `bun run check` for the 400th time.

## Two files, two purposes

| File | Committed? | Who edits it | Purpose |
|---|---|---|---|
| `.claude/settings.json` | Yes | You, deliberately | The baseline every session starts with |
| `.claude/settings.local.json` | No (`.gitignore`d) | Claude Code, automatically | Session-by-session approvals you accept in the UI |

The committed `settings.json` is the team's contract: "these tool invocations are pre-approved for everyone." The local file is a working scratchpad — it accumulates approvals as you click "always allow" on prompts, and you can promote anything from local → committed when you're ready to standardize it.

## The allow-prefix pattern

Permissions match by prefix. Use `:*` to allow any suffix:

```json
{
  "permissions": {
    "allow": [
      "Bash(bun run dev:*)",
      "Bash(bun run check:*)",
      "Bash(bun test:*)",
      "Bash(git add:*)",
      "Bash(git commit -m ':*)",
      "Bash(gh pr:*)",
      "WebSearch",
      "WebFetch(domain:github.com)"
    ],
    "deny": [
      "Bash(git push --force:*)",
      "Bash(git push origin --force:*)",
      "Bash(git push -f:*)",
      "Bash(git push origin -f:*)"
    ]
  }
}
```

The `:*` matches any arguments after the prefix. So `Bash(bun run check:*)` allows `bun run check`, `bun run check --fix`, `bun run check src/`, etc.

## What goes in the baseline

The `common/.claude/settings.json` shipped with this template includes:

- **Build/test/lint** for the chosen stack (`bun run check:*`, `bun test:*`, etc.)
- **`gh` CLI** read-mostly subcommands (`gh pr:*`, `gh run:*`, `gh issue:*`, `gh auth:*`)
- **Git everyday verbs** that aren't destructive (`git add:*`, `git commit -m ':*`, `git stash:*`, `git checkout:*`)
- **Push to origin** (but not `--force`)
- **`WebSearch`** unconditionally
- **`WebFetch`** for common-sense documentation domains (github.com, npmjs.com)
- **A deny list** for the four spellings of `git push --force` (the most common foot-gun)

## What does NOT go in the baseline

- **`Bash` without a prefix.** Don't write `Bash(:*)` — that allows everything.
- **`Bash(rm -rf:*)`** — never. No baseline should pre-approve recursive delete.
- **Project-specific paths the AI hasn't seen yet.** Don't pre-approve `Bash(bun scripts/some-thing.ts *)` until that script exists.
- **Approvals you accumulated by accident** in `.local`. Audit before promoting.

## Adding MCP tool permissions

When you install an MCP server (see [`mcps.md`](mcps.md)), its tools appear under `mcp__<server>__<tool>` and need their own allow entries:

```json
{
  "permissions": {
    "allow": [
      "mcp__chrome-devtools__list_pages",
      "mcp__chrome-devtools__navigate_page",
      "mcp__chrome-devtools__list_console_messages",
      "mcp__chrome-devtools__take_screenshot",
      "mcp__chrome-devtools__evaluate_script"
    ]
  }
}
```

`init.sh` in this template adds these automatically when you opt into the Chrome DevTools install.

## settings.local.json hygiene

`.local` accumulates cruft fast — every "always allow" you click on a one-off command lands there forever. Two cleanup habits:

1. **Audit before sharing or pushing.** You shouldn't be pushing `.local` (it's gitignored), but skim it occasionally to see what's collected.
2. **Promote, then prune.** When you notice you're approving the same prefix in `.local` across sessions, copy it into the committed `settings.json` and delete it from `.local`.

## How to think about new permissions

Before pre-approving a new tool invocation, ask:

1. **What's the worst this command could do if the AI runs it on the wrong thing?** A `bun test` is recoverable. A `gh pr merge` is not.
2. **Is the prefix tight enough?** `Bash(git:*)` is too broad. `Bash(git add:*)` is fine.
3. **Should this be in baseline (`settings.json`) or session (`settings.local.json`)?** If it's a one-off exploration, leave it local.

## Reference

Anthropic's permissions docs: https://code.claude.com/docs/en/iam (search for "permissions")
