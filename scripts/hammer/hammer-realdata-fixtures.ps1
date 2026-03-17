# hammer-realdata-fixtures.ps1 — Value-correctness tests using seeded fixture data
#
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base,
# Hammer-Section, Hammer-Record.
#
# Strategy:
#   1. Load expected values from scripts/fixtures/serp/volatility-case-1.expected.json
#      (written by capture.ps1 / compute-fixture-expectations.ts — no manual copying).
#   2. RF-REPLAY: Validate computeVolatility() directly against expected.json
#      via scripts/fixtures/replay-fixture.ts (no DB, no API).
#   3. Seed the fixture into DB via seed-serp-fixture.ts.
#   4. Parse the seeded projectId + keywordTargetId from stdout.
#   5. Hit GET /api/seo/keyword-targets/{id}/volatility with fixture project headers.
#   6. Assert value-level invariants against the loaded expectations.
#   7. Assert risk-attribution-summary invariants + determinism.
#
# Fixture file:   scripts/fixtures/serp/volatility-case-1.json
# Expected file:  scripts/fixtures/serp/volatility-case-1.expected.json
# Seed script:    scripts/fixtures/seed-serp-fixture.ts
# Replay script:  scripts/fixtures/replay-fixture.ts
#
# SKIP conditions (logged clearly, not FAIL):
#   - Node.js / tsx not on PATH
#   - Fixture file or expected.json missing
#   - Replay script not present
#   - Seed script exits non-zero (e.g. DB not reachable)
#
# FAIL conditions:
#   - expected.json present but malformed
#   - Fixture file present but seed produces no projectId
#   - Endpoint returns non-200
#   - Value invariants violated

Hammer-Section "REALDATA FIXTURE HARNESS"

$_fixtureName  = "volatility-case-1"
$_fixtureFile  = Join-Path $PSScriptRoot "..\fixtures\serp\$_fixtureName.json"
$_expectedFile = Join-Path $PSScriptRoot "..\fixtures\serp\$_fixtureName.expected.json"
$_seedScript   = Join-Path $PSScriptRoot "..\fixtures\seed-serp-fixture.ts"
$_replayScript = Join-Path $PSScriptRoot "..\fixtures\replay-fixture.ts"

# ── RF-EXP: Load expected values from expected.json ───────────────────────────
$_exp              = $null   # expectations object; $null = SKIP all value tests
$_fixtureProjectId = $null
$_fixtureKtId      = $null
$_fixtureLocale    = "en-US"
$_fixtureDevice    = "desktop"
$_fixtureHeaders   = $null

try {
    Write-Host "Testing: RF-EXP  load volatility-case-1.expected.json" -NoNewline

    if (-not (Test-Path $_expectedFile)) {
        Write-Host ("  FAIL (expected.json not found: " + $_expectedFile + ")") -ForegroundColor Red
        Write-Host "       Run: pwsh scripts/fixtures/capture.ps1 -KeywordTargetId YOUR_UUID_HERE -Name volatility-case-1" -ForegroundColor DarkGray
        Hammer-Record FAIL
    } else {
        $raw = Get-Content $_expectedFile -Raw | ConvertFrom-Json
        # Validate required fields are present
        $reqFields = @("sampleSize","snapshotCount","volatilityScore","rankVolatilityComponent",
                       "aiOverviewComponent","featureVolatilityComponent","volatilityRegime","aiOverviewChurn")
        # Use property existence check (ConvertFrom-Json returns PSCustomObject)
        $props   = $raw | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $missing = $reqFields | Where-Object { $props -notcontains $_ }
        if ($missing.Count -gt 0) {
            Write-Host ("  FAIL (expected.json missing fields: " + ($missing -join ", ") + ")") -ForegroundColor Red
            Hammer-Record FAIL
        } else {
            $_exp = $raw
            Write-Host ("  PASS (sampleSize=" + $_exp.sampleSize + " snapshotCount=" + $_exp.snapshotCount +
                         " volatilityScore=" + $_exp.volatilityScore + " regime=" + $_exp.volatilityRegime + ")") -ForegroundColor Green
            Hammer-Record PASS
        }
    }
} catch {
    Write-Host ("  FAIL (exception loading expected.json: " + $_.Exception.Message + ")") -ForegroundColor Red
    Hammer-Record FAIL
}

