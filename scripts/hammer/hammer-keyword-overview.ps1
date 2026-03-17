# hammer-keyword-overview.ps1 -- SIL-15 Keyword Overview Surface
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/overview
#
# Setup: creates one KT with 4 snapshots (enough for meaningful signals).

Hammer-Section "KEYWORD OVERVIEW TESTS"

$_koBase  = "/api/seo/keyword-targets"
$_koRunId = (Get-Date).Ticks
$_koQuery = "ko-overview-$_koRunId"
$_koKtId  = $null
$_koSetupOk = $false

# =============================================================================
# Setup -- create KT + 4 snapshots with varied signals
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_koQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_koKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_koQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_koKtId) {
    $ct0 = (Get-Date).AddMinutes(-30).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct1 = (Get-Date).AddMinutes(-20).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct2 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct3 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt=$ct0; aiOverviewStatus="absent"
            items=@(
                @{type="organic"; url="https://alpha.com/p1"; rank_absolute=1}
                @{type="organic"; url="https://alpha.com/p2"; rank_absolute=2}
                @{type="organic"; url="https://beta.com/p1"; rank_absolute=3}
                @{type="featured_snippet"; url="https://alpha.com/fs"; rank_absolute=0}
            )
        }
        @{
            capturedAt=$ct1; aiOverviewStatus="present"
            items=@(
                @{type="organic"; url="https://alpha.com/p1"; rank_absolute=5}
                @{type="organic"; url="https://gamma.com/p1"; rank_absolute=6}
                @{type="organic"; url="https://delta.com/p1"; rank_absolute=7}
                @{type="people_also_ask"; url="https://gamma.com/paa"; rank_absolute=0}
            )
        }
        @{
            capturedAt=$ct2; aiOverviewStatus="absent"
            items=@(
                @{type="organic"; url="https://alpha.com/p1"; rank_absolute=2}
                @{type="organic"; url="https://alpha.com/p2"; rank_absolute=3}
                @{type="organic"; url="https://beta.com/p1"; rank_absolute=4}
                @{type="featured_snippet"; url="https://alpha.com/fs2"; rank_absolute=0}
                @{type="local_pack"; url="https://maps.example.com/lp"; rank_absolute=0}
            )
        }
        @{
            capturedAt=$ct3; aiOverviewStatus="absent"
            items=@(
                @{type="organic"; url="https://zeta.com/p1"; rank_absolute=1}
                @{type="organic"; url="https://zeta.com/p2"; rank_absolute=2}
                @{type="organic"; url="https://zeta.com/p3"; rank_absolute=3}
            )
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_koQuery; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus=$def.aiOverviewStatus
            rawPayload=@{items=$def.items}
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 15 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_koSetupOk = $allCreated
}

