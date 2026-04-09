# Writing CLAUDE.md

`CLAUDE.md` is the file Claude Code loads automatically into every session in a project. It is the AI's primary onboarding document. Treat it that way.

## CLAUDE.md vs README vs SKILL.md

| File | Audience | When loaded | Purpose |
|---|---|---|---|
| `CLAUDE.md` | The AI | Always (every turn) | Context the AI needs to not break things: stack, conventions, architecture, gotchas |
| `README.md` | Humans | Never (auto) | How a developer gets the project running and contributes |
| `.claude/skills/<name>/SKILL.md` | The AI | Only when the user triggers the skill | A scoped procedure (commit, code review, etc.) |

The temptation is to put everything in CLAUDE.md. Don't. Anything that's only useful when the user explicitly asks for it (like a code review checklist) belongs in a skill.

## What goes in CLAUDE.md

These six sections — in this order — show up in every CLAUDE.md that's worked well across real projects:

### 1. Stack / runtime overrides

Lead with this. The AI's defaults are the wrong tool for many projects. State the override up front.

```markdown
Default to using Bun instead of Node.js.

- Use `bun <file>` instead of `node <file>` or `ts-node <file>`
- Use `bun install` instead of `npm install`
- Bun automatically loads .env, so don't use dotenv.
```

This block is the difference between the AI reaching for the right tool the first time and writing five lines of `node`-shaped code that you have to throw away.

### 2. Annotated source tree

A tight tree of every meaningful file and directory under `src/`, one line each, with a description so terse it forces you to be honest about what each file does. Keep the column narrow so the lines fit.

```markdown
src/
  client/                    React frontend
    index.tsx                React entry point + App + routing
    Layout.tsx               App shell with collapsible sidebar
    Page.tsx                 Page feature (title, editor, collaboration)
  server/                    Bun.serve backend
    index.ts                 Server entry (routes + WebSocket upgrade)
    Cable.ts                 WebSocket hub
```

Why: when the AI is asked to add a feature, this tree lets it pick the right file in one read instead of grepping its way through.

**Maintenance rule:** if you add or rename a file, update the tree in the same commit. A stale tree is worse than no tree — it actively misleads.

### 3. Key conventions

Three to seven lines. The non-obvious rules a teammate would tell you on day one.

```markdown
- **File naming**: PascalCase for components/classes, lowercase for utilities.
- **Feature structure**: `Feature.tsx` sits alongside `Feature/` which holds its internals.
- **Path aliases**: `@client/*`, `@server/*`, `@shared/*`, `@db/*` (defined in tsconfig.json).
- **Inline types**: Don't create named `interface`/`type` declarations for single-use props.
```

Don't put style rules here that the linter already enforces.

### 4. Per-subsystem sections

**Only when nontrivial.** A section per subsystem the AI has to reason about:

- Database (migrations, schema, ORM)
- Server (routing, middleware)
- Real-time (WebSockets, CRDTs)
- Frontend (state management, key libs)
- Background jobs
- Auth

Each section explains the *invariants* — the things that are true and the AI must not violate. Not a tutorial. The bar is "can the AI add a new endpoint without breaking the existing ones" and "can the AI add a new migration without forgetting the trigger."

```markdown
## Database

PostgreSQL 18. ORM is baked-orm.

- Schema is auto-generated at `db/schema.ts` after each migration. Don't edit it manually.
- `create_<table>` migration template includes a shared `set_updated_at()` trigger. Don't drop it in `down`.
```

### 5. Testing

Just the commands and what they cover. No explanation of *why* you have tests.

```markdown
## Testing

```bash
bun test              # Bun unit tests (tests/)
bun run test:e2e      # Playwright E2E tests (e2e/)
bun run check         # Biome lint + knip dead code + tsc type check
```
```

### 6. CI

One paragraph. What runs, when, and where to look. Cross-link the workflow file.

```markdown
## CI

GitHub Actions runs on push to `main` and on pull requests (`.github/workflows/ci.yml`). Three jobs:

- **check** — `bun run check` (Biome + knip + tsc)
- **unit-tests** — `bun test` against a Postgres 18 service
- **e2e-tests** — `bun run test:e2e`, gated on `dorny/paths-filter`
```

## What does NOT belong in CLAUDE.md

- **Code style rules already enforced by the linter.** Trust Biome / Prettier / Ruff. The AI runs them too.
- **Tutorials and "how it works" prose.** That's README material.
- **Triggered procedures** like "how to do a code review" or "how to commit" — those are skills.
- **Anything you'd be embarrassed to read out loud in a review.** If a rule sounds petty, it probably is.
- **Personal preferences with no rationale.** Either include the why or leave it out.

## Maintenance discipline

CLAUDE.md decays. The architecture tree is the most common rot point — you rename a file, forget to update the tree, and a week later the AI can't find anything.

Defenses:

1. **The `codebase-review` skill checks CLAUDE.md accuracy** as part of its documentation-drift pass. Run it occasionally.
2. **The `commit` skill prefers to bundle docs updates with the code change** they describe, so CLAUDE.md updates land in the same commit as the rename.
3. **Treat CLAUDE.md as code.** If a PR touches `src/` structure, the PR should touch CLAUDE.md too. The Claude PR reviewer will flag this if you forget.

## Length

A good CLAUDE.md is 100–400 lines. Beyond that you're putting things in it that should be in skills or in dedicated docs. Below 50 and you probably haven't written down enough conventions.

The three reference projects this template draws from sit at:

- `yna`: ~700 lines (high — pipeline-heavy, lots of subsystem detail)
- `inkling`: ~200 lines (sweet spot)
- `baked-orm`: ~250 lines (sweet spot, library-style)

## Reference

Anthropic's official guidance on writing CLAUDE.md: https://code.claude.com/docs/en/best-practices#write-an-effective-claude-md
