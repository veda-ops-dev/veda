# hammer-event-causality.ps1 -- SIL-14 Event Causality Detection
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/event-causality
#
# Two KTs:
#   $_ecCausalId -- 5 snapshots engineered to produce feature_turbulence → algorithm_shift
#   $_ecStableId -- 3 identical snapshots (all stable → patternCount = 0)

Hammer-Section "EVENT CAUSALITY TESTS"

$_ecBase      = "/api/seo/keyword-targets"
$_ecRunId     = (Get-Date).Ticks
$_ecCausalQ   = "ec-causal-$_ecRunId"
$_ecStableQ   = "ec-stable-$_ecRunId"
$_ecCausalId  = $null
$_ecStableId  = $null
$_ecSetupOk   = $false
$_ecStableOk  = $false

# =============================================================================
# Setup -- causal KT (feature_turbulence → algorithm_shift)
# =============================================================================
# Fixture strategy:
#
# feature_turbulence requires: featureTransitionCount >= 3, volatilityScore >= 30
# algorithm_shift requires:    volatilityScore >= 60, averageSimilarity <= 0.45
#
# Intent safety: all early features map to "informational" bucket only
#   featured_snippet -> informational
#   people_also_ask  -> informational
#   knowledge_graph  -> knowledge_panel -> informational
# Snap 4 has no features -> dominant = "none" -> 1 intent transition total
# intent_shift needs intentDriftEventCount >= 2, so 1 is safe.
#
# AI safety: aiOverviewStatus = "absent" on ALL snapshots. Zero churn.
#
# Shared URLs (shared.com/a1..a10): present in ALL snapshots, ranks oscillate
# between 1-10 and 21-30 (~20 shift per URL) in early phase, then jump to
# 61-70 (~40 shift) in snap 4 to spike cumulative volatility past the >=60
# algorithm_shift threshold.
#
# Companion URLs: rotate domains every snapshot (alpha, beta, gamma, delta, zeta)
# to keep domain similarity low across all pairs, collapsing averageSimilarity.

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ecCausalQ);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_ecCausalId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ecCausalQ } | Select-Object -First 1).id
    }
} catch {}

if ($_ecCausalId) {
    $ct0 = (Get-Date).AddMinutes(-25).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct1 = (Get-Date).AddMinutes(-20).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct2 = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct3 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct4 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    # ── Helper: build shared URLs at given rank offset ──
    # Shared URLs always present so volatility can measure rank shifts.
    # Offset 0 → ranks 1-10; offset 20 → ranks 21-30.
    function New-ECSharedItems($rankOffset) {
        $items = @()
        for ($i = 1; $i -le 10; $i++) {
            $items += @{type="organic"; url="https://shared.com/a$i"; rank_absolute=($i + $rankOffset)}
        }
        return ,$items
    }

    # ── Helper: build companion organic URLs for a domain ──
    function New-ECCompanionItems($domain, $startRank) {
        $items = @()
        for ($i = 1; $i -le 5; $i++) {
            $items += @{type="organic"; url="https://$domain/c$i"; rank_absolute=($startRank + $i - 1)}
        }
        return ,$items
    }

    # Snap 0: shared at ranks 1-10, alpha companions at 11-15, feature: featured_snippet
    $items0 = (New-ECSharedItems 0) + (New-ECCompanionItems "alpha.com" 11) + @(
        @{type="featured_snippet"; url="https://alpha.com/fs"; rank_absolute=0}
    )

    # Snap 1: shared at ranks 21-30 (shift +20), beta companions at 31-35, feature: people_also_ask
    $items1 = (New-ECSharedItems 20) + (New-ECCompanionItems "beta.com" 31) + @(
        @{type="people_also_ask"; url="https://beta.com/paa"; rank_absolute=0}
    )

    # Snap 2: shared at ranks 1-10 (shift back), gamma companions at 11-15, feature: knowledge_graph
    $items2 = (New-ECSharedItems 0) + (New-ECCompanionItems "gamma.com" 11) + @(
        @{type="knowledge_graph"; url="https://gamma.com/kg"; rank_absolute=0}
    )

    # Snap 3: shared at ranks 21-30 (shift +20 again), delta companions at 31-35, feature: featured_snippet
    $items3 = (New-ECSharedItems 20) + (New-ECCompanionItems "delta.com" 31) + @(
        @{type="featured_snippet"; url="https://delta.com/fs2"; rank_absolute=0}
    )

    # Snap 4: shared at ranks 61-70 (shift +40), zeta companions at 71-75, NO features
    # Rotating companion domains across ALL snaps keeps domain similarity low cumulatively.
    # Large final displacement pushes vol past 60; domain+feature collapse tanks similarity.
    $items4 = (New-ECSharedItems 60) + (New-ECCompanionItems "zeta.com" 71)

    $snapDefs = @(
        @{ capturedAt=$ct0; items=$items0 }
        @{ capturedAt=$ct1; items=$items1 }
        @{ capturedAt=$ct2; items=$items2 }
        @{ capturedAt=$ct3; items=$items3 }
        @{ capturedAt=$ct4; items=$items4 }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_ecCausalQ; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus="absent"
            rawPayload=@{items=$def.items}
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 15 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_ecSetupOk = $allCreated
}

# =============================================================================
# Setup -- stable KT (identical snapshots → all stable → 0 patterns)
# =============================================================================

try {
    $rKw2 = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ecStableQ);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw2.StatusCode -eq 201) {
        $_ecStableId = (($rKw2.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ecStableQ } | Select-Object -First 1).id
    }
} catch {}

