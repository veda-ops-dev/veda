# hammer-change-classification.ps1 -- SIL-12 SERP Change Classification
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/change-classification
#
# Two KTs are created:
#
#   $_ccKtId      (volatile)  -- 4 snapshots engineered to trigger algorithm_shift:
#                                5 shared URLs with large rank swaps (1-5 vs 25-29) across
#                                consecutive pairs + rotating non-shared domains + AI flips.
#     snap0: shared.com/a1-a5 @ ranks 1-5,  wiki.org/x1-x5 @ 6-10,  featured_snippet, absent
#     snap1: shared.com/a1-a5 @ ranks 25-29, reddit.com/r1-r5 @ 1-5, video,           present
#     snap2: shared.com/a1-a5 @ ranks 1-5,  medium.com/m1-m5 @ 6-10, featured_snippet, absent
#     snap3: shared.com/a1-a5 @ ranks 25-29, nytimes.com/n1-n5 @ 1-5, shopping,        present
#     Expected: high rank shift (24 per shared URL), AI churn 3/3, low similarity -> algorithm_shift
#
#   $_ccStableId  (stable)    -- 3 identical snapshots, no signal change.
#     Expected: classification=stable

Hammer-Section "CHANGE CLASSIFICATION TESTS"

$_ccBase      = "/api/seo/keyword-targets"
$_ccRunId     = (Get-Date).Ticks
$_ccQuery     = "cc-volatile-$_ccRunId"
$_ccStableQ   = "cc-stable-$_ccRunId"
$_ccKtId      = $null
$_ccStableId  = $null
$_ccSetupOk   = $false
$_ccStableOk  = $false

# =============================================================================
# Setup -- volatile KT
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ccQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_ccKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ccQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_ccKtId) {
    $t0 = (Get-Date).AddMinutes(-12).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-9).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-6).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t3 = (Get-Date).AddMinutes(-3).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    # 5 shared URLs (shared.com/a1-a5) oscillate between ranks 1-5 and 25-29
    # across consecutive pairs, producing rank shift of 24 per URL (saturates cap).
    # 5 rotating non-shared domain URLs keep domain similarity low.
    # AI overview flips every pair (3/3). Feature types rotate (2 changes/pair).
    # Result: volatilityScore ~78, averageSimilarity ~0.17 -> algorithm_shift.

    $snap0Items = @(
        @{type="organic"; url="https://shared.com/a1"; rank_absolute=1}
        @{type="organic"; url="https://shared.com/a2"; rank_absolute=2}
        @{type="organic"; url="https://shared.com/a3"; rank_absolute=3}
        @{type="organic"; url="https://shared.com/a4"; rank_absolute=4}
        @{type="organic"; url="https://shared.com/a5"; rank_absolute=5}
        @{type="organic"; url="https://wiki.org/x1"; rank_absolute=6}
        @{type="organic"; url="https://wiki.org/x2"; rank_absolute=7}
        @{type="organic"; url="https://wiki.org/x3"; rank_absolute=8}
        @{type="organic"; url="https://wiki.org/x4"; rank_absolute=9}
        @{type="organic"; url="https://wiki.org/x5"; rank_absolute=10}
        @{type="featured_snippet"; url="https://wiki.org/fs"; rank_absolute=0}
    )
    $snap1Items = @(
        @{type="organic"; url="https://shared.com/a1"; rank_absolute=25}
        @{type="organic"; url="https://shared.com/a2"; rank_absolute=26}
        @{type="organic"; url="https://shared.com/a3"; rank_absolute=27}
        @{type="organic"; url="https://shared.com/a4"; rank_absolute=28}
        @{type="organic"; url="https://shared.com/a5"; rank_absolute=29}
        @{type="organic"; url="https://reddit.com/r1"; rank_absolute=1}
        @{type="organic"; url="https://reddit.com/r2"; rank_absolute=2}
        @{type="organic"; url="https://reddit.com/r3"; rank_absolute=3}
        @{type="organic"; url="https://reddit.com/r4"; rank_absolute=4}
        @{type="organic"; url="https://reddit.com/r5"; rank_absolute=5}
        @{type="video"; url="https://reddit.com/vid"; rank_absolute=0}
    )
    $snap2Items = @(
        @{type="organic"; url="https://shared.com/a1"; rank_absolute=1}
        @{type="organic"; url="https://shared.com/a2"; rank_absolute=2}
        @{type="organic"; url="https://shared.com/a3"; rank_absolute=3}
        @{type="organic"; url="https://shared.com/a4"; rank_absolute=4}
        @{type="organic"; url="https://shared.com/a5"; rank_absolute=5}
        @{type="organic"; url="https://medium.com/m1"; rank_absolute=6}
        @{type="organic"; url="https://medium.com/m2"; rank_absolute=7}
        @{type="organic"; url="https://medium.com/m3"; rank_absolute=8}
        @{type="organic"; url="https://medium.com/m4"; rank_absolute=9}
        @{type="organic"; url="https://medium.com/m5"; rank_absolute=10}
        @{type="featured_snippet"; url="https://medium.com/fs"; rank_absolute=0}
    )
    $snap3Items = @(
        @{type="organic"; url="https://shared.com/a1"; rank_absolute=25}
        @{type="organic"; url="https://shared.com/a2"; rank_absolute=26}
        @{type="organic"; url="https://shared.com/a3"; rank_absolute=27}
        @{type="organic"; url="https://shared.com/a4"; rank_absolute=28}
        @{type="organic"; url="https://shared.com/a5"; rank_absolute=29}
        @{type="organic"; url="https://nytimes.com/n1"; rank_absolute=1}
        @{type="organic"; url="https://nytimes.com/n2"; rank_absolute=2}
        @{type="organic"; url="https://nytimes.com/n3"; rank_absolute=3}
        @{type="organic"; url="https://nytimes.com/n4"; rank_absolute=4}
        @{type="organic"; url="https://nytimes.com/n5"; rank_absolute=5}
        @{type="shopping"; url="https://nytimes.com/shop"; rank_absolute=0}
    )

    $snapDefs = @(
        @{ capturedAt=$t0; aiOverview="absent";  items=$snap0Items }
        @{ capturedAt=$t1; aiOverview="present"; items=$snap1Items }
        @{ capturedAt=$t2; aiOverview="absent";  items=$snap2Items }
        @{ capturedAt=$t3; aiOverview="present"; items=$snap3Items }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_ccQuery; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus=$def.aiOverview
            rawPayload=@{items=$def.items}
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 15 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_ccSetupOk = $allCreated
}

