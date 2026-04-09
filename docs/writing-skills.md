# Writing Skills

Skills are scoped procedures the AI runs when triggered. This template ships four out of the box (`code-review`, `codebase-review`, `security-review`, `commit`). This doc explains how they work and how to write your own.

## What a skill is

A skill is a markdown file at `.claude/skills/<name>/SKILL.md` with frontmatter and a body. Claude Code reads the frontmatter to decide *when* to load the skill, and the body is the procedure the AI follows once triggered.

```markdown
---
name: code-review
description: "PR-scoped code review — reviews what changed on the current branch. Use when the user says 'review', 'code review', 'review my PR', 'review my changes', 'look at my diff', 'what could this break', or any variation of wanting feedback on recent changes. Do NOT use for full codebase audits — that's /codebase-review."
---

# Code Review

...procedure...
```

## Skill vs CLAUDE.md section: when to use which

| Question | Answer |
|---|---|
| Should the AI follow this guidance every turn? | CLAUDE.md |
| Should the AI only follow this when the user asks? | Skill |
| Is this a multi-step procedure with phases? | Skill |
| Is this a single rule or invariant? | CLAUDE.md |

A skill is "an action the AI takes." A CLAUDE.md rule is "a constraint the AI respects."

Examples:

- "Always use Bun, not node" → CLAUDE.md
- "When you commit, group changes by intent and write conventional commit messages" → skill (`commit`)
- "Path aliases are `@client/*`, `@server/*`" → CLAUDE.md
- "When you review code, look for these 12 categories of issues" → skill (`code-review`)

## Frontmatter

Two required fields:

```yaml
---
name: <skill-name>
description: <one-line description with explicit trigger phrases>
---
```

The `name` must match the directory name. The `description` is what the AI uses to decide whether to load the skill, so it has to be specific.

## The trigger-phrase pattern

Lead the description with a one-sentence summary, then explicitly list the user phrases that should trigger it:

> "Use when the user says 'review', 'code review', 'review my PR', 'review my changes', 'look at my diff', 'what could this break', or any variation of wanting feedback on recent changes."

Don't be subtle. The AI is matching the user's phrasing against the description. If you want it to trigger on "look it over," put "look it over" in the description.

If two skills could plausibly match, **disambiguate explicitly**:

> "Do NOT use for full codebase audits — that's /codebase-review."

The four skills shipped in this template all use this pattern. Read their `SKILL.md` files for examples.

## The body: structure

Most skills converge on this structure. Use it unless you have a reason not to:

```markdown
# <Skill Title>

<one-paragraph framing — what this skill is and what it tries to achieve>

## Scope

<how to determine what to operate on — git diff range, file patterns, etc.>

## <The Process>

### Phase 1
### Phase 2
...

## Report Format

<how to present the output to the user>

## What NOT To Do

<failure modes to avoid>
```

The "What NOT To Do" section is critical. Skills without it tend to drift into unhelpful behavior over time.

## Scope: how to figure out what to operate on

For diff-scoped skills (review, commit), start with explicit fallback logic:

```markdown
1. Run `git diff main...HEAD` to get the full diff of this branch against main.
2. If the branch has no commits ahead of main, fall back to `git diff HEAD` (uncommitted) then `git diff --cached` (staged).
3. If no diff is available, ask the user which files to review.
```

This makes the skill robust across worktrees, detached HEADs, and "I haven't committed yet."

## Reading project context

Most skills should read CLAUDE.md before doing real work:

```markdown
## Project Context

Before reviewing, read CLAUDE.md to understand:
- Architecture
- Conventions
- Stack specifics
- Testing setup

This context is critical for catching issues that a generic reviewer would miss.
```

The AI already has CLAUDE.md loaded, but the explicit step makes it think about *which* parts apply to the current task.

## Report format: be specific

If the skill produces a report, prescribe the structure:

```markdown
## Report Format

### Summary
One paragraph: what the PR does and your overall recommendation.

### Issues
For each issue:
- **File and line** — exact location
- **Severity** — 🔴 must fix, 🟡 should fix, 🔵 nit
- **What and why** — the problem and its consequence
- **Suggestion** — specific fix

### What Could Break
Explicit list of risks even if the code is correct.

### Good Stuff
Call out what's done well.
```

Vague instructions ("write a summary") produce vague output. Concrete instructions produce concrete output.

## Iterating after the report

Most skills should describe what happens *after* they produce their output:

```markdown
## After the Review

When the user asks to fix findings, apply fixes in severity order. Run `bun run check` and `bun test` after each fix to verify nothing broke.
```

## What NOT To Do (in skills)

- **Don't write skills the AI already does well by default.** The AI knows how to run a test. It doesn't need a skill called `run-tests`. Skills are for *opinionated procedures*, not basic actions.
- **Don't write a skill where a CLAUDE.md rule would do.** If a one-line constraint solves it, prefer the constraint.
- **Don't make skills depend on each other implicitly.** If `commit` needs `code-review` to have run first, say so.
- **Don't write skill bodies in the imperative third person ("the AI should…").** Write in second person, addressed to the AI. ("Run `git diff main...HEAD`. Read every changed file completely.")
- **Don't put project-specific examples in the body if you can avoid it.** Skills are reused across projects via this template; project specifics belong in CLAUDE.md.

## The four skills shipped here

| Skill | Trigger | What it does |
|---|---|---|
| `code-review` | "review my PR", "review my changes" | PR-scoped review of `git diff main...HEAD` against project conventions |
| `codebase-review` | "codebase review", "architecture review" | Full structural audit by phase (orientation → review → prioritized report → fix) |
| `security-review` | "security review", "OWASP check" | OWASP-style audit of changed files, organized by severity |
| `commit` | "commit", "save my work" | Groups working-tree changes by intent and creates clean commits |

Each one is a worked example of the patterns described above. Read them.
