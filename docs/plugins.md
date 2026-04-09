# Plugins

Claude Code plugins are installable bundles that add slash commands, skills, hooks, agents, and MCP server registrations to your Claude Code setup. They're distributed through **marketplaces** — git repos that host one or more plugins.

If skills are the procedures you write yourself, plugins are the procedures (and tools) you install from someone else.

## The default marketplace

The official Anthropic marketplace, **`claude-plugins-official`**, ships with Claude Code and is available on every install. You don't need to add it.

It contains things like:

- **Language servers**: `typescript-lsp`, `pyright-lsp`, and others
- **External integrations**: GitHub, GitLab, Jira, Slack, Vercel
- **Various developer tooling** plugins

To install a plugin from it:

```sh
claude plugin install <plugin-name>@claude-plugins-official
```

## Language server plugins

The single most useful plugin to install on day one is the LSP plugin for your stack. This is what gives Claude Code structured access to types, definitions, references, and diagnostics — much richer than running `tsc --noEmit` and parsing output.

```sh
# bun-ts (TypeScript)
claude plugin install typescript-lsp@claude-plugins-official

# Python
claude plugin install pyright-lsp@claude-plugins-official
```

`init.sh` runs the right one for your stack automatically (default `y`).

After install, the LSP tool surface shows up in Claude Code as a deferred tool the AI can call. You don't have to do anything else — it picks up your `tsconfig.json` / `pyproject.toml` automatically.

## Adding a third-party marketplace

Marketplaces are just git repos with a manifest. To add one:

```sh
claude plugin marketplace add <owner>/<repo>
```

The format is `owner/repo` for GitHub, or a full git URL for anything else. After adding, plugins from that marketplace become installable as `<plugin>@<marketplace>`.

### Example: Chrome DevTools

```sh
claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp
claude plugin install chrome-devtools-mcp
```

The first command registers the marketplace; the second installs the plugin from it. This is the recommended path for Chrome DevTools — see below for why both the plugin and the MCP server matter.

## Plugin vs MCP: when both apply

For some integrations (Chrome DevTools is the canonical example), you install **both** a plugin and an MCP server:

| Layer          | What it provides                                                                                      |
| -------------- | ----------------------------------------------------------------------------------------------------- |
| **Plugin**     | Slash commands (`/debug-optimize-lcp`, `/a11y-debugging`), pre-canned workflows, settings             |
| **MCP server** | The actual tool surface (`mcp__chrome-devtools__list_pages`, etc.) — what the AI calls under the hood |

The plugin's slash commands invoke the MCP server's tools. You need the MCP server installed for the plugin's commands to work, and you need the plugin installed for the slash commands to exist.

`init.sh` does all three steps when you opt into Chrome DevTools:

```sh
claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp
claude plugin install chrome-devtools-mcp
claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

## What's a plugin vs what's an MCP

| Integration                         | Available as                                                                                   |
| ----------------------------------- | ---------------------------------------------------------------------------------------------- |
| TypeScript LSP                      | Plugin (`typescript-lsp@claude-plugins-official`)                                              |
| Pyright LSP                         | Plugin (`pyright-lsp@claude-plugins-official`)                                                 |
| GitHub                              | Plugin (`@claude-plugins-official`)                                                            |
| GitLab                              | Plugin (`@claude-plugins-official`)                                                            |
| Jira / Slack / Vercel               | Plugins (`@claude-plugins-official`)                                                           |
| Chrome DevTools                     | **Plugin + MCP** (`ChromeDevTools/chrome-devtools-mcp` marketplace, plus separate MCP install) |
| Postgres / Filesystem / Git         | MCP servers (no plugin wrapper)                                                                |
| Linear, Notion (claude.ai versions) | Built-in MCPs configured at the user level                                                     |

When in doubt: if it shows up in `/plugin marketplace browse`, install it as a plugin. If it's a raw MCP server reference somewhere, use `claude mcp add`. Some things — like Chrome DevTools — are both.

## Listing what you have

```sh
claude plugin list                      # plugins installed
claude plugin marketplace list          # marketplaces registered
claude mcp list                         # MCP servers configured
```

## Removing a plugin

```sh
claude plugin uninstall <name>@<marketplace>
```

## Where plugin config lives

- **User-scoped**: `~/.claude.json` — plugins and marketplaces installed for your user, available across all projects
- **Project-scoped**: `.claude/settings.json` (under `extraKnownMarketplaces` and friends) — plugins and marketplaces specific to this repo

For team-shared setups (an LSP plugin, say), prefer project scope so the next contributor gets the same plugins on `git clone`.

## Reference

- Anthropic plugins docs: https://code.claude.com/docs/en/discover-plugins
- Plugin reference (manifest format, hooks, agents, etc.): https://code.claude.com/docs/en/plugins-reference
- The official `claude-plugins-official` marketplace source: https://github.com/anthropics/claude-code (look under the plugins directory)
