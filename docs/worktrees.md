# Git Worktrees

A git worktree is a second working directory backed by the same `.git` database. You can have `main` checked out in `~/workspace/myproject` and a feature branch checked out in `~/workspace/myproject-feature` at the same time, with no copying, no stashing, and no `git checkout` dance.

For Claude Code in particular, worktrees are one of the highest-leverage workflow tricks available. This doc explains why and how to use them.

## The problem worktrees solve

You're working on a feature in `main`. Claude is mid-task, has files open, has loaded context. A bug report comes in. You need to:

1. Stash your work (or risk losing it)
2. Switch branches
3. Maybe re-install dependencies (different `package.json`)
4. Reset the dev server
5. Re-load context in Claude
6. Fix the bug
7. Commit, push, check out original branch
8. Unstash, re-load context again

A worktree replaces all of that with `git worktree add`. The original branch stays on disk, the dev server keeps running, your Claude session keeps its context, and you go fix the bug in a *separate directory* with its own checkout, its own dev server, its own Claude session.

## The basics

```sh
# From inside your main repo
git worktree add ../myproject-bugfix bugfix-branch

# Or create a new branch as part of the add
git worktree add ../myproject-feature -b new-feature

# List all worktrees
git worktree list

# Remove a worktree (after merging or abandoning the branch)
git worktree remove ../myproject-bugfix
```

The new worktree is a real, fully-functional checkout. You can `cd` into it, run dev servers, run tests, install dependencies — everything works.

## Why worktrees compound with Claude Code

Three reasons:

1. **Parallel sessions don't fight over files.** Two Claude Code sessions in the same directory will step on each other (the user opens a file in the editor, both AIs try to edit it, one wins). Two sessions in two worktrees are completely isolated. You can run "review my PR" in one worktree while "implement the new feature" runs in another.

2. **Context survives task-switching.** Claude's context window holds everything it's read this session. Throwing away that context to switch branches and then reloading it is expensive — both in tokens and in your patience. With worktrees, the original session keeps everything it knows.

3. **Long-running side investigations don't block the main work.** "Why is this slow? Profile it." That investigation might involve installing tools, generating large datasets, taking flame graphs. Doing it in a worktree means none of that mess touches your main checkout.

## The directory layout that works

```
~/workspace/
├── myproject/                  # main checkout, mostly always on `main`
├── myproject-feature-a/        # worktree on feature-a branch
├── myproject-bugfix/           # worktree on bugfix-123 branch
└── myproject-experiment/       # worktree on a throwaway branch
```

A simple naming convention (`<project>-<branch>` or `<project>-<purpose>`) keeps things scannable in `ls`. The dashes are intentional — the post-checkout hook in this template (see below) parses them to derive a unique database name per worktree.

If you want to keep them out of the parent dir, put them in a `.worktrees/` subfolder of the main repo:

```
~/workspace/myproject/
├── .git/
├── .worktrees/
│   ├── feature-a/
│   └── bugfix-123/
├── src/
└── ...
```

Just add `.worktrees/` to `.gitignore` so they don't show up as untracked. Inkling does it this way.

## The per-worktree environment problem

Worktrees share the `.git` database but **not** the working tree. So:

- Each worktree has its own `node_modules/` (or `.venv/`, etc.)
- Each worktree has its own `.env.local`
- Each worktree has its own running dev server (if any)
- Each worktree needs its own database, or two branches will fight over the same Postgres tables

That last one is the killer. If branch A adds a column to `users` and branch B drops a column from `users`, and both worktrees point at `myproject_dev`, you'll spend an afternoon undoing migration damage.

## How the template solves this

The bun-ts stack's [post-checkout hook](../stacks/bun-ts/.husky/post-checkout) (taken from inkling, parameterized for any project) runs automatically when a new worktree is created. It does three things:

### 1. Re-initialize husky in the new worktree

Husky stores its hook scripts under `.husky/_/`, which is git-ignored, so a brand-new worktree starts with no hooks. The post-checkout hook re-runs `bunx husky` so the new worktree has the same pre-commit / post-checkout hooks as the main one.

```sh
if [ ! -d .husky/_ ]; then
  bunx husky 2>/dev/null || true
fi
```

### 2. Symlink shared env files from the git common dir