# ── RF-REPLAY: replay-fixture.ts validates computeVolatility() w/o DB/API ─────
try {
    Write-Host "Testing: RF-REPLAY  replay-fixture validates computeVolatility (no DB/API)" -NoNewline

    if (-not (Test-Path $_replayScript)) {
        Write-Host "  SKIP (replay-fixture.ts not found)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (-not (Test-Path $_fixtureFile) -or -not (Test-Path $_expectedFile)) {
        Write-Host "  SKIP (fixture or expected.json missing)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Host "  SKIP (node not on PATH)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        # Resolve tsx — prefer local Windows .cmd shim, then .ps1, then npx tsx
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
        $tsxCmd   = Join-Path $repoRoot "node_modules\.bin\tsx.cmd"
        $tsxPs1   = Join-Path $repoRoot "node_modules\.bin\tsx.ps1"

        $replayArgs     = @("$_replayScript", "--name", "$_fixtureName")
        $replaySkipped  = $false
        $replayOutput   = $null
        $replayExitCode = 0

        if (Test-Path $tsxCmd) {
            $replayOutput   = & $tsxCmd @replayArgs 2>&1
            $replayExitCode = $LASTEXITCODE
        } elseif (Test-Path $tsxPs1) {
            $replayOutput   = & $tsxPs1 @replayArgs 2>&1
            $replayExitCode = $LASTEXITCODE
        } elseif (Get-Command "npx" -ErrorAction SilentlyContinue) {
            $replayOutput   = & "npx" "tsx" @replayArgs 2>&1
            $replayExitCode = $LASTEXITCODE
        } else {
            Write-Host "  SKIP (tsx.cmd not found and npx not available; run npm install)" -ForegroundColor DarkYellow
            Hammer-Record SKIP
            $replaySkipped = $true
        }

        if (-not $replaySkipped) {
            # replay-fixture.ts prints exactly one word to stdout: PASS or FAIL.
            $out = ($replayOutput | Out-String).Trim()
            if ($replayExitCode -eq 0 -and $out -eq "PASS") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (exit=" + $replayExitCode + ")") -ForegroundColor Red
                if ($out) { Write-Host $out -ForegroundColor DarkGray }
                Hammer-Record FAIL
            }
        }
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# ── RF-SEED: Seed fixture data via tsx ────────────────────────────────────────
try {
    Write-Host "Testing: RF-SEED  seed volatility-case-1 fixture into DB" -NoNewline

    if (-not (Test-Path $_fixtureFile)) {
        Write-Host ("  FAIL (fixture file not found: " + $_fixtureFile + ")") -ForegroundColor Red; Hammer-Record FAIL
    } elseif (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
        Write-Host "  SKIP (node not on PATH)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        # Resolve tsx — prefer local Windows .cmd shim, then .ps1, then npx tsx
        $repoRoot    = Resolve-Path (Join-Path $PSScriptRoot "..\..") 
        $tsxCmd      = Join-Path $repoRoot "node_modules\.bin\tsx.cmd"
        $tsxPs1      = Join-Path $repoRoot "node_modules\.bin\tsx.ps1"
        $seedArgs    = @("$_seedScript", "--file", "$_fixtureFile")
        $seedSkipped = $false

        if (Test-Path $tsxCmd) {
            $seedOutput   = & $tsxCmd @seedArgs 2>&1
            $seedExitCode = $LASTEXITCODE
        } elseif (Test-Path $tsxPs1) {
            $seedOutput   = & $tsxPs1 @seedArgs 2>&1
            $seedExitCode = $LASTEXITCODE
        } elseif (Get-Command "npx" -ErrorAction SilentlyContinue) {
            $seedOutput   = & "npx" "tsx" @seedArgs 2>&1
            $seedExitCode = $LASTEXITCODE
        } else {
            Write-Host "  SKIP (tsx.cmd not found and npx not available; run npm install)" -ForegroundColor DarkYellow
            Hammer-Record SKIP
            $seedSkipped = $true
        }

        if (-not $seedSkipped) {
            if ($seedExitCode -ne 0) {
                Write-Host ("  FAIL (seed-serp-fixture exited " + $seedExitCode + ")") -ForegroundColor Red
                Write-Host ($seedOutput | Out-String).Trim() -ForegroundColor DarkGray
                Hammer-Record FAIL
            } else {
                foreach ($line in $seedOutput) {
                    if ($line -match "^FIXTURE_PROJECT_ID:\s*([0-9a-f\-]{36})") {
                        $_fixtureProjectId = $Matches[1].Trim()
                    }
                    if ($line -match '^FIXTURE_KT_ID:\s*([0-9a-f\-]{36})\s+query="([^"]+)"\s+locale="([^"]+)"\s+device="([^"]+)"') {
                        $_fixtureKtId   = $Matches[1].Trim()
                        $_fixtureLocale = $Matches[3].Trim()
                        $_fixtureDevice = $Matches[4].Trim()
                    }
                }

                if (-not $_fixtureProjectId -or -not $_fixtureKtId) {
                    Write-Host "  FAIL (could not parse FIXTURE_PROJECT_ID or FIXTURE_KT_ID from seed output)" -ForegroundColor Red
                    Write-Host ($seedOutput | Out-String).Trim() -ForegroundColor DarkGray
                    Hammer-Record FAIL
                } else {
                    $_fixtureHeaders = @{ "x-project-id" = $_fixtureProjectId }
                    Write-Host ("  PASS (projectId=" + $_fixtureProjectId + " ktId=" + $_fixtureKtId + ")") -ForegroundColor Green
                    Hammer-Record PASS
                }
            }
        }
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# ── RF-VOL-A: volatility endpoint returns 200 + required fields ───────────────
try {
    Write-Host "Testing: RF-VOL-A  GET volatility returns 200 + all required fields" -NoNewline
    if (-not $_fixtureHeaders) {
        Write-Host "  SKIP (fixture not seeded)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url  = Build-Url -Path "/api/seo/keyword-targets/$_fixtureKtId/volatility"
        $resp = Invoke-WebRequest -Uri $url -Method GET -Headers $_fixtureHeaders `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing

        if ($resp.StatusCode -ne 200) {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL
        } else {
            $d        = ($resp.Content | ConvertFrom-Json).data
            $props    = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @(
                "keywordTargetId","query","locale","device",
                "sampleSize","snapshotCount","volatilityScore",
                "rankVolatilityComponent","aiOverviewComponent","featureVolatilityComponent",
                "aiOverviewChurn","averageRankShift","maxRankShift","featureVolatility",
                "maturity","volatilityRegime","computedAt"
            )
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# (rest of file unchanged)
