# API Hammer — Coordinator
# Usage: .\api-hammer.ps1 [-Base http://localhost:3000] [-ProjectId <id>] [-ProjectSlug <slug>]
#                          [-OtherProjectId <id>] [-OtherProjectSlug <slug>]

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
    "$PSScriptRoot\hammer\hammer-core.ps1"
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
    "$PSScriptRoot\hammer\hammer-veda-brain-phase1.ps1"
    "$PSScriptRoot\hammer\hammer-project-bootstrap.ps1"
    "$PSScriptRoot\hammer\hammer-veda-brain-proposals.ps1"
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

# ── Load shared helpers + sentinel registry ────────────────────────────────────
. "$PSScriptRoot\hammer\hammer-lib.ps1"

# ── Seed shared state ──────────────────────────────────────────────────────────
$Headers      = Get-ProjectHeaders -ProjectIdValue $ProjectId      -ProjectSlugValue $ProjectSlug
$OtherHeaders = Get-ProjectHeaders -ProjectIdValue $OtherProjectId -ProjectSlugValue $OtherProjectSlug

# ── Auto-bootstrap: if no project context supplied, create a hammer project ────
# Mutation endpoints require explicit project context (X-Project-Id or X-Project-Slug).
# When the operator omits -ProjectId/-ProjectSlug, the coordinator creates a
# disposable project so all mutation suites have valid headers.
if ($Headers.Count -eq 0) {
    Write-Host "No project context supplied — auto-bootstrapping hammer project..." -ForegroundColor Cyan
    $_autoSlug = "hammer-auto-$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        $_autoBody = @{ name = "Hammer Auto Project"; slug = $_autoSlug; description = "Auto-created by api-hammer coordinator" } | ConvertTo-Json
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
            # Non-fatal: cross-project tests are gated on ($OtherHeaders.Count -gt 0)
        }
    } catch {
        Write-Host ("  WARNING: other-project auto-bootstrap exception: " + $_.Exception.Message + "; cross-project tests will SKIP") -ForegroundColor DarkYellow
    }
}

$_seed = Try-GetJson -Url "$Base/api/entities?limit=1" -RequestHeaders $Headers
$entityId = $null
if ($_seed -and $_seed.data -and $_seed.data.Count -gt 0) { $entityId = $_seed.data[0].id }

# ── Run modules ────────────────────────────────────────────────────────────────
. "$PSScriptRoot\hammer\hammer-core.ps1"
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
. "$PSScriptRoot\hammer\hammer-veda-brain-phase1.ps1"
. "$PSScriptRoot\hammer\hammer-project-bootstrap.ps1"
. "$PSScriptRoot\hammer\hammer-veda-brain-proposals.ps1"
. "$PSScriptRoot\hammer\hammer-w5-persistence.ps1"

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Yellow
Write-Host ("PASS: " + $script:PassCount) -ForegroundColor Green
Write-Host ("FAIL: " + $script:FailCount) -ForegroundColor Red
Write-Host ("SKIP: " + $script:SkipCount) -ForegroundColor DarkYellow

if ($script:FailCount -eq 0) { exit 0 } else { exit 1 }
