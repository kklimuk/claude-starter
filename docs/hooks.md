# Git Hooks

Git hooks are the safety net that runs *before* code leaves your machine. CI is the safety net for what gets to `main`. You want both, and they should overlap.

This template ships hooks per stack because the *framework* for managing hooks is stack-specific:

- **bun-ts** uses [`husky`](https://typicode.github.io/husky/) — installed as a dev dependency, scripts stored in `.husky/`.
- **python** uses the [`pre-commit`](https://pre-commit.com/) framework — config in `.pre-commit-config.yaml`, hooks installed via `uvx pre-commit install`.

You could mix-and-match (husky works fine for Python projects, `pre-commit` works for JS projects), but the conventions above are what each ecosystem expects.

## What `pre-commit` should do

The pre-commit hook is the local fast-feedback loop. It should catch the things CI would catch but with seconds of latency, not minutes.

The standard set:

1. **Lint + format** the changed files
2. **Type-check** the changed files (or the whole project if your type-checker is fast enough)
3. **Run the unit tests** (or a fast subset)

## Two pre-commit philosophies

### Full-run (simple, slower) — what the template ships

```sh
#!/bin/sh
bun run check && bun test
```

Runs every check on the whole project every commit. Reliable, no edge cases, no script to maintain. On a well-scoped project this stays under a few seconds; on a large one it's slower, and that's the trade-off you accept for not having to think about it. The bun-ts stack ships this variant.

### Staged-files (fast, more code)

```sh
#!/bin/sh
set -e

# Biome on staged TS/JS/JSON only
STAGED_BIOME=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx|js|jsx|json|jsonc)$' || true)
if [ -n "$STAGED_BIOME" ]; then
  bunx biome check --write --staged .
fi

# Knip is project-wide (it has to be — it's looking for unused exports)
bun run lint:dead

# tsc on staged TS files via a temporary tsconfig
STAGED_TS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.tsx?$' || true)
if [ -n "$STAGED_TS" ]; then
  TMPCONFIG=".tsconfig-staged.json"
  trap 'rm -f "$TMPCONFIG"' EXIT
  FILES_JSON=$(echo "$STAGED_TS" | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')
  printf '{"extends":"./tsconfig.json","files":[%s],"include":[]}\n' "$FILES_JSON" > "$TMPCONFIG"
  bunx tsc --noEmit --project "$TMPCONFIG"
fi
```

Lints and types only the staged files, which keeps a commit under a second on most projects. Trade-off: more script complexity, and a few edge cases (a deletion in file A causing a type error in file B is missed by staged-tsc — but CI catches it). Use this variant when the full-run version gets slow enough that you notice it.

## What `post-checkout` is for

`post-checkout` runs whenever you `git checkout` a branch or `git worktree add` a new worktree. It's the right place for "set up the per-worktree environment" tasks:

- Symlinking `.env` files from the git common dir into the worktree
- Creating a per-worktree database (so two worktrees on different branches don't share state)
- Re-installing husky's `_/` directory in the new worktree (a known husky-in-worktrees gotcha)

If you don't already use git worktrees, read [`worktrees.md`](worktrees.md) first — it explains why they're high-leverage for Claude Code workflows and what the post-checkout hook is doing for you.

The bun-ts stack ships `inkling`'s `post-checkout` as a parameterized template. It does all three of the above. The interesting bits:

```sh
# Initialize husky in this worktree (its hooks live in .husky/_/, not committed)
if [ ! -d .husky/_ ]; then
  bunx husky 2>/dev/null || true
fi

# Symlink shared env files from the git common dir
common_dir="$(git rev-parse --git-common-dir)"
for env_file in .env .env.development.local; do
  if [ ! -e "$env_file" ] && [ -f "$common_dir/$env_file" ]; then
    ln -s "$common_dir/$env_file" "$env_file"
  fi
done

# Per-worktree dev + test DBs (only if Postgres is in the project)
if [ ! -e .env.local ]; then
  port=$(( (RANDOM % 4001) + 3000 ))
  wt_name=$(basename "$(pwd)")
  db_name="{{db_prefix}}_$(echo "$wt_name" | tr '-' '_')"
  test_db_name="${db_name}_test"
  bun bake db create "$db_name" 2>/dev/null || true
  DATABASE_URL="postgres://localhost:5432/$db_name" bun bake db migrate up 2>/dev/null || true
  bun bake db create "$test_db_name" 2>/dev/null || true
  DATABASE_URL="postgres://localhost:5432/$test_db_name" bun bake db migrate up 2>/dev/null || true
  cat > .env.local <<EOL
PORT=$port
DATABASE_URL=postgres://localhost:5432/$db_name
EOL
  if [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ]; then
    echo "WORKTREE_NAME=$wt_name" >> .env.local
  fi
  cat > .env.test.local <<EOL
DATABASE_URL=postgres://localhost:5432/$test_db_name
EOL
fi
```

The `{{db_prefix}}_` placeholder is replaced by `init.sh` with your project name when you opt into Postgres. Each worktree gets both a dev DB (`myproject_feature_a`) and a test DB (`myproject_feature_a_test`), so `bun test` inside a worktree doesn't share state with `bun run dev`.

If you don't use worktrees, the env-symlinking and per-DB sections are inert (the hook is a no-op when run from a normal checkout in your only working directory).

## The husky-in-worktrees gotcha

Husky stores its `_/` directory under the worktree, but `git worktree add` doesn't run `prepare`, so a new worktree starts with no hooks. The `post-checkout` hook above auto-initializes them so you don't have to remember.

## Python: `pre-commit` framework

For Python projects, the conventional tool is `pre-commit` (the framework, not the git hook). The bun-ts pattern of writing shell scripts directly in `.husky/` is uncommon in Python land — Python developers expect a `.pre-commit-config.yaml`.

The Python stack in this template ships:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: local
    hooks:
      - id: pytest
        name: pytest
        entry: uv run pytest
        language: system
        pass_filenames: false
        types: [python]
```

Install with:

```sh
uvx pre-commit install
```

## What goes in CI vs hooks

Hooks are about the *commit-level* loop. CI is about the *merge-level* loop. They overlap but each has things the other can't do:

| | Hook | CI |
|---|---|---|
| Speed required | Seconds | Minutes |
| Catches cross-file effects of changes | Sometimes (depends on tool) | Always |
| Runs against a clean checkout | No | Yes |
| Runs E2E tests | No (too slow) | Yes |
| Runs against multiple OS / Node versions | No | Yes |

Don't put E2E tests or full integration suites in hooks. Don't *only* run lint in CI — duplicate it in hooks so you catch it on save.
