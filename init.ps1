#!/usr/bin/env pwsh
# claude-starter init.ps1
#
# Scaffold a Claude Code project from this template (Windows / PowerShell).
#
# Usage:
#   path\to\claude-starter\init.ps1 <target-directory>
#
# Or run it directly from GitHub (no clone needed):
#   iwr -useb https://raw.githubusercontent.com/kklimuk/claude-starter/main/init.ps1 -OutFile $env:TEMP\claude-starter-init.ps1
#   & $env:TEMP\claude-starter-init.ps1 <target-directory>
#
# Examples:
#   C:\workspace\claude-starter\init.ps1 C:\workspace\my-new-project
#   cd C:\workspace\my-existing-project; C:\workspace\claude-starter\init.ps1 .
#
# Mirrors init.sh step for step. Tested under PowerShell 5.1 and pwsh 7+.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Target
)

$ErrorActionPreference = "Stop"

# ─── Locate the template root (the dir this script lives in) ───
$TemplateRoot = ""
if ($PSCommandPath) {
    $TemplateRoot = Split-Path -Parent $PSCommandPath
}

# ─── Bootstrap from GitHub if running standalone ───
# If `common\` isn't sitting next to the script, we're running detached
# (e.g. saved to %TEMP% via iwr). Download the zipball into a temp dir.
$Bootstrapped = $false
if (-not $TemplateRoot -or -not (Test-Path (Join-Path $TemplateRoot "common"))) {
    Write-Host "→ Fetching claude-starter template from GitHub..."
    $Bootstrapped = $true
    $bootstrapDir = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-starter-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $bootstrapDir -Force | Out-Null
    $zipPath = Join-Path $bootstrapDir "template.zip"
    try {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://codeload.github.com/kklimuk/claude-starter/zip/refs/heads/main" `
            -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $bootstrapDir -Force
        Remove-Item $zipPath -Force
    } catch {
        Write-Error "Failed to fetch template: $_"
        exit 1
    }
    $TemplateRoot = Join-Path $bootstrapDir "claude-starter-main"
    if (-not (Test-Path (Join-Path $TemplateRoot "common"))) {
        Write-Error "Bootstrap failed: $TemplateRoot\common not found after extract."
        exit 1
    }
}

# ─── Resolve target directory ───
if (-not (Test-Path $Target)) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
}
$TargetAbs = (Resolve-Path $Target).Path

# Detect mode
$nonempty = $false
if (Get-ChildItem -Path $TargetAbs -Force | Select-Object -First 1) {
    $nonempty = $true
}

Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "  claude-starter init"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "  Template: $TemplateRoot"
Write-Host "  Target:   $TargetAbs"
if ($nonempty) {
    Write-Host "  Mode:     layer onto existing project (will not overwrite)"
} else {
    Write-Host "  Mode:     scaffold from scratch"
}
Write-Host ""

# ─── Helpers ───
function Ask {
    param([string]$Question, [string]$Default)
    if ($Default) {
        $prompt = "$Question [$Default]"
    } else {
        $prompt = $Question
    }
    $ans = Read-Host -Prompt $prompt
    if ([string]::IsNullOrWhiteSpace($ans)) {
        return $Default
    }
    return $ans
}

function AskYn {
    param([string]$Question, [string]$Default)
    $ans = Ask "$Question (y/n)" $Default
    if ($ans -match '^(y|Y|yes|YES)$') { return "y" } else { return "n" }
}

# ─── Prompts ───
$DefaultName = Split-Path -Leaf $TargetAbs
$ProjectName = Ask "Project name" $DefaultName
$Description = Ask "One-line description" ""

Write-Host ""
Write-Host "Stack options: bun-ts, python, none"
$Stack = Ask "Stack" "bun-ts"
if ($Stack -notin @("bun-ts", "python", "none")) {
    Write-Error "Unknown stack: $Stack"
    exit 2
}

$UsePostgres = AskYn "Postgres service in CI?" "n"

$UseE2e = "n"
if ($Stack -eq "bun-ts") {
    $UseE2e = AskYn "E2E tests / Playwright?" "n"
}

$UseReviewer = AskYn "Claude PR reviewer workflow?" "y"
$UseChrome = AskYn "Install Chrome DevTools (plugin + MCP)?" "n"
$UseLsp = AskYn "Install language-server plugin?" "y"

# Derived
$DbPrefix = $ProjectName.ToLower() -replace '-', '_'

