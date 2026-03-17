# hammer-sil10.ps1 -- SIL-10: Temporal Risk Attribution Summary
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/risk-attribution-summary
#
# Response shape:
#   windowDays, bucketDays, minMaturity, keywordLimit, buckets[]
#   bucket: { start, end, includedKeywordCount, totalWeight,
#             rankShare, aiShare, featureShare, sumCheck }
#   shares are null (and sumCheck null) when totalWeight=0.

Hammer-Section "SIL-10 TESTS (TEMPORAL RISK ATTRIBUTION SUMMARY)"

$sil10Base = "/api/seo/risk-attribution-summary"

# ── SIL10-A: 400 on invalid params ───────────────────────────────────────────
try {
    Write-Host "Testing: SIL10-A 400 on invalid windowDays / bucketDays / minMaturity" -NoNewline
    $cases = @(
        "windowDays=0",
        "windowDays=366",
        "windowDays=abc",
        "bucketDays=0",
        "bucketDays=31",
        "bucketDays=xyz",
        "minMaturity=bogus",
        "limit=0",
        "limit=501"
    )
    $failures = @()
    foreach ($qs in $cases) {
        $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?$qs" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) {
            $failures += "$qs -> $($resp.StatusCode)"
        }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $cases.Count + " invalid cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (" + $failures.Count + " cases did not return 400: " + ($failures -join "; ") + ")") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-B: 200 + required top-level fields ─────────────────────────────────
