# hammer-provider-smoke.ps1 — Live provider connectivity smoke test
#
# This script tests that the DataForSEO provider integration works end-to-end.
# It is NOT part of the core hammer suite and should be run separately.
#
# Usage:
#   .\hammer-provider-smoke.ps1 [-Base http://localhost:3000] [-ProjectId <id>] [-ProjectSlug <slug>]
#
# Exit codes:
#   0 — provider healthy (201 on confirm=true)
#   1 — provider error (502, credentials missing, rate limit, etc.)
#   2 — internal system error (unexpected status code)
#
# This script does NOT use Hammer-Record or Hammer-Section.
# It is a standalone connectivity check, not an invariant test.

param(
    [string]$Base = "http://localhost:3000",
    [string]$ProjectId,
    [string]$ProjectSlug
)

$Base = $Base.TrimEnd('/')

# ── Build headers ─────────────────────────────────────────────────────────────
$Headers = @{}
if ($ProjectId)   { $Headers["x-project-id"]   = $ProjectId }
if ($ProjectSlug) { $Headers["x-project-slug"] = $ProjectSlug }

$smokeQuery = "provider-smoke-$(Get-Date -Format 'yyyyMMddHHmmss')"
$endpoint   = "$Base/api/seo/serp-snapshot"

Write-Host ""
Write-Host "=== PROVIDER SMOKE TEST ===" -ForegroundColor Yellow
Write-Host "  Endpoint: $endpoint"
Write-Host "  Query:    $smokeQuery"
Write-Host ""

# ── Step 1: Dry-run (confirm=false) ──────────────────────────────────────────
Write-Host "Step 1: Dry-run (confirm=false)..." -NoNewline
try {
    $dryBody = @{ query = $smokeQuery; locale = "en-US"; device = "desktop"; confirm = $false } | ConvertTo-Json -Compress
    $dryResp = Invoke-WebRequest -Uri $endpoint -Method POST -Headers $Headers `
        -Body $dryBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($dryResp.StatusCode -eq 200) {
        $dryData = ($dryResp.Content | ConvertFrom-Json).data
        Write-Host ("  OK (confirm_required=" + $dryData.confirm_required + " cost=" + $dryData.estimated_cost + ")") -ForegroundColor Green
    } else {
        Write-Host ("  FAIL (status=" + $dryResp.StatusCode + ")") -ForegroundColor Red
        exit 2
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red
    exit 2
}

# ── Step 2: Live provider call (confirm=true) ────────────────────────────────
Write-Host "Step 2: Live provider call (confirm=true)..." -NoNewline
try {
    $liveBody = @{ query = $smokeQuery; locale = "en-US"; device = "desktop"; confirm = $true } | ConvertTo-Json -Compress
    $liveResp = Invoke-WebRequest -Uri $endpoint -Method POST -Headers $Headers `
        -Body $liveBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing

    if ($liveResp.StatusCode -eq 201) {
        $liveData = ($liveResp.Content | ConvertFrom-Json).data
        Write-Host ("  OK (id=" + $liveData.id + " query=" + $liveData.query + ")") -ForegroundColor Green
    } elseif ($liveResp.StatusCode -eq 502) {
        $errBody = try { ($liveResp.Content | ConvertFrom-Json) } catch { $null }
        $msg = if ($errBody) { $errBody.message } else { "unknown" }
        Write-Host ("  PROVIDER ERROR: " + $msg) -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "Provider is unavailable. This is NOT a system bug." -ForegroundColor DarkYellow
        Write-Host "Possible causes: credentials missing, rate limit, quota exhausted, provider downtime." -ForegroundColor DarkYellow
        exit 1
    } elseif ($liveResp.StatusCode -eq 200) {
        # Recent-window idempotency replay — provider call was skipped
        Write-Host ("  OK (recent-window replay, no provider call needed)") -ForegroundColor Green
    } else {
        Write-Host ("  UNEXPECTED (status=" + $liveResp.StatusCode + ")") -ForegroundColor Red
        Write-Host ("  Body: " + $liveResp.Content.Substring(0, [Math]::Min(200, $liveResp.Content.Length))) -ForegroundColor Red
        exit 2
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red
    exit 2
}

# ── Step 3: Replay idempotency ───────────────────────────────────────────────
Write-Host "Step 3: Replay (should hit recent-window)..." -NoNewline
try {
    $replayResp = Invoke-WebRequest -Uri $endpoint -Method POST -Headers $Headers `
        -Body $liveBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($replayResp.StatusCode -eq 200 -or $replayResp.StatusCode -eq 201) {
        Write-Host ("  OK (status=" + $replayResp.StatusCode + ")") -ForegroundColor Green
    } else {
        Write-Host ("  WARN (status=" + $replayResp.StatusCode + ")") -ForegroundColor DarkYellow
    }
} catch {
    Write-Host ("  WARN (exception: " + $_.Exception.Message + ")") -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "=== PROVIDER SMOKE: HEALTHY ===" -ForegroundColor Green
exit 0
