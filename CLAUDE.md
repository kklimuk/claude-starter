# claude-starter

A copy-from template for bootstrapping Claude Code projects. The "code" here is two scaffolder scripts (`init.sh`, `init.ps1`) and a tree of template files they copy into a target directory.

This repo eats its own dog food in spirit but **not literally**: do not install the bun-ts or python stack overlays into this repo, and do not add a `.github/workflows/ci.yml` to it. The workflow files under `stacks/` and `common/` are templates that ship to *downstream* projects.

## Stack / runtime overrides

- `init.sh` is **POSIX sh, no bashisms**. Tested under `bash`, `dash`, and `busybox sh`. Don't reach for `[[`, `local`, arrays, `readlink -f`, GNU `sed -i` (without a backup suffix), or process substitution. The existing code already works around several of these — if you change it, run it under `dash` mentally before committing.
- `init.ps1` mirrors `init.sh` step for step and must keep working under both Windows PowerShell 5.1 and pwsh 7+. **Every behavior change to one script must land in the other in the same commit.**
- There is no language toolchain to install in this repo. Edits are shell + markdown + YAML. No `bun install`, no `uv sync`.

## Project structure

```
README.md                           Human-facing intro + how-to-run
CLAUDE.md                           This file
init.sh                             POSIX sh scaffolder (macOS/Linux/WSL)
init.ps1                            PowerShell scaffolder (Windows)
common/                             Stack-agnostic templates — always copied
  CLAUDE.md.template                Skeleton CLAUDE.md for downstream projects
  README.md.template                Skeleton README.md for downstream projects
  .claude/settings.json             Permissions baseline (gh/git/web allowlists, force-push deny)
  .claude/skills/code-review/       PR-scoped review skill
  .claude/skills/codebase-review/   Full-repo audit skill
  .claude/skills/security-review/   Security pass skill
  .claude/skills/commit/            Commit skill
  .github/workflows/review.yml      Claude PR reviewer (anthropics/claude-code-action@v1)
  .github/PULL_REQUEST_TEMPLATE.md  PR template
  .github/REVIEW_EXCEPTIONS.md      Companion to review.yml
stacks/
  bun-ts/                           Bun + TypeScript overlay
    package.json.template           Renamed to package.json at scaffold time
    biome.json, knip.json, tsconfig.json
    .husky/pre-commit, post-checkout
    .github/workflows/ci.yml        Has IF_POSTGRES + IF_E2E conditional blocks
    scripts/move.ts, db-cleanup.ts
  python/                           Python (uv + ruff + pytest) overlay
    pyproject.toml.template         Renamed to pyproject.toml at scaffold time
    ruff.toml, .pre-commit-config.yaml
    .github/workflows/ci.yml        Has IF_POSTGRES conditional block
docs/                               Normative philosophy — read before changing conventions
  writing-claude-md.md              How CLAUDE.md should be structured
  writing-readme.md                 README is for humans, CLAUDE.md is for the AI
  writing-skills.md                 When to make a skill vs. add to CLAUDE.md
  permissions.md                    Allow-prefix patterns, settings vs. settings.local
  hooks.md                          husky vs. pre-commit framework
  worktrees.md                      Per-worktree DBs and env files
  github-actions.md                 The two-workflow pattern (CI + Claude reviewer)
  mcps.md                           Registering MCP servers
  plugins.md                        Marketplaces, LSP plugins, Chrome DevTools
examples/                           Filled-in CLAUDE.md examples per stack
  CLAUDE.md.bun-ts.example
  CLAUDE.md.python.example
```

## Key conventions

