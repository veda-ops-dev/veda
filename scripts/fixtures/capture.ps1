# capture.ps1 — One-command SERP fixture capture: export snapshots + compute expectations
#
# Usage:
#   pwsh scripts/fixtures/capture.ps1 `
#     -KeywordTargetId <UUID> `
#     -Name <fixture-name> `
#     [-WindowDays 60]
#
# Steps:
#   1. Runs export-serp-fixture.ts  → writes scripts/fixtures/serp/<n>.json
#   2. Runs compute-fixture-expectations.ts → prints expected assertion values
#                                           → writes scripts/fixtures/serp/<n>.expected.json
#
# Notes:
#   - Prefers local node_modules/.bin/tsx when available.
#   - Falls back to `npx tsx` so this can run even if deps aren't fully installed.
#
# Fails early if:
#   - -KeywordTargetId is missing or not a UUID
#   - node not available
#   - export script exits non-zero
#   - fixture file not created after export
#   - expected.json not created after compute step

param(
    [Parameter(Mandatory = $true)]
    [string]$KeywordTargetId,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [int]$WindowDays = 0
)

$ErrorActionPreference = "Stop"

# ── Validate UUID format ───────────────────────────────────────────────────────
if ($KeywordTargetId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$') {
    Write-Host "ERROR: -KeywordTargetId must be a valid UUID" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: node not found on PATH" -ForegroundColor Red
    exit 1
}

# ── Locate repo root + tsx ────────────────────────────────────────────────────
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$localTsx = Join-Path $repoRoot "node_modules\.bin\tsx"

function Invoke-Tsx {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    if (Test-Path $localTsx) {
        & $localTsx @Args
        return
    }

    if (Get-Command "npx" -ErrorAction SilentlyContinue) {
        & npx tsx @Args
        return
    }

    Write-Host "ERROR: Neither local tsx nor npx is available. Install dependencies or ensure npx is on PATH." -ForegroundColor Red
    exit 1
}

# ── Step 1: Export fixture ────────────────────────────────────────────────────
$exportScript = Join-Path $PSScriptRoot "export-serp-fixture.ts"
$fixtureFile  = Join-Path $PSScriptRoot "serp\$Name.json"

Write-Host ""
Write-Host "Step 1: Exporting snapshots from DB..." -ForegroundColor Cyan

$exportArgs = @(
    $exportScript,
    "--keywordTargetId", $KeywordTargetId,
    "--name", $Name
)
if ($WindowDays -gt 0) {
    $exportArgs += "--windowDays"
    $exportArgs += "$WindowDays"
}

Invoke-Tsx -Args $exportArgs
$exportExit = $LASTEXITCODE

if ($exportExit -ne 0) {
    Write-Host "ERROR: export-serp-fixture.ts exited with code $exportExit" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $fixtureFile)) {
    Write-Host "ERROR: Fixture file not created at $fixtureFile" -ForegroundColor Red
    exit 1
}

# ── Step 2: Compute expected values + write expected.json ─────────────────────
$expectScript  = Join-Path $PSScriptRoot "compute-fixture-expectations.ts"
$expectedFile  = Join-Path $PSScriptRoot "serp\$Name.expected.json"

Write-Host ""
Write-Host "Step 2: Computing expected volatility values..." -ForegroundColor Cyan

Invoke-Tsx -Args @(
    $expectScript,
    "--file", $fixtureFile
)
$expectExit = $LASTEXITCODE

if ($expectExit -ne 0) {
    Write-Host "ERROR: compute-fixture-expectations.ts exited with code $expectExit" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $expectedFile)) {
    Write-Host "ERROR: Expected.json not created at $expectedFile" -ForegroundColor Red
    exit 1
}

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Fixture:   scripts/fixtures/serp/$Name.json" -ForegroundColor Gray
Write-Host "  Expected:  scripts/fixtures/serp/$Name.expected.json" -ForegroundColor Gray
