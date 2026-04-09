---
name: security-review
description: "Review code for security vulnerabilities. Use when the user says 'security review', 'security audit', 'check for vulnerabilities', 'pentest the code', 'OWASP check', or any variation of wanting a security assessment."
---

# Security Review

Audit changed files for security vulnerabilities, focusing on the OWASP Top 10 and issues specific to the project's stack.

## Scope

Determine the diff to review:

1. Run `git diff main...HEAD --name-only` to get files changed on this branch vs main.
2. If that fails (no `main`, detached worktree, etc.), fall back to `git diff HEAD --name-only` for uncommitted changes, then `git diff --cached --name-only` for staged files.
3. If no diff is available, ask the user which files to review.

Read every changed file completely before starting the review. Read CLAUDE.md first to understand the project's stack and any subsystems with security-sensitive surface area (auth, real-time, payments, file uploads).

## What to Look For

### Injection & Input Handling

- **SQL injection**: Raw SQL with string interpolation instead of parameterized queries. Check for any template literals that build SQL, and verify that database libraries are being used in their parameterized form.
- **Command injection**: User input passed to shell commands (`Bun.$`, `child_process`, `subprocess`, `os.system`) without sanitization.
- **XSS**: User-controlled data rendered as `dangerouslySetInnerHTML`, or reflected into HTML/JS without escaping. Check `contentEditable` fields that accept pasted HTML.
- **Path traversal**: User input used in file paths without validation. Check for `..` traversal.
- **Prototype pollution**: `Object.assign` or spread on user-controlled objects without allowlisting keys.

### Authentication & Authorization

- **Missing auth checks**: Endpoints that read/write data without verifying the caller's identity or org membership.
- **IDOR (Insecure Direct Object Reference)**: Endpoints that accept an ID parameter and return/modify the resource without verifying the caller has access. Particularly dangerous when URL params (like a slug) aren't validated against the actual resource ownership.
- **Privilege escalation**: Actions that should be restricted (delete, move, admin operations) but aren't gated on role/permission.

### Data Exposure

- **Over-fetching**: API responses that include more data than the client needs (e.g., internal IDs, secrets, full document state when only a title is needed).
- **Error leakage**: Stack traces, SQL errors, or internal paths exposed in error responses.
- **Sensitive data in logs**: Passwords, tokens, or PII logged to console.

### Real-time / WebSocket Security

(Only relevant if the project has a WebSocket layer — see CLAUDE.md.)

- **Channel authorization**: Can a client subscribe to any channel by guessing the name? Are channel subscriptions validated against user permissions?
- **Message spoofing**: Can a client broadcast messages to channels they shouldn't have write access to?
- **Payload validation**: Are incoming WebSocket messages validated before processing?

### Denial of Service

- **Unbounded queries**: Endpoints that return all records without pagination or limits.
- **Regex DoS**: User input used in regex patterns without sanitization.
- **Resource exhaustion**: File uploads, large request bodies, or expensive operations without rate limiting or size limits.

### Cryptography & Secrets

- **Hardcoded secrets**: API keys, passwords, or tokens in source code.
- **Weak randomness**: `Math.random()` / `random.random()` used for security-sensitive operations instead of `crypto.randomUUID()` / `secrets.token_*()`.
- **Missing TLS**: WebSocket connections using `ws://` in production contexts.

### Dependencies

- **Known vulnerabilities**: If `bun audit` / `npm audit` / `pip-audit` is available, check for known CVEs.
- **Prototype pollution via deps**: Libraries that merge user input deeply.

## Report Format

Organize findings by severity:

### Critical
Exploitable now with no authentication required. Data loss, unauthorized access, or remote code execution.

### High
Exploitable with some preconditions (e.g., needs authenticated user, specific timing). Privilege escalation, significant data leakage.

### Medium
Defense-in-depth issues. Missing validation that's currently protected by another layer but shouldn't rely on it.

### Low
Hardening recommendations. Not exploitable today but reduce attack surface.

For each finding:
1. **File and line number** — exact location
2. **Vulnerability type** — OWASP category or CWE
3. **Description** — what's wrong and why it matters
4. **Exploit scenario** — how an attacker would use this
5. **Fix** — specific code change to remediate

## What NOT to Do

- Don't flag style issues — that's the code review's job.
- Don't suggest adding WAFs, rate limiters, or infrastructure changes unless the code-level fix is insufficient.
- Don't report theoretical issues that require physical access or compromised infrastructure.
- Don't pile on — prioritize the top findings that matter most.

## After the Report

When the user asks to fix findings, work through them in severity order. Each fix should be minimal and targeted — don't refactor surrounding code. Run the project's check command (`{{check_command}}`) and tests after fixes.