switch ($Stack) {
    "bun-ts" {
        $InstallCmd = "bun install && bun run prepare"
        $DevCmd = "bun dev"
        $TestCmd = "bun test"
        $CheckCmd = "bun run check"
        $StackOverrides = "Default to using Bun instead of Node.js. Use ``bun <file>`` instead of ``node``, ``bun install`` instead of ``npm install``, ``bunx`` instead of ``npx``. Bun loads .env automatically — don't use dotenv."
    }
    "python" {
        $InstallCmd = "uv sync && uvx pre-commit install"
        $DevCmd = "uv run python -m {{project_name}}"
        $TestCmd = "uv run pytest"
        $CheckCmd = "uv run ruff check . && uv run ruff format --check ."
        $StackOverrides = "Use uv for everything (``uv run``, ``uv add``, ``uv sync``). Don't use pip or venv directly."
    }
    "none" {
        $InstallCmd = "<your install command>"
        $DevCmd = "<your dev command>"
        $TestCmd = "<your test command>"
        $CheckCmd = "<your check command>"
        $StackOverrides = ""
    }
}

Write-Host ""
Write-Host "─── Plan ───"
Write-Host "  Project:    $ProjectName"
Write-Host "  Stack:      $Stack"
Write-Host "  Postgres:   $UsePostgres"
Write-Host "  E2E:        $UseE2e"
Write-Host "  Reviewer:   $UseReviewer"
Write-Host "  Chrome:     $UseChrome"
Write-Host "  LSP:        $UseLsp"
Write-Host ""
$Confirm = AskYn "Proceed?" "y"
if ($Confirm -ne "y") {
    Write-Host "Aborted."
    exit 0
}

# ─── Helpers: copy ───
function Copy-Tree {
    param([string]$SrcRoot, [string]$DstRoot)
    if (-not (Test-Path $SrcRoot)) { return }
    Get-ChildItem -Path $SrcRoot -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($SrcRoot.Length).TrimStart('\', '/')
        $dst = Join-Path $DstRoot $rel
        if (Test-Path $dst) {
            if ($nonempty) {
                Write-Host "  skip (exists): $dst"
                return
            }
        }
        $dstDir = Split-Path -Parent $dst
        if ($dstDir -and -not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        Copy-Item -Path $_.FullName -Destination $dst -Force
        Write-Host "  copy: $dst"
    }
}

# ─── Step 1: git init ───
if (-not (Test-Path (Join-Path $TargetAbs ".git"))) {
    Write-Host ""
    Write-Host "→ Initializing git repo"
    git -C $TargetAbs init -q
}

# ─── Step 2: copy common/ ───
Write-Host ""
Write-Host "→ Copying common/ files"
Copy-Tree (Join-Path $TemplateRoot "common") $TargetAbs

# Rename .template files
foreach ($pair in @(
    @("CLAUDE.md.template", "CLAUDE.md"),
    @("README.md.template", "README.md")
)) {
    $src = Join-Path $TargetAbs $pair[0]
    $dst = Join-Path $TargetAbs $pair[1]
    if ((Test-Path $src) -and (-not (Test-Path $dst))) {
        Move-Item $src $dst
    }
    if (Test-Path $src) { Remove-Item $src -Force }
}

# ─── Step 3: overlay stacks/<stack>/ ───
if ($Stack -ne "none") {
    Write-Host ""
    Write-Host "→ Overlaying stacks/$Stack/ files"
    Copy-Tree (Join-Path $TemplateRoot "stacks\$Stack") $TargetAbs

    if ($Stack -eq "bun-ts") {
        $src = Join-Path $TargetAbs "package.json.template"
        $dst = Join-Path $TargetAbs "package.json"
        if ((Test-Path $src) -and (-not (Test-Path $dst))) { Move-Item $src $dst }
        if (Test-Path $src) { Remove-Item $src -Force }
    }
    if ($Stack -eq "python") {
        $src = Join-Path $TargetAbs "pyproject.toml.template"
        $dst = Join-Path $TargetAbs "pyproject.toml"
        if ((Test-Path $src) -and (-not (Test-Path $dst))) { Move-Item $src $dst }
        if (Test-Path $src) { Remove-Item $src -Force }
    }
}

# ─── Step 4: substitute placeholders ───
Write-Host ""
Write-Host "→ Substituting placeholders"

$substitutions = @{
    '{{project_name}}'    = $ProjectName
    '{{description}}'     = $Description
    '{{db_prefix}}'       = $DbPrefix
    '{{install_command}}' = $InstallCmd
    '{{dev_command}}'     = $DevCmd
    '{{test_command}}'    = $TestCmd
    '{{check_command}}'   = $CheckCmd
    '{{stack_overrides}}' = $StackOverrides
}

Get-ChildItem -Path $TargetAbs -Recurse -File -Force `
    | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\\.venv\\' -and $_.Extension -notin @('.png', '.jpg', '.lock') } `
    | ForEach-Object {
        $content = Get-Content -Raw -Path $_.FullName -ErrorAction SilentlyContinue
        if ($null -eq $content -or $content -notmatch '\{\{') { return }
        foreach ($key in $substitutions.Keys) {
            $content = $content.Replace($key, $substitutions[$key])
        }
        Set-Content -Path $_.FullName -Value $content -NoNewline
    }

# ─── Step 5: strip opted-out conditional blocks ───
Write-Host ""
Write-Host "→ Stripping conditional blocks"

function Strip-Block {
    param([string]$Marker, [string[]]$Files)
    foreach ($f in $Files) {
        if (-not (Test-Path $f)) { continue }
        $lines = Get-Content -Path $f
        $out = New-Object System.Collections.Generic.List[string]
        $skip = $false
        foreach ($line in $lines) {
            if ($line -match "^\s*#\s*IF_$Marker\s*$") { $skip = $true; continue }
            if ($line -match "^\s*#\s*END_$Marker\s*$") { $skip = $false; continue }
            if (-not $skip) { $out.Add($line) }
        }
        Set-Content -Path $f -Value $out
    }
}

function Keep-Block {
    param([string]$Marker, [string[]]$Files)
    foreach ($f in $Files) {
        if (-not (Test-Path $f)) { continue }
        $lines = Get-Content -Path $f | Where-Object { $_ -notmatch "^\s*#\s*(IF|END)_$Marker\s*$" }
        Set-Content -Path $f -Value $lines
    }
}

$ciFile = Join-Path $TargetAbs ".github\workflows\ci.yml"
$hookFile = Join-Path $TargetAbs ".husky\post-checkout"

if ($UsePostgres -eq "y") {
    Keep-Block "POSTGRES" @($ciFile, $hookFile)
} else {
    Strip-Block "POSTGRES" @($ciFile, $hookFile)
}

if ($UseE2e -eq "y") {
    Keep-Block "E2E" @($ciFile)
} else {
    Strip-Block "E2E" @($ciFile)
}

# ─── Step 6: opt-out cleanup ───
if ($UseReviewer -ne "y") {
    Remove-Item (Join-Path $TargetAbs ".github\workflows\review.yml") -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $TargetAbs ".github\REVIEW_EXCEPTIONS.md") -ErrorAction SilentlyContinue
    Write-Host "  removed review.yml + REVIEW_EXCEPTIONS.md"
}