# =============================================================================
# Setup -- stable KT
# =============================================================================

try {
    $rKw2 = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ccStableQ);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw2.StatusCode -eq 201) {
        $_ccStableId = (($rKw2.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ccStableQ } | Select-Object -First 1).id
    }
} catch {}

if ($_ccStableId) {
    $ts0 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ts1 = (Get-Date).AddMinutes(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ts2 = (Get-Date).AddMinutes(-4).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $stableItems = @(
        @{type="organic"; url="https://stable.com/p1"; rank_absolute=1}
        @{type="organic"; url="https://stable.com/p2"; rank_absolute=2}
        @{type="organic"; url="https://stable.com/p3"; rank_absolute=3}
    )

    $stableOk = $true
    foreach ($ts in @($ts0,$ts1,$ts2)) {
        $body = @{
            query=$_ccStableQ; locale="en-US"; device="desktop"
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
    $_ccStableOk = $stableOk
}

# =============================================================================
# CC-A: 400 on invalid UUID
# =============================================================================
try {
    Write-Host "Testing: CC-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$bid/change-classification" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# CC-B: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: CC-B 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ccKtId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$_ccKtId/change-classification" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# CC-C: valid request returns expected response shape + valid classification
# =============================================================================
try {
    Write-Host "Testing: CC-C valid request returns required fields + valid classification" -NoNewline
    if (-not $_ccSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$_ccKtId/change-classification" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $topRequired  = @("keywordTargetId","query","locale","device","windowDays","snapshotCount","classification","confidence","signals")
            $sigRequired  = @("volatility","similarity","intentDrift","featureVolatility","dominanceChange","aiOverviewChurn")
            $validLabels  = @("algorithm_shift","competitor_surge","intent_shift","feature_turbulence","ai_overview_disruption","stable")

            $topProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $missingTop = $topRequired | Where-Object { $topProps -notcontains $_ }

            $sigProps    = $d.signals | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $missingSig  = $sigRequired | Where-Object { $sigProps -notcontains $_ }

            $classOk     = $validLabels -contains $d.classification
            $confOk      = [int]$d.confidence -ge 0 -and [int]$d.confidence -le 100

            $failures = @()
            if ($missingTop.Count -gt 0) { $failures += "missing top: $($missingTop -join ', ')" }
            if ($missingSig.Count -gt 0) { $failures += "missing signals: $($missingSig -join ', ')" }
            if (-not $classOk)  { $failures += "invalid classification: $($d.classification)" }
            if (-not $confOk)   { $failures += "confidence out of range: $($d.confidence)" }

            if ($failures.Count -eq 0) { Write-Host ("  PASS (classification=$($d.classification) confidence=$($d.confidence))") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# CC-D: determinism (two calls return identical JSON)
# =============================================================================
try {
    Write-Host "Testing: CC-D determinism (two calls identical)" -NoNewline
    if (-not $_ccSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_ccBase/$_ccKtId/change-classification"
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
# CC-F: volatile KT returns classification = algorithm_shift
# =============================================================================
try {
    Write-Host "Testing: CC-F volatile KT returns algorithm_shift" -NoNewline
    if (-not $_ccSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$_ccKtId/change-classification" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            if ($d.classification -eq "algorithm_shift") {
                Write-Host ("  PASS (confidence=$($d.confidence))") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (classification=$($d.classification), expected algorithm_shift)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# CC-E: stable keyword returns classification=stable
# =============================================================================
try {
    Write-Host "Testing: CC-E stable keyword returns classification=stable" -NoNewline
    if (-not $_ccStableOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$_ccStableId/change-classification" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            if ($d.classification -eq "stable") {
                Write-Host ("  PASS (confidence=$($d.confidence))") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (classification=$($d.classification), expected stable)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# CC-G: POST rejected
# =============================================================================
try {
    Write-Host "Testing: CC-G POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ccKtId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ccBase/$_ccKtId/change-classification" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