# =============================================================================
# KO-A: 404 for nonexistent keyword target
# =============================================================================
try {
    Write-Host "Testing: KO-A 404 for nonexistent keyword target" -NoNewline
    $fakeId = "00000000-0000-4000-a000-000000009999"
    $r = Invoke-WebRequest -Uri "$Base$_koBase/$fakeId/overview" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-B: 404 cross-project non-disclosure
# =============================================================================
try {
    Write-Host "Testing: KO-B 404 cross-project non-disclosure" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_koKtId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_koBase/$_koKtId/overview" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-C: Response shape validation
# =============================================================================
try {
    Write-Host "Testing: KO-C response shape validation" -NoNewline
    if (-not $_koSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_koBase/$_koKtId/overview" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $required = @("keywordTargetId","query","locale","device","snapshotCount",
                          "latestSnapshot","volatility","classification","timeline",
                          "causality","intentDrift","featureVolatility","domainDominance","serpSimilarity")
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $missing = $required | Where-Object { $props -notcontains $_ }

            $failures = @()
            if ($missing.Count -gt 0) { $failures += "missing: $($missing -join ', ')" }
            if ($d.keywordTargetId -ne $_koKtId) { $failures += "keywordTargetId mismatch" }
            if ($d.snapshotCount -lt 1) { $failures += "snapshotCount < 1" }

            # volatility shape
            if ($d.volatility) {
                $vProps = $d.volatility | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($vf in @("score","regime","maturity","sampleSize","components")) {
                    if ($vProps -notcontains $vf) { $failures += "volatility missing $vf" }
                }
            }

            # classification shape
            if ($d.classification) {
                $cProps = $d.classification | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($cf in @("classification","confidence","signals")) {
                    if ($cProps -notcontains $cf) { $failures += "classification missing $cf" }
                }
            }

            # latestSnapshot shape
            if ($d.latestSnapshot) {
                $lsProps = $d.latestSnapshot | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($lf in @("id","capturedAt","aiOverviewPresent","featureFamilies","topDomains")) {
                    if ($lsProps -notcontains $lf) { $failures += "latestSnapshot missing $lf" }
                }
            } else { $failures += "latestSnapshot is null" }

            if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-D: Deterministic repeated-response test
# =============================================================================
try {
    Write-Host "Testing: KO-D deterministic repeated-response test" -NoNewline
    if (-not $_koSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_koBase/$_koKtId/overview"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 15 -Compress
            $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 15 -Compress
            if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (responses differ)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-E: latestSnapshot summary is compact (no rawPayload, no full result arrays)
# =============================================================================
try {
    Write-Host "Testing: KO-E latestSnapshot is compact (no rawPayload)" -NoNewline
    if (-not $_koSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_koBase/$_koKtId/overview" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $ls = $d.latestSnapshot
            $failures = @()
            if ($null -eq $ls) { $failures += "latestSnapshot is null" }
            else {
                $lsProps = $ls | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($lsProps -contains "rawPayload")   { $failures += "rawPayload must not be present" }
                if ($lsProps -contains "items")        { $failures += "items must not be present" }
                if ($lsProps -contains "results")      { $failures += "results must not be present" }
                # featureFamilies should be an array
                if ($null -eq $ls.featureFamilies)     { $failures += "featureFamilies missing" }
                # topDomains should be an array
                if ($null -eq $ls.topDomains)          { $failures += "topDomains missing" }
                # id must be a string
                if ([string]::IsNullOrWhiteSpace($ls.id)) { $failures += "id missing or empty" }
                # capturedAt must look like ISO
                if ([string]::IsNullOrWhiteSpace($ls.capturedAt)) { $failures += "capturedAt missing" }
            }
            if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-F: timeline deterministic ordering (capturedAt non-decreasing)
# =============================================================================
try {
    Write-Host "Testing: KO-F timeline deterministic ordering" -NoNewline
    if (-not $_koSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_koBase/$_koKtId/overview" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $timeline = $d.timeline
            $failures = @()
            if ($timeline -isnot [System.Collections.IEnumerable]) {
                $failures += "timeline is not an array"
            } else {
                $tArr = @($timeline)
                for ($i = 1; $i -lt $tArr.Count; $i++) {
                    $prev = [DateTime]::Parse($tArr[$i-1].capturedAt)
                    $curr = [DateTime]::Parse($tArr[$i].capturedAt)
                    if ($curr -lt $prev) { $failures += "out-of-order at index $i" }
                }
                # Each entry must have event and confidence
                foreach ($entry in $tArr) {
                    $ep = $entry | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    foreach ($ef in @("capturedAt","event","confidence")) {
                        if ($ep -notcontains $ef) { $failures += "timeline entry missing $ef" }
                    }
                }
            }
            if ($failures.Count -eq 0) { Write-Host ("  PASS (timelineCount=$($d.timeline.Count))") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KO-G: endpoint is read-only (POST returns 404 or 405)
# =============================================================================
try {
    Write-Host "Testing: KO-G endpoint is read-only (POST rejected)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_koKtId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_koBase/$_koKtId/overview" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