- **`.template` suffix** — files are stored with `.template` when their unsuffixed name would be picked up by tooling *in this repo* (e.g. `package.json.template`, `pyproject.toml.template`, `CLAUDE.md.template`, `README.md.template`). The init scripts rename these in place during scaffold. If you add a new file whose unsuffixed name would confuse tooling here, suffix it.
- **Conditional blocks: `# IF_<MARKER>` / `# END_<MARKER>`** — used in `ci.yml` and `.husky/post-checkout` to opt in/out of optional features (`POSTGRES`, `E2E`). Markers are stripped or kept by `strip_block` / `keep_block` (sh) and `Strip-Block` / `Keep-Block` (ps1). If you add a new opt-in feature, add markers in both stacks where relevant *and* the corresponding gate in both init scripts.
- **Placeholder substitution: `{{name}}`** — recognized placeholders are `project_name`, `description`, `db_prefix`, `install_command`, `dev_command`, `test_command`, `check_command`, `stack_overrides`. Both init scripts only run substitution on files containing `{{` (binaries and lockfiles are skipped). If you introduce a new placeholder, add it to **both** scripts' substitution maps.
- **`copy_safe` semantics** — when scaffolding into a non-empty directory ("layer onto existing project" mode), existing files are preserved untouched. New files only. The init scripts detect this mode at start (`NONEMPTY` / `$nonempty`) and skip writes accordingly. Don't add unconditional overwrites.
- **Docs are normative.** If you change a baked-in convention (a permission allowlist, a skill trigger phrase, the ci.yml job structure), update the matching file under `docs/` in the same commit. The `codebase-review` skill checks for doc/template drift.

## init.sh ↔ init.ps1 invariant

These two scripts are the entire program. They must stay in sync on:

1. **Step order** — both follow the same 8 steps: parse args, prompts, copy `common/`, overlay `stacks/<stack>/`, substitute placeholders, strip conditional blocks, opt-out cleanup, install plugins/MCPs, print next steps.
2. **Prompts** — same questions, same defaults, same allowed values. Adding a question to one without the other is a bug.
3. **Files renamed from `.template`** — the lists must match.
4. **Substitution map** — keys must match.
5. **Conditional markers handled** — must match.
6. **Self-bootstrap behavior** — both detect "running detached" by checking whether `common/` sits next to the script. If not, they download the tarball/zipball from `codeload.github.com/kklimuk/claude-starter/{tar.gz,zip}/refs/heads/main` into a temp dir, set the template root to the extracted path, and proceed normally. The "read the docs" line at the end points to the GitHub URL when bootstrapped (the temp dir is about to be cleaned up).

When changing one script, open the other and make the parallel edit before committing.

## Sh portability gotchas already handled

These keep tripping people up — don't undo them:

- `readlink -f` is GNU-only. The script resolves symlinks with a manual loop.
- `mktemp -d` without a template fails on macOS BSD `mktemp` in some configs. The script falls back to `mktemp -d -t claude-starter`.
- `sed -i` needs a backup suffix on BSD sed (macOS). The script uses `sed -i.bak` then `rm -f "$file.bak"`.
- `read` in a `curl | sh` invocation reads from the (now-empty) pipe, not the user. The script reattaches stdin to `/dev/tty` if one is actually openable (file existing isn't enough — sandboxed shells have `/dev/tty` but can't open it; the test is `(: </dev/tty) 2>/dev/null`).
- `find ... -print0` is GNU-only. The script uses plain `find ... | while read` and tolerates the lack of null-delimited safety because none of the paths in this repo contain newlines.

## Testing

There are no automated tests. Smoke-test changes by running the script against a throwaway directory:

```sh
# Local mode (script finds common/ next to itself)
rm -rf /tmp/cs-test && mkdir /tmp/cs-test
./init.sh /tmp/cs-test

# Detached mode (forces the bootstrap path)
cp init.sh /tmp/init-detached.sh
rm -rf /tmp/cs-boot && mkdir /tmp/cs-boot
/tmp/init-detached.sh /tmp/cs-boot
```

For non-trivial changes, also smoke-test:
- Both stacks (`bun-ts`, `python`, `none`)
- Both modes (empty target → "scaffold from scratch"; non-empty target → "layer onto existing project")
- All four opt-ins toggled (`POSTGRES`, `E2E`, reviewer, Chrome) — verify the conditional blocks are stripped/kept correctly in the resulting `ci.yml`

There's no equivalent way to smoke-test `init.ps1` from macOS. If you change it, eyeball the diff against `init.sh` and trust the mirror.

## CI

This repo has no CI. Don't add one. The `ci.yml` files under `stacks/*/` are templates that ship to downstream projects — they should never run against `claude-starter` itself (they reference `bun.lock` / `pyproject.toml` that don't exist here).

The `review.yml` under `common/.github/workflows/` is also a template; it's not active in this repo.
