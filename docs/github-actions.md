# GitHub Actions

This template ships two workflows, with two different jobs:

| Workflow | Purpose |
|---|---|
| `.github/workflows/ci.yml` | The deterministic safety net: lint, types, unit tests, optional E2E |
| `.github/workflows/review.yml` | An AI reviewer that posts a single consolidated PR review with inline comments |

They're independent. You can keep one and drop the other. The Claude reviewer is recommended.

## `ci.yml`: the safety net

The bun-ts version of `ci.yml` shipped here is taken from `inkling`. It has four jobs:

1. **`changes`** — uses `dorny/paths-filter` to detect whether anything that affects E2E changed.
2. **`check`** — `bun run check` (Biome + knip + tsc).
3. **`unit-tests`** — `bun test` against an optional Postgres service.
4. **`e2e-tests`** — `bunx playwright test`, gated on the `changes` output.

### The E2E gating trick

E2E tests are slow and brittle. You don't want to run them on a docs-only PR. But if you make `e2e-tests` a `needs:` of the merge requirement, GitHub flags it as "skipped" on docs PRs and the merge is blocked.

The fix: keep `e2e-tests` as a stable required check, but gate every step inside it on a flag. When nothing relevant changed, the job runs in seconds, prints a "skipping" message, and reports success.

```yaml
jobs:
  changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    outputs:
      e2e: ${{ steps.filter.outputs.e2e }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            e2e:
              - 'src/**'
              - 'e2e/**'
              - 'db/migrations/**'
              - 'playwright.config.ts'
              - 'package.json'
              - 'bun.lock'
              - 'tsconfig.json'
              - '.github/workflows/ci.yml'

  e2e-tests:
    needs: changes
    env:
      RUN_E2E: ${{ needs.changes.outputs.e2e }}
    steps:
      - run: echo "Skipping E2E — no relevant files changed"
        if: env.RUN_E2E != 'true'
      - uses: actions/checkout@v4
        if: env.RUN_E2E == 'true'
      - uses: oven-sh/setup-bun@v2
        if: env.RUN_E2E == 'true'
      # ...every step gated on RUN_E2E == 'true'
      - run: bun run test:e2e
        if: env.RUN_E2E == 'true'
```

**Important:** every step in `e2e-tests` needs the `if: env.RUN_E2E == 'true'` guard. If you add a new step and forget the guard, it'll run on every PR.

### Postgres service

Both `unit-tests` and `e2e-tests` use a `services.postgres` block. If you opted into Postgres in `init.sh`, this is included; if not, the service block is removed.

```yaml
services:
  postgres:
    image: postgres:18
    env:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myproject_test
    ports:
      - 5432:5432
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### Bun cache

Don't skip this. `bun install --frozen-lockfile` is fast but the cache makes it instant:

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.bun/install/cache
    key: bun-${{ runner.os }}-${{ hashFiles('bun.lock') }}
    restore-keys: bun-${{ runner.os }}-
- run: bun install --frozen-lockfile
```

### Concurrency

The workflow cancels older runs of the same branch when a new push lands:

```yaml
concurrency:
  group: ci-${{ github.head_ref || github.sha }}
  cancel-in-progress: true
```

This saves CI minutes and gets you faster feedback on the latest commit.

## `review.yml`: the AI reviewer

This is the workflow that turns Claude into a PR reviewer. It runs `anthropics/claude-code-action@v1` with a prompt that:

1. Reads previous review comments and respects "won't fix" / "expected" responses (so you don't get the same comment 4 times).
2. Reads `.github/REVIEW_EXCEPTIONS.md` for project-wide known limitations.
3. Runs the `code-review` skill.
4. Runs the `security-review` skill.
5. Submits everything as a **single** GitHub review with inline comments.

### Why one consolidated review

Posting comments individually via `gh pr review` or `mcp__github_inline_comment` produces a lot of separate notification emails and clutters the PR. One review with N inline comments is the right shape.

### The `jq` trick

`gh api -f` cannot handle nested JSON arrays, so you can't pass an array of comments directly. The workflow uses `jq` to build the JSON payload and pipes it via `--input -`:

```bash
COMMIT_SHA="$(gh api repos/${{ github.repository }}/pulls/${{ github.event.pull_request.number }} --jq '.head.sha')"

jq -n \
  --arg sha "$COMMIT_SHA" \
  --arg body "REVIEW BODY HERE" \
  --arg event "APPROVE" \
  --argjson comments '[
    {"path": "src/example.ts", "line": 42, "body": "Comment on this line."}
  ]' \
  '{commit_id: $sha, body: $body, event: $event, comments: $comments}' \
| gh api repos/${{ github.repository }}/pulls/${{ github.event.pull_request.number }}/reviews --method POST --input -
```

The full version is in `common/.github/workflows/review.yml`. Don't try to rewrite it; the shape is load-bearing.

### Setting up `CLAUDE_CODE_OAUTH_TOKEN`

The workflow needs an OAuth token in the repo's secrets:

```sh
gh secret set CLAUDE_CODE_OAUTH_TOKEN
```

You'll be prompted to paste the value. To generate one, sign in to https://claude.com/code and look for the OAuth token issuance flow under the GitHub Action setup docs (https://docs.claude.com/en/docs/claude-code/github-actions).

### Required permissions

`review.yml` needs these permissions on the workflow job:

```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```

`pull-requests: write` is what lets it post the review. `id-token: write` is for OAuth.

### Concurrency

Just like `ci.yml`, cancel previous review runs when a new push lands:

```yaml
concurrency:
  group: review-${{ github.head_ref }}
  cancel-in-progress: true
```

## `REVIEW_EXCEPTIONS.md`

A markdown file at `.github/REVIEW_EXCEPTIONS.md` lists project-wide known limitations the reviewer should not flag. Things like "we don't have rate limiting yet, that's intentional for now."

The shipped template is empty — you fill it in as you accumulate reviewer false positives. The Claude reviewer reads it on every run.

```markdown
# Review Exceptions

Known limitations that should NOT be flagged as issues in code reviews.
These are intentional gaps, not bugs.

## Authentication & Authorization

(none yet)

## Rate Limiting & DoS

(none yet)
```

## `PULL_REQUEST_TEMPLATE.md`

A standard PR template prompting for Summary, Test plan, and Screenshots. The Claude reviewer will look for these sections.

## What does NOT belong in CI

- **`bun install` without a lockfile.** Always use `--frozen-lockfile`.
- **Hard-coded secrets.** Use `${{ secrets.X }}` and document them in your README.
- **`continue-on-error: true` on the main check.** If you don't care about failures, you don't need the check.
- **A separate workflow per command.** Group related jobs into one workflow file. The two-file split here (`ci.yml` for tests, `review.yml` for AI review) is the right granularity for most projects.