# ─── Step 7: install plugins / MCPs ───
Write-Host ""
Write-Host "→ Installing Claude Code plugins / MCPs"

$claudeBin = Get-Command claude -ErrorAction SilentlyContinue

function RunOrPrint {
    param([string[]]$Args)
    if ($claudeBin) {
        Write-Host "  `$ claude $($Args -join ' ')"
        try {
            Push-Location $TargetAbs
            & claude @Args
        } catch {
            Write-Host "    (failed — continue and run manually if you want)"
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  (claude CLI not on PATH — run this manually:)"
        Write-Host "  `$ claude $($Args -join ' ')"
    }
}

if ($UseLsp -eq "y") {
    switch ($Stack) {
        "bun-ts" { RunOrPrint @("plugin", "install", "typescript-lsp@claude-plugins-official") }
        "python" { RunOrPrint @("plugin", "install", "pyright-lsp@claude-plugins-official") }
    }
}

if ($UseChrome -eq "y") {
    RunOrPrint @("plugin", "marketplace", "add", "ChromeDevTools/chrome-devtools-mcp")
    RunOrPrint @("plugin", "install", "chrome-devtools-mcp")
    RunOrPrint @("mcp", "add", "--scope", "project", "chrome-devtools", "--", "npx", "-y", "chrome-devtools-mcp@latest")
}

# ─── Step 8: Print next steps ───
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host "  ✓ Done. Next steps:"
Write-Host "═══════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "  cd $TargetAbs"
Write-Host ""
switch ($Stack) {
    "bun-ts" { Write-Host "  bun install && bun run prepare" }
    "python" { Write-Host "  uv sync && uvx pre-commit install" }
}
Write-Host ""
Write-Host "  # Open CLAUDE.md and fill in the placeholder sections."
Write-Host ""
if ($UseReviewer -eq "y") {
    Write-Host "  # Set up the GitHub secret for the Claude PR reviewer:"
    Write-Host "  gh secret set CLAUDE_CODE_OAUTH_TOKEN"
    Write-Host ""
}
if ($UsePostgres -eq "y") {
    Write-Host "  # Set up the database secret if your CI Postgres differs from the default:"
    Write-Host "  gh secret set DATABASE_URL"
    Write-Host ""
}
Write-Host "  # Read the docs for any of the pieces you want to customize:"
if ($Bootstrapped) {
    Write-Host "  #   https://github.com/kklimuk/claude-starter/tree/main/docs"
} else {
    Write-Host "  #   $TemplateRoot\docs\"
}
Write-Host ""
