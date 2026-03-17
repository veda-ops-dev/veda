# hammer-sil8-a2.ps1 -- SIL-8 A2 (Volatility Spike Detection)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/volatility-spikes
#
# Response shape (spec-canonical):
#   keywordTargetId, query, locale, device, windowDays, sampleSize, totalPairs, topN,
#   spikes: [ { fromSnapshotId, toSnapshotId, fromCapturedAt, toCapturedAt,
#               pairVolatilityScore, pairRankShift, pairMaxShift,
#               pairFeatureChangeCount, aiFlipped } ],
#   computedAt
#
# Fixture dependency:
#   $s3KtId    -- SIL-3 KeywordTarget with >=21 snapshots
#   $s7ZeroKtId -- KeywordTarget with 0 snapshots (set in hammer-sil7.ps1)
#   $OtherHeaders -- second project headers (set in coordinator)
#
# Tests (A2-A through A2-P):
#   A2-A: 200 + required top-level fields present
#   A2-B: spikes is an array
#   A2-C: sampleSize = snapshots - 1 (cross-check with /volatility sampleSize)
#   A2-D: spikes non-empty when sampleSize >= 1
#   A2-E: spikes.Count = min(topN default=3, sampleSize)
#   A2-F: determinism (two calls return identical spikes, excluding computedAt)
#   A2-G: sort correct -- pairVolatilityScore non-increasing across returned spikes
#   A2-H: pairVolatilityScore in [0, 100] for all items
#   A2-I: required per-spike fields present
#   A2-J: pairVolatilityScore cross-check -- single-pair fixture: spikes[0].pairVolatilityScore = /volatility volatilityScore
#   A2-K: topN param respected (topN=1 -> at most 1 spike)
#   A2-L: topN=10 -> at most min(10, sampleSize) spikes
#   A2-M: windowDays respected (narrow window -> sampleSize <= full-history sampleSize)
#   A2-N: 400 on invalid UUID
#   A2-O: 400 on topN out-of-range (0, 11)
#   A2-P: 400 on windowDays out-of-range (0, 366)
#   A2-Q: 404 cross-project (OtherHeaders + this project's ktId)
#   A2-R: zero-snapshot fixture -> sampleSize=0, spikes=[]

Hammer-Section "SIL-8 A2 TESTS (VOLATILITY SPIKE DETECTION)"

$a2Base = "/api/seo/keyword-targets"

