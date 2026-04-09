---
name: codebase-review
description: "Full codebase audit — architecture, structural health, technical debt. Use when the user asks for a 'codebase review', 'architecture review', 'codebase audit', 'full review', 'engineering critique', 'refactoring plan', or 'what would a senior engineer think of this codebase'. Do NOT use for reviewing a PR or branch diff — that's /code-review."
---

# Staff+ Code Review

A systematic process for reviewing codebases the way a senior staff engineer would — focusing on structural health, maintainability, and the kinds of issues that compound over time rather than surface-level style nits.

## Philosophy

A good code review isn't a list of complaints. It's a conversation about where a codebase is headed and whether its current structure supports that trajectory. The best reviews identify patterns (good and bad), not just individual issues. They distinguish between "this is wrong" and "this will hurt you in six months."

Think of it like a doctor's checkup: you're looking for systemic health, not just symptoms. A duplicated function is a symptom; the absence of an extraction pattern is the disease.

## The Review Process

### Phase 1: Orientation

Before critiquing anything, understand the codebase on its own terms.

1. **Read the project documentation** — CLAUDE.md, README, any architecture docs. Understand the stated intent, conventions, and constraints.
2. **Map the architecture** — identify entry points, the module dependency graph, and data flow. Use `Glob` and `Grep` to build a mental model before diving into individual files.
3. **Identify the tech stack and its idioms** — a Bun project has different conventions than a Node project. A Rails-influenced TypeScript codebase will value convention over configuration. A Python+FastAPI service has different bones than a Django app. Meet the code where it is.

### Phase 2: The Review

Read every file in the source directory systematically. For each file, hold these questions in mind:

#### Structural Issues (highest impact)

- **Type/interface duplication**: Is the same shape defined in multiple places? When one definition changes and the others don't, you get subtle runtime bugs that pass type-checking. Look for interfaces or type aliases with identical or near-identical fields across files.
- **Dead code**: Exported functions that nothing imports. Feature flags that are always true. Utility functions written for a refactor that never landed. Dead code is cognitive tax on every future reader. If the project has a dead-code linter (`knip`, `vulture`), run it to get a machine-verified list of unused exports, files, and dependencies — don't rely on manual inspection alone.
- **Missing single source of truth**: When a constant, type, or configuration value is defined in more than one place, which one wins? There should be one canonical location, and everything else should import from it.
- **Pipeline/decomposition clarity**: Is the main orchestration function doing too much? Good code reads like a table of contents — the orchestrator calls well-named functions in sequence, and each function does one thing. Use comment delimiters (`// ─── Section ───`) as a code smell — if you need a comment to separate sections, they should probably be separate functions or files.
- **File/folder decomposition**: When a module grows, follow the sibling file + subfolder convention: `foo.ts` sits alongside `foo/` which holds its implementation details. The file is the public interface; the folder contains internal helpers. Don't let a single file accumulate unrelated responsibilities just because they're in the same domain.
- **Separation of concerns in pipelines**: Pipeline modules that produce results should use generators (or async generators) that yield individual results. The caller (orchestrator) handles I/O, counting, and progress logging — the generator only knows how to process and yield. This keeps analysis/processing logic testable without touching the filesystem or mixing in persistence concerns.

#### Robustness Issues

- **Silent catch blocks**: `catch {}` or `catch { /* ignore */ }` (or `except Exception: pass`) is almost always wrong. Every catch should either rethrow, log with context, or have a comment explaining exactly why swallowing the error is safe. The one legitimate case is when you're parsing untrusted input and non-matching input is expected — and even then, a comment is warranted.
- **Missing guard clauses**: Look for array access (`arr[0]`) or property access on values that could be undefined/empty without a preceding check. Particularly in loops processing external data.
- **Asymmetric error handling**: If two similar code paths handle errors differently, the weaker one will eventually bite. Both should be equally robust.
- **Stale/retry logic**: If the code has retry or recovery mechanisms, are they aggressive enough? Compare similar mechanisms across the codebase — if one path has sophisticated recovery and another has a minimal version, flag it.

#### Maintainability Issues

