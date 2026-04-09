#!/bin/sh
# claude-starter init.sh
#
# Scaffold a Claude Code project from this template.
#
# Usage:
#   path/to/claude-starter/init.sh <target-directory>
#
# Or run it directly from GitHub (no clone needed):
#   curl -fsSL https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.sh | sh -s -- <target-directory>
#
# Examples:
#   ~/workspace/claude-starter/init.sh ~/workspace/my-new-project
#   cd ~/workspace/my-existing-project && ~/workspace/claude-starter/init.sh .
#
# POSIX sh, no bashisms. Tested under bash, dash, and busybox sh.

set -eu

# ─── Allow interactive prompts when piped from curl ───
# When invoked via `curl ... | sh`, stdin is the pipe — `read` would never see
# the user. Reattach stdin to the controlling terminal if one is actually
# usable (the file existing isn't enough; sandboxed shells have /dev/tty but
# can't open it).
if [ ! -t 0 ] && (: </dev/tty) 2>/dev/null; then
  exec </dev/tty
fi

# ─── Locate the template root (the dir this script lives in) ───
SCRIPT_PATH="$0"
# Resolve symlinks (without `readlink -f`, which is GNU-only)
while [ -L "$SCRIPT_PATH" ]; do
  link_target="$(readlink "$SCRIPT_PATH")"
  case "$link_target" in
    /*) SCRIPT_PATH="$link_target" ;;
    *)  SCRIPT_PATH="$(dirname "$SCRIPT_PATH")/$link_target" ;;
  esac
done
TEMPLATE_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd || echo "")"

# ─── Bootstrap from GitHub if running standalone ───
# If `common/` isn't sitting next to the script, we're running detached
# (e.g. piped from curl). Download the tarball into a temp dir and use that.
BOOTSTRAPPED=0
if [ -z "$TEMPLATE_ROOT" ] || [ ! -d "$TEMPLATE_ROOT/common" ]; then
  echo "→ Fetching claude-starter template from GitHub..."
  BOOTSTRAPPED=1
  BOOTSTRAP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t claude-starter)"
  trap 'rm -rf "$BOOTSTRAP_DIR"' EXIT INT TERM
  TARBALL_URL="https://codeload.github.com/kklimuk/claude-starter/tar.gz/refs/heads/main"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TARBALL_URL" | tar -xz -C "$BOOTSTRAP_DIR"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$TARBALL_URL" | tar -xz -C "$BOOTSTRAP_DIR"
  else
    echo "Need curl or wget to bootstrap the template." >&2
    exit 1
  fi
  TEMPLATE_ROOT="$BOOTSTRAP_DIR/claude-starter-main"
  if [ ! -d "$TEMPLATE_ROOT/common" ]; then
    echo "Bootstrap failed: $TEMPLATE_ROOT/common not found after extract." >&2
    exit 1
  fi
fi

# ─── Parse arguments ───
if [ $# -lt 1 ]; then
  echo "Usage: $0 <target-directory>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 ~/workspace/my-new-project" >&2
  echo "  $0 ." >&2
  exit 2
fi

TARGET_RAW="$1"
# Resolve to absolute, creating if necessary
mkdir -p "$TARGET_RAW"
TARGET="$(cd "$TARGET_RAW" && pwd)"

# ─── Detect mode: scaffold-new vs layer-onto-existing ───
NONEMPTY=0
if [ -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]; then
  NONEMPTY=1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  claude-starter init"
echo "═══════════════════════════════════════════════════════════"
echo "  Template: $TEMPLATE_ROOT"
echo "  Target:   $TARGET"
if [ "$NONEMPTY" = "1" ]; then
  echo "  Mode:     layer onto existing project (will not overwrite)"
else
  echo "  Mode:     scaffold from scratch"
fi
echo ""

# ─── Helper: prompt with default ───
ask() {
  # ask "Question?" "default" -> echoes the answer
  q="$1"
  d="$2"
  if [ -n "$d" ]; then
    printf "%s [%s]: " "$q" "$d" >&2
  else
    printf "%s: " "$q" >&2
  fi
  read -r ans || ans=""
  if [ -z "$ans" ]; then
    ans="$d"
  fi
  echo "$ans"
}

ask_yn() {
  # ask_yn "Question?" "y" -> echoes y or n
  q="$1"
  d="$2"
  ans="$(ask "$q (y/n)" "$d")"
  case "$ans" in
    y|Y|yes|YES) echo "y" ;;
    *) echo "n" ;;
  esac
}

# ─── Prompts ───
DEFAULT_NAME="$(basename "$TARGET")"
PROJECT_NAME="$(ask "Project name" "$DEFAULT_NAME")"
DESCRIPTION="$(ask "One-line description" "")"

echo ""
echo "Stack options: bun-ts, python, none"
STACK="$(ask "Stack" "bun-ts")"
case "$STACK" in
  bun-ts|python|none) ;;
  *)
    echo "Unknown stack: $STACK" >&2
    exit 2
    ;;
esac

USE_POSTGRES="$(ask_yn "Postgres service in CI?" "n")"

USE_E2E="n"
if [ "$STACK" = "bun-ts" ]; then
  USE_E2E="$(ask_yn "E2E tests / Playwright?" "n")"
fi

USE_REVIEWER="$(ask_yn "Claude PR reviewer workflow?" "y")"
USE_CHROME="$(ask_yn "Install Chrome DevTools (plugin + MCP)?" "n")"
USE_LSP="$(ask_yn "Install language-server plugin?" "y")"

# Derived: snake_case version of project name for db prefix
DB_PREFIX="$(echo "$PROJECT_NAME" | tr '-' '_' | tr '[:upper:]' '[:lower:]')"

# Stack-specific commands referenced in templates
case "$STACK" in
  bun-ts)
    INSTALL_CMD="bun install && bun run prepare"
    DEV_CMD="bun dev"
    TEST_CMD="bun test"
    CHECK_CMD="bun run check"
    STACK_OVERRIDES="Default to using Bun instead of Node.js. Use \`bun <file>\` instead of \`node\`, \`bun install\` instead of \`npm install\`, \`bunx\` instead of \`npx\`. Bun loads .env automatically — don't use dotenv."
    ;;
  python)
    INSTALL_CMD="uv sync && uvx pre-commit install"
    DEV_CMD="uv run python -m {{project_name}}"
    TEST_CMD="uv run pytest"
    CHECK_CMD="uv run ruff check . && uv run ruff format --check ."
    STACK_OVERRIDES="Use uv for everything (\`uv run\`, \`uv add\`, \`uv sync\`). Don't use pip or venv directly."
    ;;
  none)
    INSTALL_CMD="<your install command>"
    DEV_CMD="<your dev command>"
    TEST_CMD="<your test command>"
    CHECK_CMD="<your check command>"
    STACK_OVERRIDES=""
    ;;
esac

echo ""
echo "─── Plan ───"
echo "  Project:    $PROJECT_NAME"
echo "  Stack:      $STACK"
echo "  Postgres:   $USE_POSTGRES"
echo "  E2E:        $USE_E2E"
echo "  Reviewer:   $USE_REVIEWER"
echo "  Chrome:     $USE_CHROME"
echo "  LSP:        $USE_LSP"
echo ""
CONFIRM="$(ask_yn "Proceed?" "y")"
if [ "$CONFIRM" != "y" ]; then
  echo "Aborted."
  exit 0
fi

# ─── Helper: copy a file/tree, respecting NONEMPTY mode ───
copy_safe() {
  src="$1"
  dst="$2"
  if [ -e "$dst" ]; then
    if [ "$NONEMPTY" = "1" ]; then
      echo "  skip (exists): $dst"
      return 0
    fi
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "  copy: $dst"
}

copy_tree() {
  # Copy every file under $1 into $2, preserving structure, using copy_safe per file.
  src_root="$1"
  dst_root="$2"
  if [ ! -d "$src_root" ]; then
    return 0
  fi
  # POSIX find: print every regular file under src_root
  find "$src_root" -type f | while IFS= read -r file; do
    rel="${file#$src_root/}"
    copy_safe "$file" "$dst_root/$rel"
  done
}

# ─── Step 1: git init ───
if [ ! -d "$TARGET/.git" ]; then
  echo ""
  echo "→ Initializing git repo"
  (cd "$TARGET" && git init -q)
fi

# ─── Step 2: copy common/ ───
echo ""
echo "→ Copying common/ files"
copy_tree "$TEMPLATE_ROOT/common" "$TARGET"

# Rename CLAUDE.md.template -> CLAUDE.md and README.md.template -> README.md
if [ -f "$TARGET/CLAUDE.md.template" ] && [ ! -f "$TARGET/CLAUDE.md" ]; then
  mv "$TARGET/CLAUDE.md.template" "$TARGET/CLAUDE.md"
fi
if [ -f "$TARGET/README.md.template" ] && [ ! -f "$TARGET/README.md" ]; then
  mv "$TARGET/README.md.template" "$TARGET/README.md"
fi
# Clean up any leftover .template files we didn't keep
rm -f "$TARGET/CLAUDE.md.template" "$TARGET/README.md.template" 2>/dev/null || true

# ─── Step 3: overlay stacks/<stack>/ ───
if [ "$STACK" != "none" ]; then
  echo ""
  echo "→ Overlaying stacks/$STACK/ files"
  copy_tree "$TEMPLATE_ROOT/stacks/$STACK" "$TARGET"

  # Rename .template files to their final names
  if [ "$STACK" = "bun-ts" ] && [ -f "$TARGET/package.json.template" ] && [ ! -f "$TARGET/package.json" ]; then
    mv "$TARGET/package.json.template" "$TARGET/package.json"
  fi
  if [ "$STACK" = "python" ] && [ -f "$TARGET/pyproject.toml.template" ] && [ ! -f "$TARGET/pyproject.toml" ]; then
    mv "$TARGET/pyproject.toml.template" "$TARGET/pyproject.toml"
  fi
  rm -f "$TARGET/package.json.template" "$TARGET/pyproject.toml.template" 2>/dev/null || true
fi

# ─── Step 4: substitute placeholders ───
echo ""
echo "→ Substituting placeholders"

# Escape strings for sed
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

NAME_E="$(sed_escape "$PROJECT_NAME")"
DESC_E="$(sed_escape "$DESCRIPTION")"
DB_E="$(sed_escape "$DB_PREFIX")"
INSTALL_E="$(sed_escape "$INSTALL_CMD")"
DEV_E="$(sed_escape "$DEV_CMD")"
TEST_E="$(sed_escape "$TEST_CMD")"
CHECK_E="$(sed_escape "$CHECK_CMD")"
OVERRIDES_E="$(sed_escape "$STACK_OVERRIDES")"

# Files we should template-substitute (text only, not binaries)
find "$TARGET" -type f \
  ! -path "*/.git/*" \
  ! -path "*/node_modules/*" \
  ! -path "*/.venv/*" \
  ! -name "*.png" \
  ! -name "*.jpg" \
  ! -name "*.lock" \
  | while IFS= read -r file; do
    # Skip if file doesn't contain a {{ marker — saves a lot of work
    if ! grep -q '{{' "$file" 2>/dev/null; then
      continue
    fi
    sed -i.bak \
      -e "s/{{project_name}}/$NAME_E/g" \
      -e "s/{{description}}/$DESC_E/g" \
      -e "s/{{db_prefix}}/$DB_E/g" \
      -e "s/{{install_command}}/$INSTALL_E/g" \
      -e "s/{{dev_command}}/$DEV_E/g" \
      -e "s/{{test_command}}/$TEST_E/g" \
      -e "s/{{check_command}}/$CHECK_E/g" \
      -e "s/{{stack_overrides}}/$OVERRIDES_E/g" \
      "$file"
    rm -f "$file.bak"
done

# ─── Step 5: strip opted-out conditional blocks ───
echo ""
echo "→ Stripping conditional blocks"

strip_block() {
  # strip_block <marker-name> <files-glob>
  marker="$1"
  shift
  for f in "$@"; do
    [ -f "$f" ] || continue
    awk -v m="$marker" '
      $0 ~ "# IF_" m "$" || $0 ~ "# IF_" m " " { skip=1; next }
      $0 ~ "# END_" m "$" || $0 ~ "# END_" m " " { skip=0; next }
      !skip { print }
    ' "$f" > "$f.new" && mv "$f.new" "$f"
  done
}

keep_block() {
  # keep_block <marker-name> <files-glob>: just removes the marker lines
  marker="$1"
  shift
  for f in "$@"; do
    [ -f "$f" ] || continue
    grep -v -E "^[[:space:]]*# (IF|END)_${marker}$" "$f" > "$f.new" && mv "$f.new" "$f"
  done
}

# CI workflow files for both stacks
CI_FILES="$TARGET/.github/workflows/ci.yml"
HOOK_FILE="$TARGET/.husky/post-checkout"

if [ "$USE_POSTGRES" = "y" ]; then
  keep_block "POSTGRES" $CI_FILES $HOOK_FILE
else
  strip_block "POSTGRES" $CI_FILES $HOOK_FILE
fi

if [ "$USE_E2E" = "y" ]; then
  keep_block "E2E" $CI_FILES
else
  strip_block "E2E" $CI_FILES
fi

# ─── Step 6: opt-out cleanup ───
if [ "$USE_REVIEWER" != "y" ]; then
  rm -f "$TARGET/.github/workflows/review.yml"
  rm -f "$TARGET/.github/REVIEW_EXCEPTIONS.md"
  echo "  removed review.yml + REVIEW_EXCEPTIONS.md"
fi

# Make hook scripts executable
if [ -f "$TARGET/.husky/pre-commit" ]; then chmod +x "$TARGET/.husky/pre-commit"; fi
if [ -f "$TARGET/.husky/post-checkout" ]; then chmod +x "$TARGET/.husky/post-checkout"; fi

# ─── Step 7: install plugins / MCPs ───
echo ""
echo "→ Installing Claude Code plugins / MCPs"

CLAUDE_BIN="$(command -v claude || true)"

run_or_print() {
  if [ -n "$CLAUDE_BIN" ]; then
    echo "  \$ $*"
    (cd "$TARGET" && "$@") || echo "    (failed — continue and run manually if you want)"
  else
    echo "  (claude CLI not on PATH — run this manually:)"
    echo "  \$ $*"
  fi
}

if [ "$USE_LSP" = "y" ]; then
  case "$STACK" in
    bun-ts) run_or_print claude plugin install typescript-lsp@claude-plugins-official ;;
    python) run_or_print claude plugin install pyright-lsp@claude-plugins-official ;;
  esac
fi

if [ "$USE_CHROME" = "y" ]; then
  run_or_print claude plugin marketplace add ChromeDevTools/chrome-devtools-mcp
  run_or_print claude plugin install chrome-devtools-mcp@chrome-devtools-mcp
  run_or_print claude mcp add --scope project chrome-devtools -- npx -y chrome-devtools-mcp@latest
  # Add allow-list entries to settings.json (non-destructive)
  SETTINGS_FILE="$TARGET/.claude/settings.json"
  if [ -f "$SETTINGS_FILE" ] && ! grep -q "mcp__chrome-devtools__list_pages" "$SETTINGS_FILE"; then
    echo "  (you'll want to add mcp__chrome-devtools__* entries to .claude/settings.json — see docs/permissions.md)"
  fi
fi

# ─── Step 8: Print next steps ───
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ Done. Next steps:"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  cd $TARGET"
echo ""
case "$STACK" in
  bun-ts)
    echo "  bun install && bun run prepare"
    ;;
  python)
    echo "  uv sync && uvx pre-commit install"
    ;;
esac
echo ""
echo "  # Open CLAUDE.md and fill in the placeholder sections."
echo ""
if [ "$USE_REVIEWER" = "y" ]; then
  echo "  # Set up the GitHub secret for the Claude PR reviewer:"
  echo "  gh secret set CLAUDE_CODE_OAUTH_TOKEN"
  echo ""
fi
if [ "$USE_POSTGRES" = "y" ]; then
  echo "  # Set up the database secret if your CI Postgres differs from the default:"
  echo "  gh secret set DATABASE_URL"
  echo ""
fi
echo "  # Read the docs for any of the pieces you want to customize:"
if [ "$BOOTSTRAPPED" = "1" ]; then
  echo "  #   https://github.com/kklimuk/claude-starter/tree/main/docs"
else
  echo "  #   $TEMPLATE_ROOT/docs/"
fi
echo ""