# ── A2-A: 200 + required top-level fields ─────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes 200 + required top-level fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId", "windowDays", "sampleSize", "totalPairs", "topN", "spikes", "computedAt")
            $missing  = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-B: spikes is an array ──────────────────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes spikes field is an array" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $spikes = ($resp.Content | ConvertFrom-Json).data.spikes
            $isArray = ($spikes -is [System.Array]) -or ($null -eq $spikes)
            if ($isArray) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (spikes is not an array)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-C: sampleSize cross-check with /volatility ────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes sampleSize matches /volatility sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rSpikes = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rVol    = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rSpikes.StatusCode -eq 200 -and $rVol.StatusCode -eq 200) {
            $ssSpikes = [int]($rSpikes.Content | ConvertFrom-Json).data.sampleSize
            $ssVol    = [int]($rVol.Content    | ConvertFrom-Json).data.sampleSize
            if ($ssSpikes -eq $ssVol) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (spikes.sampleSize=" + $ssSpikes + " vol.sampleSize=" + $ssVol + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $rSpikes.StatusCode + "/" + $rVol.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-D: spikes non-empty when sampleSize >= 1 ───────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes non-empty when sampleSize >= 1" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d  = ($resp.Content | ConvertFrom-Json).data
            $ss = [int]$d.sampleSize
            $sc = @($d.spikes).Count
            if ($ss -ge 1 -and $sc -ge 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } elseif ($ss -eq 0 -and $sc -eq 0) {
                Write-Host "  SKIP (fixture has sampleSize=0, cannot verify non-empty rule)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                Write-Host ("  FAIL (sampleSize=" + $ss + " but spikes.Count=" + $sc + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-E: default topN=3 -> spikes.Count = min(3, sampleSize) ────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes default topN=3 respected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d      = ($resp.Content | ConvertFrom-Json).data
            $ss     = [int]$d.sampleSize
            $sc     = @($d.spikes).Count
            $expect = [Math]::Min(3, $ss)
            if ($sc -eq $expect) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (spikes.Count=" + $sc + ", expected min(3," + $ss + ")=" + $expect + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-F: determinism ─────────────────────────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes deterministic (two calls identical, excluding computedAt)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base$a2Base/$s3KtId/volatility-spikes"
        $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $ss1     = $d1.sampleSize
            $ss2     = $d2.sampleSize
            $spikes1 = ($d1.spikes | ConvertTo-Json -Depth 5 -Compress)
            $spikes2 = ($d2.spikes | ConvertTo-Json -Depth 5 -Compress)
            $match   = ($ss1 -eq $ss2) -and ($spikes1 -eq $spikes2)
            if ($match) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (spike arrays differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-G: sort order -- pairVolatilityScore non-increasing ───────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes sort order (pairVolatilityScore non-increasing)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=10" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $spikes = @(($resp.Content | ConvertFrom-Json).data.spikes)
            if ($spikes.Count -lt 2) {
                Write-Host "  SKIP (fewer than 2 spikes, cannot verify sort)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $sortOk = $true
                for ($i = 0; $i -lt $spikes.Count - 1; $i++) {
                    $cur  = [double]$spikes[$i].pairVolatilityScore
                    $next = [double]$spikes[$i + 1].pairVolatilityScore
                    if ($next -gt $cur) { $sortOk = $false; break }
                }
                if ($sortOk) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (pairVolatilityScore is not non-increasing)" -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-H: pairVolatilityScore in [0, 100] ────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes all pairVolatilityScore in [0, 100]" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=10" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $spikes = @(($resp.Content | ConvertFrom-Json).data.spikes)
            if ($spikes.Count -eq 0) {
                Write-Host "  SKIP (no spikes)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $invalid = $spikes | Where-Object {
                    $s = [double]$_.pairVolatilityScore
                    ($s -lt 0) -or ($s -gt 100)
                }
                if ($invalid.Count -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (" + $invalid.Count + " items have pairVolatilityScore outside [0,100])") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-I: required per-spike fields present ───────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes per-spike required fields present" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $spikes = @(($resp.Content | ConvertFrom-Json).data.spikes)
            if ($spikes.Count -eq 0) {
                Write-Host "  SKIP (no spikes returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $spike    = $spikes[0]
                $sProps   = $spike | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $required = @("fromSnapshotId","toSnapshotId","fromCapturedAt","toCapturedAt",
                              "pairVolatilityScore","pairRankShift","pairMaxShift",
                              "pairFeatureChangeCount","aiFlipped")
                $missing  = $required | Where-Object { $sProps -notcontains $_ }
                if ($missing.Count -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (missing spike fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-J: pairVolatilityScore cross-check with /volatility (1-pair case) ─────
# For a keyword with exactly 2 snapshots, sampleSize=1. The single spike's
# pairVolatilityScore must equal the /volatility volatilityScore (same input, same formula).
# We reuse $s7ZeroKtId's pair logic is unavailable (zero snapshots). Instead we
# use $s3KtId with windowDays=1. If that produces sampleSize=1 we can cross-check.
# If not, we SKIP with explanation (not a failure -- boundary conditions are data-dependent).
try {
    Write-Host "Testing: A2 pairVolatilityScore consistency with /volatility (single-pair window)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rSpikes = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?windowDays=1&topN=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rVol    = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rSpikes.StatusCode -eq 200 -and $rVol.StatusCode -eq 200) {
            $dSpikes  = ($rSpikes.Content | ConvertFrom-Json).data
            $dVol     = ($rVol.Content    | ConvertFrom-Json).data
            $ssSpikes = [int]$dSpikes.sampleSize
            $ssVol    = [int]$dVol.sampleSize
            if ($ssSpikes -eq 1 -and $ssVol -eq 1 -and $dSpikes.spikes.Count -ge 1) {
                $pairScore = [double]$dSpikes.spikes[0].pairVolatilityScore
                $volScore  = [double]$dVol.volatilityScore
                if ([Math]::Abs($pairScore - $volScore) -lt 0.01) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (pairScore=" + $pairScore + " volScore=" + $volScore + ", diff > 0.01)") -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                Write-Host "  SKIP (windowDays=1 did not yield sampleSize=1; data-dependent, not a logic failure)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            }
        } else { Write-Host ("  FAIL (status=" + $rSpikes.StatusCode + "/" + $rVol.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-K: topN=1 -> at most 1 spike ─────────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes topN=1 returns at most 1 spike" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $sc = @(($resp.Content | ConvertFrom-Json).data.spikes).Count
            if ($sc -le 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (spikes.Count=" + $sc + ", expected <= 1)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-L: topN=10 -> at most min(10, sampleSize) spikes ──────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes topN=10 returns min(10, sampleSize) spikes" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=10" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d      = ($resp.Content | ConvertFrom-Json).data
            $ss     = [int]$d.sampleSize
            $sc     = @($d.spikes).Count
            $expect = [Math]::Min(10, $ss)
            if ($sc -eq $expect) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (spikes.Count=" + $sc + ", expected min(10," + $ss + ")=" + $expect + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-M: windowDays respected (narrow window -> sampleSize <= full-history) ──
try {
    Write-Host "Testing: A2 /volatility-spikes windowDays=1 sampleSize <= no-window sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rAll = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rW1  = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rAll.StatusCode -eq 200 -and $rW1.StatusCode -eq 200) {
            $ssAll = [int]($rAll.Content | ConvertFrom-Json).data.sampleSize
            $ssW1  = [int]($rW1.Content  | ConvertFrom-Json).data.sampleSize
            if ($ssW1 -le $ssAll) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (windowDays=1 sampleSize=" + $ssW1 + " > full sampleSize=" + $ssAll + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $rAll.StatusCode + "/" + $rW1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-N: 400 on invalid UUID ────────────────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes 400 on invalid UUID" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$a2Base/not-a-uuid/volatility-spikes" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-O: 400 on topN out of range (0, 11) ───────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes 400 on topN=0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: A2 /volatility-spikes 400 on topN=11" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?topN=11" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-P: 400 on windowDays out of range (0, 366) ────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes 400 on windowDays=0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?windowDays=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: A2 /volatility-spikes 400 on windowDays=366" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes?windowDays=366" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-Q: 404 cross-project ────────────────────────────────────────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes 404 on cross-project access" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId) -or $OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (s3KtId or OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s3KtId/volatility-spikes" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A2-R: zero-snapshot fixture -> sampleSize=0, spikes=[] ──────────────────
try {
    Write-Host "Testing: A2 /volatility-spikes zero-snapshot fixture -> sampleSize=0, spikes=[]" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s7ZeroKtId)) {
        Write-Host "  SKIP (s7ZeroKtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a2Base/$s7ZeroKtId/volatility-spikes" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $ssOk  = ([int]$d.sampleSize -eq 0)
            $spOk  = ($null -eq $d.spikes -or @($d.spikes).Count -eq 0)
            if ($ssOk -and $spOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " spikes.Count=" + @($d.spikes).Count + ", expected 0/0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
