# hammer-event-timeline.ps1 -- SIL-13 SERP Event Timeline
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/event-timeline
#
# Two KTs:
#   $_etVolatileId -- 4 snapshots with domain swaps to trigger classification changes
#   $_etStableId   -- 3 identical snapshots (stable -> single event, no duplicates)

Hammer-Section "EVENT TIMELINE TESTS"

$_etBase       = "/api/seo/keyword-targets"
$_etRunId      = (Get-Date).Ticks
$_etVolatileQ  = "et-volatile-$_etRunId"
$_etStableQ    = "et-stable-$_etRunId"
$_etVolatileId = $null
$_etStableId   = $null
$_etSetupOk    = $false
$_etStableOk   = $false

# =============================================================================
# Setup -- volatile KT (domain swaps → classification transitions)
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_etVolatileQ);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_etVolatileId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_etVolatileQ } | Select-Object -First 1).id
    }
} catch {}

if ($_etVolatileId) {
    $t0 = (Get-Date).AddMinutes(-12).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-9).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-6).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t3 = (Get-Date).AddMinutes(-3).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    function New-ETOrgItems($domain, $count, $extraType) {
        $items = @()
        for ($i = 1; $i -le $count; $i++) {
            $items += @{type="organic"; url="https://$domain/p$i"; rank_absolute=$i}
        }
        if ($extraType) { $items += @{type=$extraType; url="https://$domain/feature"; rank_absolute=0} }
        return ,$items
    }

    $snapDefs = @(
        @{ capturedAt=$t0; aiOverview="absent";  items=(New-ETOrgItems "wikipedia.org" 10 "featured_snippet") }
        @{ capturedAt=$t1; aiOverview="present"; items=(New-ETOrgItems "reddit.com"    10 "video") }
        @{ capturedAt=$t2; aiOverview="absent";  items=(New-ETOrgItems "wikipedia.org" 10 "featured_snippet") }
        @{ capturedAt=$t3; aiOverview="present"; items=(New-ETOrgItems "medium.com"    10 "shopping") }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_etVolatileQ; locale="en-US"; device="desktop"
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
    $_etSetupOk = $allCreated
}

# =============================================================================
# Setup -- stable KT (identical snapshots)
# =============================================================================

try {
    $rKw2 = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_etStableQ);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw2.StatusCode -eq 201) {
        $_etStableId = (($rKw2.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_etStableQ } | Select-Object -First 1).id
    }
} catch {}

if ($_etStableId) {
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
            query=$_etStableQ; locale="en-US"; device="desktop"
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
    $_etStableOk = $stableOk
}

# =============================================================================
# ET-A: 400 on invalid UUID
# =============================================================================
try {
    Write-Host "Testing: ET-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$bid/event-timeline" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ET-B: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: ET-B 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_etVolatileId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$_etVolatileId/event-timeline" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ET-C: valid request returns required top-level fields
# =============================================================================
try {
    Write-Host "Testing: ET-C valid request returns required fields" -NoNewline
    if (-not $_etSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$_etVolatileId/event-timeline" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $topRequired = @("keywordTargetId","query","locale","device","timeline")
            $topProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $missingTop = $topRequired | Where-Object { $topProps -notcontains $_ }

            $validLabels = @("algorithm_shift","competitor_surge","intent_shift","feature_turbulence","ai_overview_disruption","stable")

            $failures = @()
            if ($missingTop.Count -gt 0) { $failures += "missing top: $($missingTop -join ', ')" }
            if ($d.timeline.Count -eq 0) { $failures += "timeline is empty" }

            # Validate timeline entry shape
            if ($d.timeline.Count -gt 0) {
                $entry = $d.timeline[0]
                $entryProps = $entry | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $entryRequired = @("capturedAt","event","confidence")
                $missingEntry = $entryRequired | Where-Object { $entryProps -notcontains $_ }
                if ($missingEntry.Count -gt 0) { $failures += "missing entry fields: $($missingEntry -join ', ')" }
                if ($validLabels -notcontains $entry.event) { $failures += "invalid event: $($entry.event)" }
                if ([int]$entry.confidence -lt 0 -or [int]$entry.confidence -gt 100) { $failures += "confidence out of range: $($entry.confidence)" }
            }

            if ($failures.Count -eq 0) { Write-Host ("  PASS (timeline count=$($d.timeline.Count))") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ET-D: timeline sorted capturedAt ASC
# =============================================================================
try {
    Write-Host "Testing: ET-D timeline sorted capturedAt ASC" -NoNewline
    if (-not $_etSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$_etVolatileId/event-timeline" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $sorted = $true
            for ($i = 1; $i -lt $d.timeline.Count; $i++) {
                if ($d.timeline[$i].capturedAt -lt $d.timeline[$i-1].capturedAt) {
                    $sorted = $false
                    break
                }
            }
            if ($sorted) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (not sorted ASC)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ET-E: duplicate classifications collapse (stable KT → single event)
# =============================================================================
try {
    Write-Host "Testing: ET-E duplicate classifications collapse into single event" -NoNewline
    if (-not $_etStableOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$_etStableId/event-timeline" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            # 3 identical snapshots → all stable → should collapse to exactly 1 event
            if ($d.timeline.Count -eq 1 -and $d.timeline[0].event -eq "stable") {
                Write-Host ("  PASS (1 event, stable)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (expected 1 stable event, got $($d.timeline.Count) events)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ET-F: determinism (two calls identical)
# =============================================================================
try {
    Write-Host "Testing: ET-F determinism (two calls identical)" -NoNewline
    if (-not $_etSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_etBase/$_etVolatileId/event-timeline"
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
# ET-G: POST rejected
# =============================================================================
try {
    Write-Host "Testing: ET-G POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_etVolatileId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_etBase/$_etVolatileId/event-timeline" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
