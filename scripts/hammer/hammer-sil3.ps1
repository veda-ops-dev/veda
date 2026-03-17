# hammer-sil3.ps1 — SIL-3 (Keyword Volatility Aggregation)
# Dot-sourced by api-hammer.ps1. Inherits all symbols from hammer-lib.ps1 + coordinator.

Hammer-Section "SIL-3 TESTS (KEYWORD VOLATILITY)"

# ── Setup: create a fresh KeywordTarget + 3 snapshots with known delta data ────
$s3RunId  = (Get-Date).Ticks
$s3Query  = "volatility hammer $s3RunId"
$s3Locale = "en-US"
$s3Device = "desktop"
$s3KtId   = $null

try {
    Write-Host "Testing: SIL-3 setup: create KeywordTarget" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($s3Query);locale=$s3Locale;device=$s3Device;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $s3KtId = (($resp.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $s3Query } | Select-Object -First 1).id
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

if ([string]::IsNullOrWhiteSpace($s3KtId) -or $s3KtId -notmatch '^[0-9a-fA-F-]{36}$') { $s3KtId = $null }

# ── VL-A: invalid UUID → 400 ──────────────────────────────────────────────────
Test-Endpoint "GET" "$Base/api/seo/keyword-targets/not-a-uuid/volatility" 400 `
    "GET volatility invalid UUID -> 400" $Headers

# ── VL-B: nonexistent UUID → 404 ─────────────────────────────────────────────
Test-Endpoint "GET" "$Base/api/seo/keyword-targets/00000000-0000-4000-a000-000000000099/volatility" 404 `
    "GET volatility not found -> 404" $Headers

if (-not $s3KtId) {
    Write-Host "Skipping VL-C through VL-I: KeywordTarget creation failed" -ForegroundColor DarkYellow
    for ($i=0; $i -lt 7; $i++) { Hammer-Record SKIP }
} else {
    # ── VL-C: <2 snapshots → sampleSize=0, all metrics 0, 200 ─────────────────
    try {
        Write-Host "Testing: GET volatility <2 snapshots -> sampleSize=0" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.sampleSize -eq 0 -and $d.volatilityScore -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " score=" + $d.volatilityScore + ", expected 0/0)") -ForegroundColor Red
                Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── Add snapshot 1: page-a #1, page-b #2; aiOverviewStatus=absent ─────────
    $s3Ss1Id = $null
    try {
        Write-Host "Testing: SIL-3 setup: create snapshot 1" -NoNewline
        $body = @{
            query=$s3Query; locale=$s3Locale; device=$s3Device
            capturedAt=(Get-Date).AddMinutes(-20).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            rawPayload=@{results=@(
                @{url="https://example.com/alpha";rank=1;title="Alpha"}
                @{url="https://example.com/beta"; rank=2;title="Beta"}
                @{url="https://example.com/gamma";rank=3;title="Gamma"}
            )}
            source="dataforseo"; aiOverviewStatus="absent"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) {
            $s3Ss1Id = ($resp.Content | ConvertFrom-Json).data.id
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── Still <2 snapshots for *this run* check already done (VL-C above) ─────

    # ── Add snapshot 2: beta rises to #1, alpha drops to #3, delta enters ─────
    $s3Ss2Id = $null
    try {
        Write-Host "Testing: SIL-3 setup: create snapshot 2" -NoNewline
        $body = @{
            query=$s3Query; locale=$s3Locale; device=$s3Device
            capturedAt=(Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            rawPayload=@{results=@(
                @{url="https://example.com/beta"; rank=1;title="Beta"}
                @{url="https://example.com/gamma";rank=2;title="Gamma"}
                @{url="https://example.com/alpha";rank=3;title="Alpha"}
                # gamma: no change, alpha: +2, beta: -1
            )}
            source="dataforseo"; aiOverviewStatus="present"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) {
            $s3Ss2Id = ($resp.Content | ConvertFrom-Json).data.id
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-D: 2 snapshots → sampleSize=1, metrics computed, score > 0 ─────────
    try {
        Write-Host "Testing: GET volatility 2 snapshots -> sampleSize=1, score>0" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $hasMetrics = ($d.sampleSize -eq 1 -and $d.volatilityScore -gt 0 -and $d.aiOverviewChurn -ge 1)
            if ($hasMetrics) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " score=" + $d.volatilityScore + " aioChurn=" + $d.aiOverviewChurn + ")") -ForegroundColor Red
                Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── Add snapshot 3: another change so we can verify aggregation ────────────
    try {
        Write-Host "Testing: SIL-3 setup: create snapshot 3" -NoNewline
        $body = @{
            query=$s3Query; locale=$s3Locale; device=$s3Device
            capturedAt=(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            rawPayload=@{results=@(
                @{url="https://example.com/alpha";rank=1;title="Alpha"}
                @{url="https://example.com/gamma";rank=2;title="Gamma"}
                @{url="https://example.com/beta"; rank=3;title="Beta"}
            )}
            source="dataforseo"; aiOverviewStatus="absent"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-E: 3 snapshots → sampleSize=2, aiOverviewChurn >= 2 ──────────────
    # ss1→ss2: absent→present (flip). ss2→ss3: present→absent (flip). Total churn=2.
    try {
        Write-Host "Testing: GET volatility 3 snapshots -> sampleSize=2, aiOverviewChurn=2" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.sampleSize -eq 2 -and $d.aiOverviewChurn -eq 2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " aiChurn=" + $d.aiOverviewChurn + ", expected 2/2)") -ForegroundColor Red
                Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-F: Determinism — two identical calls produce identical output ───────
    try {
        Write-Host "Testing: GET volatility deterministic (two sequential calls match)" -NoNewline
        $url = "$Base/api/seo/keyword-targets/$s3KtId/volatility"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $match = (
                $d1.volatilityScore  -eq $d2.volatilityScore  -and
                $d1.averageRankShift -eq $d2.averageRankShift -and
                $d1.maxRankShift     -eq $d2.maxRankShift     -and
                $d1.aiOverviewChurn  -eq $d2.aiOverviewChurn  -and
                $d1.featureVolatility -eq $d2.featureVolatility -and
                $d1.sampleSize       -eq $d2.sampleSize
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else {
                Write-Host ("  FAIL (score1=" + $d1.volatilityScore + " score2=" + $d2.volatilityScore + ")") -ForegroundColor Red
                Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status1=" + $r1.StatusCode + " status2=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-G: Cross-project non-disclosure → 404 ─────────────────────────────
    if ($OtherHeaders.Count -gt 0) {
        Test-Endpoint "GET" "$Base/api/seo/keyword-targets/$s3KtId/volatility" 404 `
            "GET volatility cross-project -> 404" $OtherHeaders
    } else {
        Write-Host "Testing: GET volatility cross-project -> 404  SKIP (no OtherHeaders)" -ForegroundColor DarkYellow
        Hammer-Record SKIP
    }

    # ── VL-H: Response envelope validation ───────────────────────────────────
    try {
        Write-Host "Testing: GET volatility response envelope has all required fields" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","sampleSize","averageRankShift","maxRankShift",
                          "featureVolatility","aiOverviewChurn","volatilityScore","computedAt")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-I: volatilityScore in [0, 100] ────────────────────────────────────
    try {
        Write-Host "Testing: GET volatility score in range [0, 100]" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $score = ($resp.Content | ConvertFrom-Json).data.volatilityScore
            if ($score -ge 0 -and $score -le 100) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (score=" + $score + " out of range [0,100])") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-J: windowDays=1 → 200, windowDays echoed in response ──────────────
    try {
        Write-Host "Testing: GET volatility windowDays=1 -> 200 + windowDays echoed" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.windowDays -eq 1 -and $null -ne $d.windowStartAt) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (windowDays=" + $d.windowDays + " windowStartAt=" + $d.windowStartAt + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-K: windowDays=1 with recent snapshots → sampleSize reflects window ─
    # The 3 snapshots created above all have capturedAt within the last hour.
    # windowDays=1 includes them; sampleSize must still be 2 (3 snaps - 1 pair).
    try {
        Write-Host "Testing: GET volatility windowDays=1 includes recent snapshots (sampleSize=2)" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.sampleSize -eq 2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + ", expected 2)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-L: old-snapshot outside window → sampleSize drops ─────────────────
    # Create a snapshot with capturedAt 400 days ago (outside windowDays=365).
    # Without window: sampleSize increases. With windowDays=365: old snap excluded.
    $s3OldSnapCreated = $false
    try {
        Write-Host "Testing: SIL-3 setup: create snapshot with capturedAt 400 days ago" -NoNewline
        $oldCapturedAt = (Get-Date).AddDays(-400).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $body = @{
            query=$s3Query; locale=$s3Locale; device=$s3Device
            capturedAt=$oldCapturedAt
            rawPayload=@{results=@(
                @{url="https://example.com/alpha";rank=5;title="Alpha"}
                @{url="https://example.com/beta"; rank=6;title="Beta"}
            )}
            source="dataforseo"; aiOverviewStatus="absent"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) {
            $s3OldSnapCreated = $true
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # Without window: sampleSize must now be 3 (4 snaps, 3 pairs)
    # With windowDays=365: old snap excluded, sampleSize still 2
    if ($s3OldSnapCreated) {
        try {
            Write-Host "Testing: GET volatility no-window includes old snap (sampleSize=3)" -NoNewline
            $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $d = ($resp.Content | ConvertFrom-Json).data
                if ($d.sampleSize -eq 3) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + ", expected 3)") -ForegroundColor Red; Hammer-Record FAIL
                }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

        try {
            Write-Host "Testing: GET volatility windowDays=365 excludes 400-day-old snap (sampleSize=2)" -NoNewline
            $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=365" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $d = ($resp.Content | ConvertFrom-Json).data
                if ($d.sampleSize -eq 2 -and $d.windowDays -eq 365) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " windowDays=" + $d.windowDays + ", expected 2/365)") -ForegroundColor Red; Hammer-Record FAIL
                }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } else {
        Write-Host "Testing: GET volatility no-window sampleSize=3  SKIP (old snap not created)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        Write-Host "Testing: GET volatility windowDays=365 sampleSize=2  SKIP (old snap not created)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    }

    # ── VL-M: invalid windowDays values → 400 ────────────────────────────────
    Test-Endpoint "GET" "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=0" 400 `
        "GET volatility windowDays=0 -> 400" $Headers
    Test-Endpoint "GET" "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=abc" 400 `
        "GET volatility windowDays=abc -> 400" $Headers
    Test-Endpoint "GET" "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=366" 400 `
        "GET volatility windowDays=366 -> 400" $Headers

    # ── VL-N: windowed determinism — two calls with same windowDays match ─────
    try {
        Write-Host "Testing: GET volatility windowDays=30 deterministic (two calls match)" -NoNewline
        $wUrl = "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=30"
        $r1 = Invoke-WebRequest -Uri $wUrl -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $wUrl -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            # Exclude computedAt and windowStartAt — wall-clock fields.
            $match = (
                $d1.windowDays       -eq $d2.windowDays       -and
                $d1.volatilityScore  -eq $d2.volatilityScore  -and
                $d1.sampleSize       -eq $d2.sampleSize       -and
                $d1.averageRankShift -eq $d2.averageRankShift -and
                $d1.aiOverviewChurn  -eq $d2.aiOverviewChurn
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (score1=" + $d1.volatilityScore + " score2=" + $d2.volatilityScore + ")") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (status1=" + $r1.StatusCode + " status2=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-O: maturity field present and is a valid tier string ────────────────
    try {
        Write-Host "Testing: GET volatility maturity field present and valid" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $mat = ($resp.Content | ConvertFrom-Json).data.maturity
            $validTiers = @("preliminary", "developing", "stable")
            if ($validTiers -contains $mat) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (maturity='" + $mat + "' not in valid tiers)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-P: 2 pairs (sampleSize=2 after VL-K) → maturity = preliminary ────────
    # At this point in the test run: 3 recent snapshots + 1 old snapshot.
    # windowDays=1 shows only the 3 recent ones → sampleSize=2 → preliminary.
    try {
        Write-Host "Testing: GET volatility windowDays=1 sampleSize=2 -> maturity=preliminary" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.sampleSize -eq 2 -and $d.maturity -eq "preliminary") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " maturity=" + $d.maturity + ", expected 2/preliminary)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-Q: bulk-insert snapshots to reach sampleSize >= 20 → maturity = stable ─
    # We need at least 21 total snapshots for sampleSize=20 (21-1 pairs).
    # We currently have 4 (3 recent + 1 old). Need 17 more recent ones.
    $s3BulkOk = $true
    for ($bi = 1; $bi -le 17; $bi++) {
        try {
            $bCapturedAt = (Get-Date).AddSeconds(-$bi * 30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $bBody = @{
                query=$s3Query; locale=$s3Locale; device=$s3Device
                capturedAt=$bCapturedAt
                rawPayload=@{results=@(
                    @{url="https://example.com/alpha";rank=(1 + ($bi % 5));title="Alpha"}
                    @{url="https://example.com/beta"; rank=(2 + ($bi % 3));title="Beta"}
                )}
                source="dataforseo"; aiOverviewStatus=if ($bi % 2 -eq 0) { "present" } else { "absent" }
            }
            $bResp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($bBody | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($bResp.StatusCode -ne 201 -and $bResp.StatusCode -ne 200) { $s3BulkOk = $false }
        } catch { $s3BulkOk = $false }
    }

    try {
        Write-Host "Testing: GET volatility 21+ snapshots -> sampleSize>=20 -> maturity=stable" -NoNewline
        if (-not $s3BulkOk) {
            Write-Host "  SKIP (bulk insert failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $d = ($resp.Content | ConvertFrom-Json).data
                if ($d.sampleSize -ge 20 -and $d.maturity -eq "stable") {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " maturity=" + $d.maturity + ", expected >=20/stable)") -ForegroundColor Red; Hammer-Record FAIL
                }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-R: alertThreshold=0 → 200, exceedsThreshold=true iff sampleSize>=1 ─────────
    # At this point sampleSize >= 20 (VL-Q bulk inserts). Any score >= 0 exceeds threshold=0.
    try {
        Write-Host "Testing: GET volatility alertThreshold=0 -> exceedsThreshold=true (active kw)" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?alertThreshold=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            # sampleSize >= 1 after all the inserts, so exceedsThreshold must be true
            $expectExceeds = ($d.sampleSize -ge 1)
            $fieldOk = ($d.alertThreshold -eq 0) -and ($d.exceedsThreshold -eq $expectExceeds)
            if ($fieldOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (alertThreshold=" + $d.alertThreshold + " exceedsThreshold=" + $d.exceedsThreshold + " sampleSize=" + $d.sampleSize + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-S: alertThreshold=100 → 200, exceedsThreshold is a boolean (not assumed) ───
    try {
        Write-Host "Testing: GET volatility alertThreshold=100 -> 200, exceedsThreshold is boolean" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility?alertThreshold=100" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $isBool = ($d.exceedsThreshold -eq $true -or $d.exceedsThreshold -eq $false)
            $echoOk = ($d.alertThreshold -eq 100)
            if ($isBool -and $echoOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (alertThreshold=" + $d.alertThreshold + " exceedsThreshold=" + $d.exceedsThreshold + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # ── VL-T: invalid alertThreshold values → 400 ──────────────────────────────
    $s3VlUrl = "$Base/api/seo/keyword-targets/$s3KtId/volatility"
    Test-Endpoint "GET" "$($s3VlUrl)?alertThreshold=-1" 400 `
        "GET volatility alertThreshold=-1 -> 400" $Headers
    Test-Endpoint "GET" "$($s3VlUrl)?alertThreshold=101" 400 `
        "GET volatility alertThreshold=101 -> 400" $Headers
    Test-Endpoint "GET" "$($s3VlUrl)?alertThreshold=abc" 400 `
        "GET volatility alertThreshold=abc -> 400" $Headers

    # ── VL-U: combined windowDays + alertThreshold → 200, fields present ────────────
    try {
        Write-Host "Testing: GET volatility windowDays=1&alertThreshold=60 -> 200 + fields present" -NoNewline
        $resp = Invoke-WebRequest -Uri "$($s3VlUrl)?windowDays=1&alertThreshold=60" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $hasFields = ($null -ne $d.alertThreshold) -and ($null -ne $d.exceedsThreshold)
            $paramsOk  = ($d.windowDays -eq 1 -and $d.alertThreshold -eq 60)
            if ($hasFields -and $paramsOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (windowDays=" + $d.windowDays + " alertThreshold=" + $d.alertThreshold + " exceedsThreshold=" + $d.exceedsThreshold + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
}

# =============================================================================
Hammer-Section "SIL-3 PAYLOAD HETEROGENEITY TORTURE TESTS"
# =============================================================================

$s3phRunId = (Get-Date).Ticks

# ---- PH3-A: snapshot with {} payload among real snapshots -------------------
# Ensures computeVolatility handles a payload with no extractable results:
# the empty snapshot contributes 0 URLs to its pairs -> averageRankShift=0
# for those pairs, but sampleSize is still counted (N-1 pairs from N snapshots).
$ph3AQuery = "ph3-empty-payload $s3phRunId"
$ph3AKtId  = $null

try {
    $r = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($ph3AQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 201) {
        $ph3AKtId = (($r.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $ph3AQuery } | Select-Object -First 1).id
    }
} catch {}

$ph3AOk = $false
if ($ph3AKtId) {
    $tA0 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tA1 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tA2 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $snapOk = $true
    # Snapshot 1: normal results
    $body1 = @{query=$ph3AQuery;locale="en-US";device="desktop";capturedAt=$tA0;source="dataforseo";aiOverviewStatus="absent"
        rawPayload=@{results=@(@{url="https://ex.com/a";rank=1;title="A"},@{url="https://ex.com/b";rank=2;title="B"})}}
    $r1 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($body1 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -notin @(200,201)) { $snapOk = $false }

    # Snapshot 2: empty payload object (no results key)
    $body2 = @{query=$ph3AQuery;locale="en-US";device="desktop";capturedAt=$tA1;source="dataforseo";aiOverviewStatus="present"
        rawPayload=@{}}
    $r2 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($body2 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r2.StatusCode -notin @(200,201)) { $snapOk = $false }

    # Snapshot 3: normal results again
    $body3 = @{query=$ph3AQuery;locale="en-US";device="desktop";capturedAt=$tA2;source="dataforseo";aiOverviewStatus="absent"
        rawPayload=@{results=@(@{url="https://ex.com/a";rank=2;title="A"},@{url="https://ex.com/b";rank=1;title="B"})}}
    $r3 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($body3 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r3.StatusCode -notin @(200,201)) { $snapOk = $false }

    $ph3AOk = $snapOk
}

try {
    Write-Host "Testing: volatility with {} payload snapshot -> 200, sampleSize=2, score in [0,100]" -NoNewline
    if (-not $ph3AOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$ph3AKtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $scoreOk  = ($d.volatilityScore -ge 0 -and $d.volatilityScore -le 100)
            # 3 snapshots -> sampleSize=2 pairs (even if one snapshot yields no extractable URLs)
            $sizeOk   = ($d.sampleSize -eq 2)
            if ($scoreOk -and $sizeOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " score=" + $d.volatilityScore + ", expected 2 and [0,100])") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ---- PH3-B: near-identical timestamps, id tie-breaker ordering stability -----
# Goal: verify that [capturedAt ASC, id ASC] ordering produces stable output.
#
# Why not literal same capturedAt:
#   SERPSnapshot has @@unique([projectId, query, locale, device, capturedAt]).
#   Two inserts with identical (query, locale, device, capturedAt) hit a unique
#   constraint violation. The schema intentionally prevents exact-duplicate
#   captures. Testing literal same-timestamp is not reachable via the public API.
#
# What we test instead:
#   Three snapshots spaced 1 second apart. Two sequential calls to the volatility
#   endpoint must return identical stable fields, proving the orderBy is repeatable.
$ph3BQuery = "ph3-id-tiebreak $s3phRunId"
$ph3BKtId  = $null

try {
    $r = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($ph3BQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 201) {
        $ph3BKtId = (($r.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $ph3BQuery } | Select-Object -First 1).id
    }
} catch {}

$ph3BOk = $false
if ($ph3BKtId) {
    $tB0 = (Get-Date).AddSeconds(-2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tB1 = (Get-Date).AddSeconds(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tB2 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $bB1 = @{query=$ph3BQuery;locale="en-US";device="desktop";capturedAt=$tB0;source="dataforseo";aiOverviewStatus="absent"
        rawPayload=@{results=@(@{url="https://ex.com/b1";rank=1;title="B1"})}}
    $bB2 = @{query=$ph3BQuery;locale="en-US";device="desktop";capturedAt=$tB1;source="dataforseo";aiOverviewStatus="present"
        rawPayload=@{results=@(@{url="https://ex.com/b2";rank=1;title="B2"})}}
    $bB3 = @{query=$ph3BQuery;locale="en-US";device="desktop";capturedAt=$tB2;source="dataforseo";aiOverviewStatus="absent"
        rawPayload=@{results=@(@{url="https://ex.com/b1";rank=2;title="B1"})}}

    $rB1 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($bB1 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $rB2 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($bB2 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $rB3 = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
        -Body ($bB3 | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $ph3BOk = ($rB1.StatusCode -in @(200,201) -and $rB2.StatusCode -in @(200,201) -and $rB3.StatusCode -in @(200,201))
}

try {
    Write-Host "Testing: volatility id-tiebreak ordering -> sampleSize=2, deterministic" -NoNewline
    if (-not $ph3BOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $u = "$Base/api/seo/keyword-targets/$ph3BKtId/volatility"
        $resp1 = Invoke-WebRequest -Uri $u -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $resp2 = Invoke-WebRequest -Uri $u -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp1.StatusCode -eq 200 -and $resp2.StatusCode -eq 200) {
            $d1 = ($resp1.Content | ConvertFrom-Json).data
            $d2 = ($resp2.Content | ConvertFrom-Json).data
            # 3 snapshots -> sampleSize=2
            $sizeOk = ($d1.sampleSize -eq 2)
            $detOk  = (
                $d1.sampleSize      -eq $d2.sampleSize      -and
                $d1.volatilityScore -eq $d2.volatilityScore -and
                $d1.aiOverviewChurn -eq $d2.aiOverviewChurn
            )
            if ($sizeOk -and $detOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d1.sampleSize + " det=" + $detOk + ", expected 2 + stable)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $resp1.StatusCode + "/" + $resp2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ---- PH3-C: volatility determinism on existing s3KtId (main SIL-3 KT) ------
try {
    Write-Host "Testing: volatility two calls identical stable fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) { Write-Host "  SKIP (main SIL-3 KT not created)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $u = "$Base/api/seo/keyword-targets/$s3KtId/volatility"
        $resp1 = Invoke-WebRequest -Uri $u -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $resp2 = Invoke-WebRequest -Uri $u -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp1.StatusCode -eq 200 -and $resp2.StatusCode -eq 200) {
            $d1 = ($resp1.Content | ConvertFrom-Json).data
            $d2 = ($resp2.Content | ConvertFrom-Json).data
            $match = (
                $d1.volatilityScore  -eq $d2.volatilityScore  -and
                $d1.sampleSize       -eq $d2.sampleSize       -and
                $d1.averageRankShift -eq $d2.averageRankShift -and
                $d1.aiOverviewChurn  -eq $d2.aiOverviewChurn  -and
                $d1.maturity         -eq $d2.maturity
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (fields differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (status=" + $resp1.StatusCode + "/" + $resp2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