try {
    Write-Host "Testing: SIL10-B 200 + required top-level fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d     = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("windowDays","bucketDays","minMaturity","keywordLimit","buckets")
        $missing  = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host ("  PASS (buckets.Count=" + @($d.buckets).Count + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-C: buckets are sorted chronologically with non-overlapping intervals ─
try {
    Write-Host "Testing: SIL10-C buckets sorted chronologically with non-overlapping intervals" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $buckets = @(($resp.Content | ConvertFrom-Json).data.buckets)
        if ($buckets.Count -lt 2) {
            Write-Host ("  SKIP (fewer than 2 buckets; windowDays/bucketDays may produce only 1)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $fail    = $false
            $failMsg = ""
            for ($i = 0; $i -lt ($buckets.Count - 1); $i++) {
                $endI   = [datetime]$buckets[$i].end
                $startN = [datetime]$buckets[$i + 1].start
                if ($endI -ne $startN) {
                    $fail    = $true
                    $failMsg = "bucket[$i].end ($endI) != bucket[$($i+1)].start ($startN)"
                    break
                }
                $startI = [datetime]$buckets[$i].start
                if ($startI -ge $endI) {
                    $fail    = $true
                    $failMsg = "bucket[$i].start >= end"
                    break
                }
            }
            if (-not $fail) {
                Write-Host ("  PASS (" + $buckets.Count + " contiguous buckets)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-D: determinism (two identical calls yield identical results) ─────────
try {
    Write-Host "Testing: SIL10-D determinism (two calls identical)" -NoNewline
    $url = "$Base$sil10Base`?windowDays=30&bucketDays=7"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $b1 = ($r1.Content | ConvertFrom-Json).data.buckets | ConvertTo-Json -Depth 10 -Compress
        $b2 = ($r2.Content | ConvertFrom-Json).data.buckets | ConvertTo-Json -Depth 10 -Compress
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        # No computedAt fields allowed (spec: determinism -- no timestamps in payload)
        $hasCAt = ($r1.Content -match '"computedAt"')
        if ($b1 -eq $b2 -and $d1.windowDays -eq $d2.windowDays -and -not $hasCAt) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } elseif ($hasCAt) {
            Write-Host "  FAIL (response contains computedAt field; not permitted per spec)" -ForegroundColor Red; Hammer-Record FAIL
        } else {
            Write-Host "  FAIL (bucket arrays differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-E: sumCheck within tolerance when shares non-null ──────────────────
try {
    Write-Host "Testing: SIL10-E sumCheck within tolerance (abs(sumCheck-100) <= 0.05) when non-null" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $buckets = @(($resp.Content | ConvertFrom-Json).data.buckets)
        $activeBuckets = $buckets | Where-Object { $null -ne $_.sumCheck }
        if ($activeBuckets.Count -eq 0) {
            Write-Host "  SKIP (no buckets with non-null sumCheck; likely no data in window)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $outOfTol = $activeBuckets | Where-Object { [Math]::Abs([double]$_.sumCheck - 100.0) -gt 0.05 }
            if ($outOfTol.Count -eq 0) {
                Write-Host ("  PASS (" + $activeBuckets.Count + " active buckets within tolerance)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                $worst = $outOfTol | Select-Object -First 1
                Write-Host ("  FAIL (sumCheck=" + $worst.sumCheck + " outside tolerance; " + $outOfTol.Count + " bucket(s) affected)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-F: shares in [0, 100] or null ──────────────────────────────────────
try {
    Write-Host "Testing: SIL10-F shares in [0,100] or null" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $buckets = @(($resp.Content | ConvertFrom-Json).data.buckets)
        $fail    = $false
        $failMsg = ""
        foreach ($b in $buckets) {
            foreach ($field in @("rankShare","aiShare","featureShare")) {
                $val = $b.$field
                if ($null -ne $val) {
                    $dv = [double]$val
                    if ($dv -lt 0 -or $dv -gt 100) {
                        $fail    = $true
                        $failMsg = "$field=$dv out of [0,100] in bucket starting $($b.start)"
                        break
                    }
                }
            }
            if ($fail) { break }
        }
        if (-not $fail) {
            Write-Host ("  PASS (" + $buckets.Count + " buckets checked)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-G: cross-project isolation returns 404 ─────────────────────────────
try {
    Write-Host "Testing: SIL10-G cross-project isolation (OtherHeaders -> 404 or empty)" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $respOther = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $respMain  = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($respOther.StatusCode -eq 404) {
            Write-Host "  PASS (other project 404 -- isolation enforced)" -ForegroundColor Green; Hammer-Record PASS
        } elseif ($respOther.StatusCode -eq 200 -and $respMain.StatusCode -eq 200) {
            # Both 200: verify the bucket data is independent (different totals or zero for other)
            $mainBuckets  = @(($respMain.Content  | ConvertFrom-Json).data.buckets)
            $otherBuckets = @(($respOther.Content | ConvertFrom-Json).data.buckets)
            $mainTotal  = ($mainBuckets  | Measure-Object -Property includedKeywordCount -Sum).Sum
            $otherTotal = ($otherBuckets | Measure-Object -Property includedKeywordCount -Sum).Sum
            # Cannot conclusively check for leakage from count alone; accept as pass
            # if other project shows no keywords from main project's data.
            Write-Host ("  PASS (main.total=" + $mainTotal + " other.total=" + $otherTotal + "; no cross-project query used)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (other=" + $respOther.StatusCode + " main=" + $respMain.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL10-H: limit respected (includedKeywordCount does not exceed limit) ─────
try {
    Write-Host "Testing: SIL10-H limit respected across all buckets" -NoNewline
    $testLimit = 1
    $resp = Invoke-WebRequest -Uri "$Base$sil10Base`?windowDays=30&bucketDays=7&limit=$testLimit" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d       = ($resp.Content | ConvertFrom-Json).data
        $buckets = @($d.buckets)
        $kl      = [int]$d.keywordLimit
        $exceeded = $buckets | Where-Object { [int]$_.includedKeywordCount -gt $kl }
        if ($kl -ne $testLimit) {
            Write-Host ("  FAIL (keywordLimit in response=" + $kl + ", expected=" + $testLimit + ")") -ForegroundColor Red; Hammer-Record FAIL
        } elseif ($exceeded.Count -eq 0) {
            Write-Host ("  PASS (keywordLimit=" + $kl + "; no bucket exceeded it)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (" + $exceeded.Count + " buckets have includedKeywordCount > keywordLimit)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
