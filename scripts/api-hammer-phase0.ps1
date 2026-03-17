# API Hammer — Phase 0 Current Baseline Coordinator
# Usage: .\api-hammer-phase0.ps1 [-Base http://localhost:3000] [-ProjectId <id>] [-ProjectSlug <slug>]
#                                 [-OtherProjectId <id>] [-OtherProjectSlug <slug>]
#
# Purpose:
#   Run the current-reality Phase 0 baseline for the clean repo.
#   This excludes:
#   - legacy mixed-era hammer residue (entities, audits, draft-artifacts, blueprint flows)
#   - known Phase 1 VEDA-brain route gaps
#
# It keeps current observability, content-graph, and persistence lanes so Phase 0 can measure
# real operational safety instead of stale or future-phase failures.

param(
    [string]$Base = "http://localhost:3000",
    [string]$ProjectId,
    [string]$ProjectSlug,
    [string]$OtherProjectId,
    [string]$OtherProjectSlug
)

# ── Parse-check guardrail (catches syntax errors before execution) ─────────────
$_parseTargets = @(
    $MyInvocation.MyCommand.Path
    "$PSScriptRoot\hammer\hammer-lib.ps1"
    "$PSScriptRoot\hammer\hammer-seo.ps1"
    "$PSScriptRoot\hammer\hammer-sil2.ps1"
    "$PSScriptRoot\hammer\hammer-sil3.ps1"
    "$PSScriptRoot\hammer\hammer-sil4.ps1"
    "$PSScriptRoot\hammer\hammer-sil5.ps1"
    "$PSScriptRoot\hammer\hammer-sil6.ps1"
    "$PSScriptRoot\hammer\hammer-sil7.ps1"
    "$PSScriptRoot\hammer\hammer-sil8.ps1"
    "$PSScriptRoot\hammer\hammer-sil8-a1.ps1"
    "$PSScriptRoot\hammer\hammer-sil8-a2.ps1"
    "$PSScriptRoot\hammer\hammer-sil8-b2.ps1"
    "$PSScriptRoot\hammer\hammer-sil8-a3.ps1"
    "$PSScriptRoot\hammer\hammer-sil9.ps1"
    "$PSScriptRoot\hammer\hammer-sil10.ps1"
    "$PSScriptRoot\hammer\hammer-sil11.ps1"
    "$PSScriptRoot\hammer\hammer-sil11-briefing.ps1"
    "$PSScriptRoot\hammer\hammer-feature-history.ps1"
    "$PSScriptRoot\hammer\hammer-feature-volatility.ps1"
    "$PSScriptRoot\hammer\hammer-domain-dominance.ps1"
    "$PSScriptRoot\hammer\hammer-intent-drift.ps1"
    "$PSScriptRoot\hammer\hammer-serp-similarity.ps1"
    "$PSScriptRoot\hammer\hammer-change-classification.ps1"
    "$PSScriptRoot\hammer\hammer-event-timeline.ps1"
    "$PSScriptRoot\hammer\hammer-event-causality.ps1"
    "$PSScriptRoot\hammer\hammer-dataforseo-ingest.ps1"
    "$PSScriptRoot\hammer\hammer-realdata-fixtures.ps1"
    "$PSScriptRoot\hammer\hammer-keyword-overview.ps1"
    "$PSScriptRoot\hammer\hammer-page-command-center.ps1"
    "$PSScriptRoot\hammer\hammer-sil16.ps1"
    "$PSScriptRoot\hammer\hammer-sil17.ps1"
    "$PSScriptRoot\hammer\hammer-sil18.ps1"
    "$PSScriptRoot\hammer\hammer-sil19.ps1"
    "$PSScriptRoot\hammer\hammer-sil19b.ps1"
    "$PSScriptRoot\hammer\hammer-sil20.ps1"
    "$PSScriptRoot\hammer\hammer-sil21.ps1"
    "$PSScriptRoot\hammer\hammer-sil22-24.ps1"
    "$PSScriptRoot\hammer\hammer-content-graph-phase1.ps1"
    "$PSScriptRoot\hammer\hammer-content-graph-intelligence.ps1"
    "$PSScriptRoot\hammer\hammer-w5-persistence.ps1"
)
foreach ($_pt in $_parseTargets) {
    $_tokens = $null
    $_parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_pt, [ref]$_tokens, [ref]$_parseErrors) | Out-Null
    if ($_parseErrors -and $_parseErrors.Count -gt 0) {
        Write-Host ("PARSE ERROR in " + (Split-Path $_pt -Leaf) + ": " + $_parseErrors[0].Message) -ForegroundColor Red
        exit 1
    }
}

$ErrorActionPreference = "Continue"
$Base = $Base.TrimEnd('/')

# ── Shared counters (script: scope so dot-sourced modules write to these) ──────
$script:PassCount = 0
$script:FailCount = 0
$script:SkipCount = 0

# ── Load shared helpers ────────────────────────────────────────────────────────
. "$PSScriptRoot\hammer\hammer-lib.ps1"

# ── Seed shared state ──────────────────────────────────────────────────────────
$Headers      = Get-ProjectHeaders -ProjectIdValue $ProjectId      -ProjectSlugValue $ProjectSlug
$OtherHeaders = Get-ProjectHeaders -ProjectIdValue $OtherProjectId -ProjectSlugValue $OtherProjectSlug