The interesting trick: instead of keeping your `.env` in each worktree (where it'd have to be copied or recreated), keep it under `.git/` (which is shared across worktrees) and symlink it into each worktree at checkout time.

```sh
common_dir="$(git rev-parse --git-common-dir)"
for env_file in .env .env.development.local; do
  if [ ! -e "$env_file" ] && [ -f "$common_dir/$env_file" ]; then
    ln -s "$common_dir/$env_file" "$env_file"
  fi
done
```

To set this up, move your real `.env.development.local` into `.git/`:

```sh
mv .env.development.local .git/.env.development.local
ln -s .git/.env.development.local .env.development.local
```

Now every worktree gets the same env file automatically, and if you update it once, every worktree sees the update. (Inkling does exactly this — see its [.env -> .git/.env symlink](../../inkling/.env).)

### 3. Create a per-worktree database

When you opt into Postgres in `init.sh`, the post-checkout hook gets the per-worktree DB block enabled. Each worktree gets:

- A random port between 3000–7000 written to `.env.local`
- A unique database named after the worktree directory: `myproject_feature_a` for a worktree at `~/workspace/myproject-feature-a`

```sh
if [ ! -e .env.local ]; then
  port=$(( (RANDOM % 4001) + 3000 ))
  wt_name=$(basename "$(pwd)")
  db_name="myproject_$(echo "$wt_name" | tr '-' '_')"
  DATABASE_URL="postgres://localhost:5432/$db_name" bun bake db create 2>/dev/null || true
  DATABASE_URL="postgres://localhost:5432/$db_name" bun bake db migrate up 2>/dev/null || true
  cat > .env.local <<EOL
PORT=$port
DATABASE_URL=postgres://localhost:5432/$db_name
EOL
fi
```

So `git worktree add ../myproject-feature-a feature-a` gives you a feature-a checkout with its own dev server port, its own database, all migrations applied, all in one command. No manual setup.

## Cleaning up dead worktree databases

Eventually you'll remove a worktree without dropping its database, and orphaned `myproject_*` databases will pile up. The bun-ts stack ships [`scripts/db-cleanup.ts`](../stacks/bun-ts/scripts/db-cleanup.ts) which:

1. Lists all `myproject_*` databases
2. Lists all current git worktrees
3. Drops the databases that don't have a matching worktree (after confirming with you)

Run it occasionally:

```sh
bun scripts/db-cleanup.ts
```

## Worktree workflow patterns

### Pattern: speculative branch

You want to try a refactor but you're not sure it'll work.

```sh
git worktree add -b try-refactor ../myproject-try
cd ../myproject-try
# ... try the refactor with Claude in a fresh session ...
```

If it works: merge the branch, remove the worktree, drop the DB.
If it doesn't: `git worktree remove ../myproject-try && git branch -D try-refactor`. Original main checkout untouched.

### Pattern: parallel review and implement

Claude is implementing feature A. A teammate's PR drops and you want Claude to review it.

```sh
# In a second terminal, from the main repo:
git fetch origin
git worktree add ../myproject-pr-456 origin/teammate-branch
cd ../myproject-pr-456
claude  # second Claude session, separate from the implementation one
# > review my changes
```

Two Claudes, two contexts, no interference.

### Pattern: hotfix without losing state

Claude is mid-feature in `main` checkout. Production bug.

```sh
# From a second terminal:
git worktree add ../myproject-hotfix -b hotfix-123 origin/main
cd ../myproject-hotfix
claude
# > there's a bug in src/server/auth.ts where ...
```

Fix, push, merge. Original Claude session never noticed.

## Gotchas

- **Submodules don't work great with worktrees.** If your project uses git submodules, test before committing to the worktree workflow.
- **`bun install` is per-worktree.** Each worktree has its own `node_modules/`. Disk usage adds up. Use `bun install --frozen-lockfile` and a shared cache (`~/.bun/install/cache`) to keep installs fast.
- **You can't `git checkout` a branch that's already checked out in another worktree.** Git refuses, which is the point. Move branches with `git worktree move` if you need to.
- **Removing a worktree without `git worktree remove` leaves a stale entry.** If you `rm -rf` a worktree directory by hand, run `git worktree prune` afterward.
- **The post-checkout hook only runs on `git checkout` and `git worktree add`, not on the initial clone.** That's fine — the main checkout's setup happens once, manually, when you first clone.

## Reference

- Git's worktree docs: https://git-scm.com/docs/git-worktree
- The hook in this template: [`stacks/bun-ts/.husky/post-checkout`](../stacks/bun-ts/.husky/post-checkout)
- The DB cleanup script: [`stacks/bun-ts/scripts/db-cleanup.ts`](../stacks/bun-ts/scripts/db-cleanup.ts)
