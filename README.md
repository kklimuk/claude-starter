# claude-starter

A copy-from template for bootstrapping Claude Code projects with a consistent setup: CLAUDE.md, skills, hooks, GitHub Actions (including a Claude PR reviewer), permissions, MCPs, and language-server plugins.

It is opinionated. The conventions baked in here come from running Claude Code on three real projects and converging on what worked.

## What you get

Run `init.sh` (or `init.ps1` on Windows) inside a target directory and you'll end up with:

- **`CLAUDE.md`** — annotated skeleton with the section structure that holds up across projects
- **`README.md`** — human-facing skeleton (CLAUDE.md is for the AI; README is for humans)
- **`.claude/settings.json`** — permissions baseline with sensible `gh` / `git` / web allowlists and a force-push deny list
- **`.claude/skills/`** — `code-review`, `codebase-review`, `security-review`, and `commit` skills, ready to trigger
- **`.github/workflows/ci.yml`** — lint + types + tests, with optional Postgres and E2E gating via `dorny/paths-filter`
- **`.github/workflows/review.yml`** — Claude as a PR reviewer (`anthropics/claude-code-action@v1`), posting one consolidated review with inline comments
- **`.github/PULL_REQUEST_TEMPLATE.md`** and **`REVIEW_EXCEPTIONS.md`** — the surrounding workflow scaffolding
- **Stack-specific tooling**:
  - **bun-ts**: `package.json`, `biome.json`, `knip.json`, `tsconfig.json`, husky hooks (pre-commit + post-checkout), reusable utility scripts (`move.ts`, `db-cleanup.ts`)
  - **python**: `pyproject.toml`, `ruff.toml`, `.pre-commit-config.yaml`
- **Plugin + MCP installs** (via `claude` CLI): TypeScript LSP / Pyright LSP, plus optional Chrome DevTools (plugin + MCP server)

## How to run it

No clone required — the init scripts self-bootstrap. They detect when they're running detached, fetch the template tarball from GitHub into a temp dir, run the scaffold, then clean up.

### macOS / Linux / WSL

```sh
# Bootstrap a brand-new project folder
curl -fsSL https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.sh | sh -s -- ~/workspace/my-new-project

# Or layer onto an existing project
cd ~/workspace/my-existing-project
curl -fsSL https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.sh | sh -s -- .
```

### Windows (PowerShell)

PowerShell can't pipe a script and pass arguments in one shot, so save it first:

```powershell
# Bootstrap a brand-new project folder
iwr -useb https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.ps1 -OutFile $env:TEMP\claude-starter-init.ps1
& $env:TEMP\claude-starter-init.ps1 C:\workspace\my-new-project

# Or layer onto an existing project
cd C:\workspace\my-existing-project
iwr -useb https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.ps1 -OutFile $env:TEMP\claude-starter-init.ps1
& $env:TEMP\claude-starter-init.ps1 .
```

> Each run pulls fresh from `main`, so you always get the latest template. If you'd rather keep a permanent checkout (e.g. to hack on the template itself), clone the repo and call `init.sh` / `init.ps1` from there directly — the scripts skip the bootstrap when they find `common/` next to themselves.

The script will prompt for:

1. Project name (default: basename of target directory)
2. One-line description
3. Stack — `bun-ts`, `python`, or `none`
4. Postgres service in CI? (default `n`)
5. E2E tests / Playwright? (default `n`, bun-ts only)
6. Claude PR reviewer workflow? (**default `y`**)
7. Install Chrome DevTools? (default `n`)
8. Install language-server plugin? (default `y`)

### What happens when you say yes to plugins / MCPs

If `claude` is on your `PATH`, the script runs the install commands directly. If not, it prints them so you can run them by hand later.

```sh
# LSP plugin (one of these depending on stack)
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install pyright-lsp@claude-plugins-official

# Chrome DevTools (plugin + MCP — both are needed)
claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp
claude plugin install chrome-devtools-mcp@chrome-devtools-mcp
claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

### After init.sh finishes

Set up secrets if you opted into the PR reviewer or Postgres:

```sh
gh secret set CLAUDE_CODE_OAUTH_TOKEN          # required for review.yml
gh secret set DATABASE_URL                     # if you opted into Postgres
```

Install dependencies:

```sh
# bun-ts
bun install && bun run prepare

# python
uv sync && uvx pre-commit install
```

Then open `CLAUDE.md` and fill in the placeholder sections.

## Layout of this repo

```
claude-starter/
├── README.md                          # this file
├── init.sh                            # POSIX sh scaffolder (macOS/Linux/WSL)
├── init.ps1                           # PowerShell scaffolder (Windows)
├── docs/                              # how-to guides for each piece
│   ├── writing-claude-md.md
│   ├── writing-readme.md
│   ├── writing-skills.md
│   ├── permissions.md
│   ├── hooks.md
│   ├── worktrees.md
│   ├── github-actions.md
│   ├── mcps.md
│   └── plugins.md
├── common/                            # stack-agnostic templates (always copied)
├── stacks/
│   ├── bun-ts/                        # Bun + TypeScript stack overlay
│   └── python/                        # Python (uv + ruff + pytest) stack overlay
└── examples/                          # filled-in CLAUDE.md examples per stack
```

## Read this before extending

The `docs/` folder is where the philosophy lives. If you're going to add a stack, change the skills, or modify the permissions baseline, start there:

- [`docs/writing-claude-md.md`](docs/writing-claude-md.md) — how to structure a CLAUDE.md so the AI loads the right context
- [`docs/writing-readme.md`](docs/writing-readme.md) — README is for humans, CLAUDE.md is for the AI
- [`docs/writing-skills.md`](docs/writing-skills.md) — frontmatter, trigger phrases, when to make a skill vs. add to CLAUDE.md
- [`docs/permissions.md`](docs/permissions.md) — allow-prefix patterns, settings vs. settings.local
- [`docs/hooks.md`](docs/hooks.md) — pre-commit / post-checkout, husky vs. the `pre-commit` framework
- [`docs/worktrees.md`](docs/worktrees.md) — git worktrees for parallel Claude sessions, per-worktree DBs and env files
- [`docs/github-actions.md`](docs/github-actions.md) — the two-workflow pattern (CI + Claude reviewer)
- [`docs/mcps.md`](docs/mcps.md) — registering MCP servers
- [`docs/plugins.md`](docs/plugins.md) — marketplaces, LSP plugins, third-party plugins like Chrome DevTools

## Credit

This template extracts patterns from `yna`, `baked-orm`, and `inkling`. The skills, hook structure, and GitHub workflow patterns are taken near-verbatim from those projects.