# ── Auto-bootstrap: if no project context supplied, create a hammer project ────
if ($Headers.Count -eq 0) {
    Write-Host "No project context supplied — auto-bootstrapping hammer project..." -ForegroundColor Cyan
    $_autoSlug = "hammer-auto-$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        $_autoBody = @{ name = "Hammer Auto Project"; slug = $_autoSlug; description = "Auto-created by phase0 coordinator" } | ConvertTo-Json
        $_autoResp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $_autoBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($_autoResp.StatusCode -eq 201) {
            $_autoProject = ($_autoResp.Content | ConvertFrom-Json).data
            $ProjectId = $_autoProject.id
            $Headers = Get-ProjectHeaders -ProjectIdValue $ProjectId
            Write-Host ("  Auto-bootstrapped project: id=" + $ProjectId + " slug=" + $_autoSlug) -ForegroundColor Cyan
        } else {
            Write-Host ("  FATAL: auto-bootstrap failed (status=" + $_autoResp.StatusCode + ") body=" + $_autoResp.Content) -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host ("  FATAL: auto-bootstrap exception: " + $_.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

# ── Auto-bootstrap OtherProject for cross-project isolation tests ──────────────
if ($OtherHeaders.Count -eq 0) {
    Write-Host "No other-project context supplied — auto-bootstrapping second project..." -ForegroundColor Cyan
    $_otherSlug = "hammer-other-$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        $_otherBody = @{ name = "Hammer Other Project"; slug = $_otherSlug; description = "Cross-project isolation target" } | ConvertTo-Json
        $_otherResp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $_otherBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($_otherResp.StatusCode -eq 201) {
            $_otherProject = ($_otherResp.Content | ConvertFrom-Json).data
            $OtherProjectId = $_otherProject.id
            $OtherHeaders = Get-ProjectHeaders -ProjectIdValue $OtherProjectId
            Write-Host ("  Auto-bootstrapped other project: id=" + $OtherProjectId + " slug=" + $_otherSlug) -ForegroundColor Cyan
        } else {
            Write-Host ("  WARNING: other-project auto-bootstrap failed (status=" + $_otherResp.StatusCode + "); cross-project tests will SKIP") -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host ("  WARNING: other-project auto-bootstrap exception: " + $_.Exception.Message + "; cross-project tests will SKIP") -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "=== PHASE 0 CURRENT BASELINE ===" -ForegroundColor Yellow
Write-Host "Included: current observability, SIL, content-graph, persistence" -ForegroundColor DarkYellow
Write-Host "Excluded: legacy mixed-era core residue, blueprint flows, known Phase 1 VEDA-brain gaps" -ForegroundColor DarkYellow

# ── Run current Phase 0 modules ────────────────────────────────────────────────
. "$PSScriptRoot\hammer\hammer-seo.ps1"
. "$PSScriptRoot\hammer\hammer-sil2.ps1"
. "$PSScriptRoot\hammer\hammer-sil3.ps1"
. "$PSScriptRoot\hammer\hammer-sil4.ps1"
. "$PSScriptRoot\hammer\hammer-sil5.ps1"
. "$PSScriptRoot\hammer\hammer-sil6.ps1"
. "$PSScriptRoot\hammer\hammer-sil7.ps1"
. "$PSScriptRoot\hammer\hammer-sil8.ps1"
. "$PSScriptRoot\hammer\hammer-sil8-a1.ps1"
. "$PSScriptRoot\hammer\hammer-sil8-a2.ps1"
. "$PSScriptRoot\hammer\hammer-sil8-b2.ps1"
. "$PSScriptRoot\hammer\hammer-sil8-a3.ps1"
. "$PSScriptRoot\hammer\hammer-sil9.ps1"
. "$PSScriptRoot\hammer\hammer-sil10.ps1"
. "$PSScriptRoot\hammer\hammer-sil11.ps1"
. "$PSScriptRoot\hammer\hammer-sil11-briefing.ps1"
. "$PSScriptRoot\hammer\hammer-feature-history.ps1"
. "$PSScriptRoot\hammer\hammer-feature-volatility.ps1"
. "$PSScriptRoot\hammer\hammer-domain-dominance.ps1"
. "$PSScriptRoot\hammer\hammer-intent-drift.ps1"
. "$PSScriptRoot\hammer\hammer-serp-similarity.ps1"
. "$PSScriptRoot\hammer\hammer-change-classification.ps1"
. "$PSScriptRoot\hammer\hammer-event-timeline.ps1"
. "$PSScriptRoot\hammer\hammer-event-causality.ps1"
. "$PSScriptRoot\hammer\hammer-dataforseo-ingest.ps1"
. "$PSScriptRoot\hammer\hammer-realdata-fixtures.ps1"
. "$PSScriptRoot\hammer\hammer-keyword-overview.ps1"
. "$PSScriptRoot\hammer\hammer-page-command-center.ps1"
. "$PSScriptRoot\hammer\hammer-sil16.ps1"
. "$PSScriptRoot\hammer\hammer-sil17.ps1"
. "$PSScriptRoot\hammer\hammer-sil18.ps1"
. "$PSScriptRoot\hammer\hammer-sil19.ps1"
. "$PSScriptRoot\hammer\hammer-sil19b.ps1"
. "$PSScriptRoot\hammer\hammer-sil20.ps1"
. "$PSScriptRoot\hammer\hammer-sil21.ps1"
. "$PSScriptRoot\hammer\hammer-sil22-24.ps1"
. "$PSScriptRoot\hammer\hammer-content-graph-phase1.ps1"
. "$PSScriptRoot\hammer\hammer-content-graph-intelligence.ps1"
. "$PSScriptRoot\hammer\hammer-w5-persistence.ps1"

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== PHASE 0 SUMMARY ===" -ForegroundColor Yellow
Write-Host ("PASS: " + $script:PassCount) -ForegroundColor Green
Write-Host ("FAIL: " + $script:FailCount) -ForegroundColor Red
Write-Host ("SKIP: " + $script:SkipCount) -ForegroundColor DarkYellow

if ($script:FailCount -eq 0) { exit 0 } else { exit 1 }
