# claude-starter

A copy-from template for bootstrapping Claude Code projects with a consistent setup: CLAUDE.md, skills, hooks, GitHub Actions (including a Claude PR reviewer), permissions, MCPs, and language-server plugins.

It is opinionated. The conventions baked in here come from running Claude Code on three real projects and converging on what worked.

## Getting started

### 1. Read how this template thinks

The scaffolder is the *output*. The *reasoning* lives in [`docs/`](docs/). If you skip the docs, you'll have a working project without knowing why the hooks are split the way they are, why the permissions baseline draws the lines it does, or why there are two GitHub workflows instead of one — and every time you want to bend the template to fit your project, you'll be guessing.

**Read these before you run the scaffolder.** They're short, written as standalone essays, and the interesting thinking lives in them — not in this README:

- [`docs/writing-claude-md.md`](docs/writing-claude-md.md) — how to structure a CLAUDE.md so the AI loads the right context. The single highest-leverage file in any Claude Code project.
- [`docs/writing-readme.md`](docs/writing-readme.md) — why README is for humans and CLAUDE.md is for the AI, and what that means in practice.
- [`docs/writing-skills.md`](docs/writing-skills.md) — frontmatter, trigger phrases, and when a workflow should be a skill vs. a line in CLAUDE.md.
- [`docs/permissions.md`](docs/permissions.md) — the allow-prefix pattern, why there are two settings files, and what belongs in each.
- [`docs/hooks.md`](docs/hooks.md) — pre-commit and post-checkout philosophy, husky vs. the `pre-commit` framework, and the two pre-commit variants.
- [`docs/worktrees.md`](docs/worktrees.md) — why git worktrees are the highest-leverage workflow trick for Claude Code, and how the template sets up per-worktree DBs and env files automatically.
- [`docs/github-actions.md`](docs/github-actions.md) — the two-workflow pattern (CI + Claude reviewer) and why they're separate.
- [`docs/mcps.md`](docs/mcps.md) — what MCP servers are, how to register them, and the security model.
- [`docs/plugins.md`](docs/plugins.md) — marketplaces, LSP plugins, and third-party plugins like Chrome DevTools.

Each doc stands on its own — read the ones relevant to what you're setting up and come back for the rest when you need them. But don't skip them all.

### 2. Run the scaffolder

No clone required — the init scripts self-bootstrap. They detect when they're running detached, fetch the template tarball from GitHub into a temp dir, run the scaffold, then clean up.

<details open>
<summary><b>macOS / Linux / WSL</b></summary>

```sh
# Bootstrap a brand-new project folder
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.sh)" -- ~/workspace/my-new-project

# Or layer onto an existing project
cd ~/workspace/my-existing-project
sh -c "$(curl -fsSL https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.sh)" -- .
```

> Use the `sh -c "$(curl ...)"` form, **not** `curl ... | sh`. The piped form hangs on the first prompt because stdin is the pipe carrying the script.

</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

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

</details>

> Each run pulls fresh from `main`, so you always get the latest template. If you'd rather keep a permanent checkout (e.g. to hack on the template itself), clone the repo and call `init.sh` / `init.ps1` from there directly — the scripts skip the bootstrap when they find `common/` next to themselves.

### 3. Answer the prompts

The script will ask for:

1. Project name (default: basename of target directory)
2. One-line description
3. Stack — `bun-ts`, `python`, or `none`
4. Postgres service in CI? (default `n`)
5. E2E tests / Playwright? (default `n`, bun-ts only)
6. Claude PR reviewer workflow? (**default `y`**)
7. Install Chrome DevTools? (default `n`)
8. Install language-server plugin? (default `y`)

If `claude` is on your `PATH`, the script runs the plugin/MCP install commands directly. If not, it prints them so you can run them by hand later.

### 4. Finish the setup

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

Then open `CLAUDE.md` and fill in the placeholder sections. You're running.

## What you get

The scaffolder drops the following into your target directory:

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

## Repo layout

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

## Credit

This template extracts patterns from `yna`, `baked-orm`, and `inkling`. The skills, hook structure, and GitHub workflow patterns are taken near-verbatim from those projects.
