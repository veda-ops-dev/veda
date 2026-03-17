# hammer-sil7.ps1 — SIL-7 (Volatility Attribution Components)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Depends on SIL-3 fixtures: reuses $s3KtId (the main SIL-3 KeywordTarget with
# 21+ snapshots). SIL-3 module must run before this module in the coordinator.
#
# Tests added here (VL-SIL7-*):
#   A — component fields present on /volatility response
#   B — component values in [0, 100]
#   C — sum check: abs(sum - volatilityScore) <= 0.02
#   D — determinism: two calls return identical component values
#   E — zero state: sampleSize=0 → all components 0
#   F — component fields present on /volatility-alerts items
#   G — alerts sum check on first item
#   H — alerts component determinism

Hammer-Section "SIL-7 TESTS (VOLATILITY ATTRIBUTION COMPONENTS)"

# ── SIL7-A: component fields present on /volatility ──────────────────────────
try {
    Write-Host "Testing: SIL-7 /volatility has attribution component fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("rankVolatilityComponent", "aiOverviewComponent", "featureVolatilityComponent")
            $missing  = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-B: component values in [0, 100] ─────────────────────────────────────
try {
    Write-Host "Testing: SIL-7 /volatility component values in [0, 100]" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d    = ($resp.Content | ConvertFrom-Json).data
            $rvc  = [double]$d.rankVolatilityComponent
            $aoc  = [double]$d.aiOverviewComponent
            $fvc  = [double]$d.featureVolatilityComponent
            $inRange = ($rvc -ge 0 -and $rvc -le 100) -and
                       ($aoc -ge 0 -and $aoc -le 100) -and
                       ($fvc -ge 0 -and $fvc -le 100)
            if ($inRange) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (rvc=" + $rvc + " aoc=" + $aoc + " fvc=" + $fvc + ", all must be in [0,100])") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-C: sum check — abs(rvc + aoc + fvc - volatilityScore) <= 0.02 ───────
try {
    Write-Host "Testing: SIL-7 /volatility component sum within 0.02 of volatilityScore" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d    = ($resp.Content | ConvertFrom-Json).data
            $rvc  = [double]$d.rankVolatilityComponent
            $aoc  = [double]$d.aiOverviewComponent
            $fvc  = [double]$d.featureVolatilityComponent
            $vs   = [double]$d.volatilityScore
            $diff = [Math]::Abs($rvc + $aoc + $fvc - $vs)
            if ($diff -le 0.02) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sum=" + ($rvc + $aoc + $fvc) + " score=" + $vs + " diff=" + $diff + ", expected diff<=0.02)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-D: determinism — two calls return identical component values ─────────
try {
    Write-Host "Testing: SIL-7 /volatility components deterministic (two calls match)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base/api/seo/keyword-targets/$s3KtId/volatility"
        $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $match = (
                $d1.rankVolatilityComponent    -eq $d2.rankVolatilityComponent    -and
                $d1.aiOverviewComponent        -eq $d2.aiOverviewComponent        -and
                $d1.featureVolatilityComponent -eq $d2.featureVolatilityComponent
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else {
                Write-Host ("  FAIL (rvc1=" + $d1.rankVolatilityComponent + " rvc2=" + $d2.rankVolatilityComponent + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-E: zero state — sampleSize=0 keyword has all components = 0 ─────────
# Use a fresh keyword with no snapshots.
$s7ZeroRunId = (Get-Date).Ticks
$s7ZeroQuery = "sil7-zero $s7ZeroRunId"
$s7ZeroKtId  = $null

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($s7ZeroQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $s7ZeroKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $s7ZeroQuery } | Select-Object -First 1).id
    }
} catch {}

try {
    Write-Host "Testing: SIL-7 /volatility sampleSize=0 -> components all 0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s7ZeroKtId)) {
        Write-Host "  SKIP (zero-state KT creation failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s7ZeroKtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $allZero = ($d.sampleSize -eq 0) -and
                       ([double]$d.rankVolatilityComponent -eq 0) -and
                       ([double]$d.aiOverviewComponent -eq 0) -and
                       ([double]$d.featureVolatilityComponent -eq 0)
            if ($allZero) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " rvc=" + $d.rankVolatilityComponent + " aoc=" + $d.aiOverviewComponent + " fvc=" + $d.featureVolatilityComponent + ", expected all 0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-F: component fields present on /volatility-alerts items ──────────────
try {
    Write-Host "Testing: SIL-7 /volatility-alerts items have attribution component fields" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d.items -and $d.items.Count -gt 0) {
            $item     = $d.items[0]
            $iProps   = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("rankVolatilityComponent", "aiOverviewComponent", "featureVolatilityComponent")
            $missing  = $required | Where-Object { $iProps -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no active alert items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-G: alerts sum check on first item ────────────────────────────────────
try {
    Write-Host "Testing: SIL-7 /volatility-alerts first item component sum within 0.02 of volatilityScore" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d.items -and $d.items.Count -gt 0) {
            $item = $d.items[0]
            $rvc  = [double]$item.rankVolatilityComponent
            $aoc  = [double]$item.aiOverviewComponent
            $fvc  = [double]$item.featureVolatilityComponent
            $vs   = [double]$item.volatilityScore
            $diff = [Math]::Abs($rvc + $aoc + $fvc - $vs)
            if ($diff -le 0.02) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sum=" + ($rvc + $aoc + $fvc) + " score=" + $vs + " diff=" + $diff + ", expected diff<=0.02)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL7-H: alerts component determinism ─────────────────────────────────────
try {
    Write-Host "Testing: SIL-7 /volatility-alerts components deterministic (two calls match)" -NoNewline
    $url = "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary&limit=1"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        if ($d1.items -and $d1.items.Count -gt 0 -and $d2.items -and $d2.items.Count -gt 0) {
            $match = (
                $d1.items[0].rankVolatilityComponent    -eq $d2.items[0].rankVolatilityComponent    -and
                $d1.items[0].aiOverviewComponent        -eq $d2.items[0].aiOverviewComponent        -and
                $d1.items[0].featureVolatilityComponent -eq $d2.items[0].featureVolatilityComponent
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (component values differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
