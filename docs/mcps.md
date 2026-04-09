# MCP Servers

MCP (Model Context Protocol) servers expose tools and resources to Claude Code over a small protocol. They're how the AI gets access to things outside its built-in tool surface — browsers, databases, third-party APIs, custom internal systems.

## Where MCPs live

MCP server configuration lives in one of three places, depending on scope:

| Scope           | File                                   | Shared via |
| --------------- | -------------------------------------- | ---------- |
| Local (default) | `~/.claude.json` (per-project section) | Not shared |
| Project         | `.mcp.json` at the project root        | Git        |
| User            | `~/.claude.json`                       | Not shared |

For team consistency, **prefer project scope** so the MCP setup is committed to the repo and every contributor gets the same servers.

## Adding an MCP server

The CLI command:

```sh
claude mcp add --scope project <name> -- <command> [args...]
```

For Chrome DevTools specifically:

```sh
claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

That writes a `.mcp.json` entry like:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

`init.sh` runs this command for you when you opt into Chrome DevTools.

## Permissions for MCP tools

MCP tools show up in your permissions allow list as `mcp__<server>__<tool>`. They're denied by default and need explicit allow entries:

```json
{
  "permissions": {
    "allow": [
      "mcp__chrome-devtools__list_pages",
      "mcp__chrome-devtools__navigate_page",
      "mcp__chrome-devtools__list_console_messages",
      "mcp__chrome-devtools__take_screenshot",
      "mcp__chrome-devtools__evaluate_script",
      "mcp__chrome-devtools__performance_start_trace",
      "mcp__chrome-devtools__performance_stop_trace",
      "mcp__chrome-devtools__performance_analyze_insight"
    ]
  }
}
```

`init.sh` adds these to `.claude/settings.json` automatically if you opt in. See [`permissions.md`](permissions.md) for the details on the prefix pattern.

## Chrome DevTools: the workflow

Chrome DevTools MCP is the most useful one to set up first because it gives Claude direct access to a real browser tab — not Playwright, not a synthetic environment, **your browser**. That means it can read console logs from your dev server, take screenshots of what you're seeing, run JS in the page, and trace performance.

### Prerequisite

Chrome must be running with `--remote-debugging-port=9222`:

```sh
# macOS
open -a "Google Chrome" --args --remote-debugging-port=9222

# Linux
google-chrome --remote-debugging-port=9222

# Windows
chrome.exe --remote-debugging-port=9222
```

(Make a shell alias for this — you'll use it constantly.)

### Common uses

| Tool                                                      | When                                                       |
| --------------------------------------------------------- | ---------------------------------------------------------- |
| `list_console_messages`                                   | "Why does the page show an error?"                         |
| `evaluate_script`                                         | "What's the value of this variable in the page right now?" |
| `take_screenshot`                                         | "Show me what this looks like"                             |
| `navigate_page`                                           | "Reload after my fix"                                      |
| `performance_start_trace` + `performance_analyze_insight` | "Why is this slow?"                                        |

For ad-hoc browser debugging, prefer Chrome DevTools MCP over Playwright. Playwright is for **writing E2E tests**, not for poking at the live app.

## Chrome DevTools is also a plugin

Chrome DevTools is unusual in that it's available **both** as a plugin (which ships slash commands and configuration) and as an MCP server (which provides the tool surface). You install both:

```sh
claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp
claude plugin install chrome-devtools-mcp
claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

The plugin gives you `/debug-optimize-lcp`, `/a11y-debugging`, `/troubleshooting`, and `/chrome-devtools` slash commands that wrap common debugging workflows. The MCP server is what those commands actually call.

See [`plugins.md`](plugins.md) for more on the plugin side.

## Discovering more MCPs

The MCP ecosystem is growing fast. Some places to look:

- The official MCP server registry (linked from https://docs.claude.com)
- https://github.com/modelcontextprotocol/servers — reference servers (filesystem, GitHub, Postgres, Slack, etc.)
- https://github.com/punkpeye/awesome-mcp-servers — community-curated list

Most MCPs you'd want — Slack, Linear, Notion, Postgres, GitHub — are in one of these lists.

## Removing an MCP

```sh
claude mcp remove chrome-devtools
```

That removes the entry from `.mcp.json`. Don't forget to remove the matching `mcp__chrome-devtools__*` entries from `.claude/settings.json` too, or you'll have stale allow rules.

## Reference

- Anthropic MCP docs: https://code.claude.com/docs/en/mcp
- MCP protocol spec: https://modelcontextprotocol.io/