- **Structural duplication**: Not just copy-paste, but repeated patterns that should be extracted. If two functions follow the same resolve → check → transform → collect pattern with different types, that's a helper waiting to be born.
- **Import hygiene**: Unused imports, inconsistent alias usage, deep relative paths where aliases exist. These are small individually but signal a codebase that isn't being actively maintained.
- **Naming**: Abbreviated names (`cfg`, `ctx`, `mgr`) make code harder to grep and harder to read six months later. Full descriptive names throughout.
- **Definition ordering**: Within files, are the most important things (exports, entry points) at the top, or do you have to scroll past helpers to find the main function?

#### Testing & Verification

- **Test coverage gaps**: Not just "are there tests" but "do the tests cover the interesting cases?" Edge cases, error paths, and schema validation are where bugs hide.
- **Fixture freshness**: If tests use fixtures, do the fixtures match the current data shape? Stale fixtures mean tests pass but don't actually validate current behavior.
- **Schema validation in tests**: Every parsed output should be validated against the schema. This catches drift between what parsers produce and what the rest of the system expects.

#### Documentation Drift

- **CLAUDE.md accuracy**: Compare the architecture section, command examples, data model, and key patterns against the actual code. Flag any commands, file paths, type shapes, or pipeline descriptions that no longer match reality. CLAUDE.md is the primary onboarding document — if it's wrong, every future session starts with a lie.
- **README.md accuracy**: If a README exists, check that setup instructions, usage examples, and feature descriptions reflect the current state. Outdated READMEs are worse than no README — they actively mislead.
- **Rules in `.claude/rules/`** (if present): Read each rule file and verify its guidance still applies. Rules that reference deleted files, renamed functions, or superseded patterns should be updated or removed.
- **Consistency across docs**: If CLAUDE.md says one thing and the code does another, flag the drift. The fix is always to update the docs to match the code, not the other way around.

### Phase 3: Prioritized Report

Present findings organized by impact, not by file. Group them into tiers:

1. **Critical** — will cause bugs or data loss (type mismatches, missing error handling on critical paths)
2. **High** — structural issues that compound (duplication, dead code, missing single source of truth)
3. **Medium** — maintainability concerns (naming, ordering, import hygiene)
4. **Low** — style preferences and minor improvements

For each finding, explain the _why_. Don't just say "this is duplicated" — explain what goes wrong when the definitions drift apart. Don't just say "add a guard clause" — explain what input would cause the crash.

### Phase 4: Iterative Fixing

When the user asks to proceed with fixes, work through them methodically:

1. **Fix in priority order** — critical first, then high, etc.
2. **One concern per edit** — don't combine unrelated fixes in the same edit. This makes it easy to understand each change and revert if needed.
3. **Preserve existing tests** — if a fix removes dead code that has tests, remove the tests too. If a fix changes behavior, update the tests to match.
4. **After each batch of fixes, run the full verification chain:**
   - Lint and auto-fix (the project's configured linter)
   - Run affected tests (targeted) then full suite
   - Type-check
   - Dead code check if available
5. **Update documentation** — after all code fixes are done, update CLAUDE.md, README.md, and any `.claude/rules/` files to reflect the changes. New commands, changed defaults, added pipeline phases, new CLI flags, and modified data models should all be reflected in docs. This is the last step before considering the review complete.
6. **Respect the project's own conventions** — read CLAUDE.md / contributing guides and follow them. Don't introduce new tooling the project doesn't already use. If the project uses `bun test`, don't suggest vitest. If the project uses Biome, don't suggest ESLint.

## What NOT To Do

- **Don't nitpick formatting** — that's the linter's job. If the project has a formatter configured, trust it.
- **Don't suggest rewriting in a different language/framework** — work within the existing tech choices.
- **Don't conflate personal preference with engineering quality** — "I prefer X" is not a review finding. "X prevents Y class of bug" is.
- **Don't pile on** — if there are 30 issues, prioritize the top 7-10 that matter most. The user can always ask for more.
- **Don't suggest adding dependencies for simple things** — especially for testing. Use what's already in the project.

## Adapting to the User

Pay attention to the user's background and experience level. A user who mentions Ruby on Rails experience will appreciate DRY principles, convention over configuration, and "sharp knives" philosophy. A user from the Java world will resonate with interface segregation and dependency inversion. A user who's new to programming needs gentler framing and more explanation of the "why."

The best review meets the developer where they are and uses concepts they already value to motivate improvements.