if ($_ecStableId) {
    $st0 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $st1 = (Get-Date).AddMinutes(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $st2 = (Get-Date).AddMinutes(-4).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $stableItems = @(
        @{type="organic"; url="https://stable.com/p1"; rank_absolute=1}
        @{type="organic"; url="https://stable.com/p2"; rank_absolute=2}
        @{type="organic"; url="https://stable.com/p3"; rank_absolute=3}
    )

    $stableOk = $true
    foreach ($ts in @($st0,$st1,$st2)) {
        $body = @{
            query=$_ecStableQ; locale="en-US"; device="desktop"
            capturedAt=$ts; source="dataforseo"; aiOverviewStatus="absent"
            rawPayload=@{items=$stableItems}
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $stableOk = $false }
        } catch { $stableOk = $false }
    }
    $_ecStableOk = $stableOk
}

# =============================================================================
# EC-A: 400 on invalid UUID
# =============================================================================
try {
    Write-Host "Testing: EC-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$bid/event-causality" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-B: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: EC-B 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ecCausalId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecCausalId/event-causality" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-C: valid request returns required top-level fields
# =============================================================================
try {
    Write-Host "Testing: EC-C valid request returns required fields" -NoNewline
    if (-not $_ecSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecCausalId/event-causality" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $topRequired = @("keywordTargetId","query","locale","device","timelineCount","patternCount","patterns")
            $topProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $missingTop = $topRequired | Where-Object { $topProps -notcontains $_ }

            $failures = @()
            if ($missingTop.Count -gt 0) { $failures += "missing top: $($missingTop -join ', ')" }
            if ($d.keywordTargetId -ne $_ecCausalId) { $failures += "keywordTargetId mismatch" }
            if ($null -eq $d.timelineCount -or $d.timelineCount -lt 0) { $failures += "bad timelineCount" }
            if ($null -eq $d.patternCount -or $d.patternCount -lt 0) { $failures += "bad patternCount" }
            if ($d.patterns -isnot [System.Collections.IEnumerable]) { $failures += "patterns not array" }

            if ($d.patterns.Count -gt 0) {
                $entry = $d.patterns[0]
                $entryProps = $entry | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $entryRequired = @("fromCapturedAt","toCapturedAt","fromEvent","toEvent","pattern","confidence")
                $missingEntry = $entryRequired | Where-Object { $entryProps -notcontains $_ }
                if ($missingEntry.Count -gt 0) { $failures += "missing pattern fields: $($missingEntry -join ', ')" }
            }

            if ($failures.Count -eq 0) { Write-Host ("  PASS (patternCount=$($d.patternCount))") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-D: determinism (two calls identical)
# =============================================================================
try {
    Write-Host "Testing: EC-D determinism (two calls identical)" -NoNewline
    if (-not $_ecSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_ecBase/$_ecCausalId/event-causality"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (responses differ)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-E: stable-only timeline returns patternCount = 0
# =============================================================================
try {
    Write-Host "Testing: EC-E stable-only timeline returns patternCount=0" -NoNewline
    if (-not $_ecStableOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecStableId/event-causality" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            if ($d.patternCount -eq 0 -and $d.patterns.Count -eq 0) {
                Write-Host "  PASS (0 patterns)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (expected 0 patterns, got $($d.patternCount))") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-F: known fixture produces feature_turbulence_to_algorithm_shift
# =============================================================================
try {
    Write-Host "Testing: EC-F known fixture produces feature_turbulence_to_algorithm_shift" -NoNewline
    if (-not $_ecSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        # Debug: fetch event-timeline to see raw classifications
        $rtl = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecCausalId/event-timeline" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $tlDebug = ""
        if ($rtl.StatusCode -eq 200) {
            $dtl = ($rtl.Content | ConvertFrom-Json).data
            $tlDebug = ($dtl.timeline | ForEach-Object { "$($_.event)($($_.confidence))" }) -join " -> "
        }

        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecCausalId/event-causality" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $targetPattern = $d.patterns | Where-Object { $_.pattern -eq "feature_turbulence_to_algorithm_shift" }
            if ($targetPattern) {
                $failures = @()
                if ($targetPattern.fromEvent -ne "feature_turbulence") { $failures += "fromEvent: $($targetPattern.fromEvent)" }
                if ($targetPattern.toEvent -ne "algorithm_shift") { $failures += "toEvent: $($targetPattern.toEvent)" }
                if ($targetPattern.confidence -lt 50 -or $targetPattern.confidence -gt 100) { $failures += "confidence out of range: $($targetPattern.confidence)" }
                if ([string]::IsNullOrWhiteSpace($targetPattern.fromCapturedAt)) { $failures += "missing fromCapturedAt" }
                if ([string]::IsNullOrWhiteSpace($targetPattern.toCapturedAt)) { $failures += "missing toCapturedAt" }

                if ($failures.Count -eq 0) {
                    Write-Host ("  PASS (confidence=$($targetPattern.confidence))") -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                $labels = ($d.patterns | ForEach-Object { $_.pattern }) -join ", "
                Write-Host ("  FAIL (pattern not found; timeline=$tlDebug; patterns=$labels; tl=$($d.timelineCount) p=$($d.patternCount))") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# EC-G: POST rejected (404 or 405)
# =============================================================================
try {
    Write-Host "Testing: EC-G POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ecCausalId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ecBase/$_ecCausalId/event-causality" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
