# hammer-seo.ps1 — search-performance, quotable-blocks, SIL-1, W5
# Dot-sourced by api-hammer.ps1. Inherits all symbols from hammer-lib.ps1 + coordinator.

Hammer-Section "SEO TESTS (SEARCH PERFORMANCE)"

if (-not $entityId) {
    Write-Host "Skipping SEO search-performance tests: no entities found" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    $spRunId = (Get-Date).Ticks
    $searchPerfBody = @{
        rows = @(@{ query="api-hammer-sp-$spRunId"; pageUrl="https://example.com/test-$spRunId"; impressions=100; clicks=10; ctr=0.1; avgPosition=3.5; dateStart="2026-02-01"; dateEnd="2026-02-07"; entityId=$entityId })
    }
    Test-PostJson "$Base/api/seo/search-performance/ingest" 200 "POST search-performance ingest (valid)"              $Headers $searchPerfBody
    Test-PostJson "$Base/api/seo/search-performance/ingest" 400 "POST search-performance rejects clicks>impressions"  $Headers @{
        rows = @(@{ query="test"; pageUrl="https://example.com/test"; impressions=10; clicks=20; ctr=2.0; avgPosition=1.0; dateStart="2026-02-01"; dateEnd="2026-02-07" })
    }
    if ($OtherHeaders.Count -gt 0) {
        Test-PostJson "$Base/api/seo/search-performance/ingest" 404 "POST search-performance cross-project entity" $OtherHeaders $searchPerfBody
    }
    Test-ResponseEnvelope "$Base/api/seo/search-performance?limit=5"         $Headers "GET search-performance (list envelope)"   $true
    Test-Endpoint "GET" "$Base/api/seo/search-performance?entityId=$entityId" 200 "GET search-performance entityId filter" $Headers
}

Hammer-Section "SEO TESTS (QUOTABLE BLOCKS)"

if (-not $entityId) {
    Write-Host "Skipping SEO quotable-blocks tests: no entities found" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    $qbRunId = (Get-Date).Ticks
    $qbBody  = @{ entityId=$entityId; text="api-hammer quotable block $qbRunId with sufficient length for validation"; claimType="statistic"; sourceCitation="api-hammer-$qbRunId"; topicTag="test" }
    Test-PostJson "$Base/api/quotable-blocks" 201 "POST quotable-blocks (valid)"           $Headers $qbBody
    $badClaim = $qbBody.Clone(); $badClaim.claimType = "invalid"
    Test-PostJson "$Base/api/quotable-blocks" 400 "POST quotable-blocks invalid claimType" $Headers $badClaim
    if ($OtherHeaders.Count -gt 0) {
        Test-PostJson "$Base/api/quotable-blocks" 404 "POST quotable-blocks cross-project entity" $OtherHeaders $qbBody
    }
    Test-ResponseEnvelope "$Base/api/quotable-blocks?limit=5" $Headers "GET quotable-blocks (list envelope)" $true
}

Hammer-Section "SIL-1 TESTS (KEYWORD TARGETS)"

$ktRunId       = (Get-Date).Ticks
$ktBody        = @{ query="  Best CRM  Software $ktRunId  "; locale="en-US"; device="desktop"; isPrimary=$true }
$ktExpected    = "best crm software $ktRunId"

$ktResult = Test-PostJsonCapture "$Base/api/seo/keyword-targets" 201 "POST keyword-targets (valid, normalization)" $Headers $ktBody
if ($ktResult.ok) {
    Write-Host "Testing: keyword-target query normalized correctly" -NoNewline
    if ($ktResult.data -and $ktResult.data.query -eq $ktExpected) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got '" + $ktResult.data.query + "', expected '$ktExpected')") -ForegroundColor Red; Hammer-Record FAIL }
} else { Write-Host "Testing: keyword-target query normalized correctly  SKIP (create failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }

Test-PostJson "$Base/api/seo/keyword-targets" 409 "POST keyword-targets (duplicate -> 409)"       $Headers $ktBody
Test-PostJson "$Base/api/seo/keyword-targets" 400 "POST keyword-targets (invalid device -> 400)"  $Headers @{ query="test query $ktRunId"; locale="en-US"; device="tablet" }

try {
    Write-Host "Testing: POST keyword-targets (malformed JSON -> 400)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets" -Method POST -Headers $Headers -Body "not json{" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

if ($OtherHeaders.Count -gt 0) {
    $ktCrossBody = @{ query="cross project probe $ktRunId"; locale="en-US"; device="desktop" }
    Test-PostJson "$Base/api/seo/keyword-targets" 201 "POST keyword-targets (cross-project setup in A)"          $Headers      $ktCrossBody
    Test-PostJson "$Base/api/seo/keyword-targets" 201 "POST keyword-targets (cross-project B creates independently)" $OtherHeaders $ktCrossBody
}

Hammer-Section "SIL-1 TESTS (SERP SNAPSHOTS)"

$ssRunId      = (Get-Date).Ticks
$ssCapturedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$ssBody = @{ query="serp hammer $ssRunId"; locale="en-US"; device="desktop"; capturedAt=$ssCapturedAt; rawPayload=@{results=@();features=@()}; source="dataforseo"; batchRef="hammer-$ssRunId" }

$ssResult = Test-PostJsonCapture "$Base/api/seo/serp-snapshots" 201 "POST serp-snapshots (valid)" $Headers $ssBody
if ($ssResult.ok) {
    Write-Host "Testing: serp-snapshot aiOverviewStatus default populated" -NoNewline
    if ($ssResult.data -and $ssResult.data.aiOverviewStatus) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host "  FAIL" -ForegroundColor Red; Hammer-Record FAIL }
} else { Write-Host "Testing: serp-snapshot aiOverviewStatus default populated  SKIP (create failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }

Test-PostJson "$Base/api/seo/serp-snapshots" 200 "POST serp-snapshots (idempotent replay -> 200)" $Headers $ssBody
Test-PostJson "$Base/api/seo/serp-snapshots" 400 "POST serp-snapshots (invalid aiOverviewStatus -> 400)" $Headers @{ query="test aio $ssRunId"; locale="en-US"; device="desktop"; rawPayload=@{results=@()}; source="dataforseo"; aiOverviewStatus="maybe" }

try {
    Write-Host "Testing: POST serp-snapshots (malformed JSON -> 400)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers -Body "{broken" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Test-PostJson "$Base/api/seo/serp-snapshots" 400 "POST serp-snapshots (invalid capturedAt -> 400)"      $Headers @{ query="test date $ssRunId";   locale="en-US"; device="desktop"; capturedAt="not-a-date"; rawPayload=@{results=@()}; source="dataforseo" }
Test-PostJson "$Base/api/seo/serp-snapshots" 400 "POST serp-snapshots (source not in allowlist -> 400)" $Headers @{ query="test source $ssRunId"; locale="en-US"; device="desktop"; rawPayload=@{results=@()}; source="other" }

Hammer-Section "SIL-1 LIST TESTS (KEYWORD TARGETS READ SURFACE)"

$ssNormalizedQuery = "serp hammer $ssRunId"

try {
    Write-Host "Testing: GET keyword-targets (basic list -> 200, envelope)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json
        if ($p.data -ne $null -and $p.pagination -ne $null -and $p.pagination.total -ge 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (missing data/pagination or total < 0)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: GET keyword-targets device=desktop filter (all items match)" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/keyword-targets" @{device="desktop"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json; $allOk = $true
        foreach ($item in $p.data) { if ($item.device -ne "desktop") { $allOk=$false; break } }
        if ($allOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (non-desktop item in result)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Test-Endpoint "GET" (Build-Url "/api/seo/keyword-targets" @{device="tablet"})    400 "GET keyword-targets invalid device -> 400"    $Headers
Test-Endpoint "GET" (Build-Url "/api/seo/keyword-targets" @{isPrimary="1"})      400 "GET keyword-targets isPrimary=1 -> 400"        $Headers
Test-Endpoint "GET" (Build-Url "/api/seo/keyword-targets" @{isPrimary="yes"})    400 "GET keyword-targets isPrimary=yes -> 400"      $Headers

try {
    Write-Host "Testing: GET keyword-targets ordering deterministic (createdAt desc, id tiebreak)" -NoNewline
    $o1 = Try-GetJson -Url "$Base/api/seo/keyword-targets?limit=20" -RequestHeaders $Headers
    $o2 = Try-GetJson -Url "$Base/api/seo/keyword-targets?limit=20" -RequestHeaders $Headers
    if ($o1 -and $o2 -and $o1.data -and $o2.data) {
        $ids1 = $o1.data | ForEach-Object { $_.id }; $ids2 = $o2.data | ForEach-Object { $_.id }
        $orderOk = ($ids1.Count -eq $ids2.Count)
        if ($orderOk) { for ($i=0; $i -lt $ids1.Count; $i++) { if ($ids1[$i] -ne $ids2[$i]) { $orderOk=$false; break } } }
        $createdOk = $true
        for ($i=0; $i -lt ($o1.data.Count - 1); $i++) {
            if ([datetime]::Parse($o1.data[$i].createdAt) -lt [datetime]::Parse($o1.data[$i+1].createdAt)) { $createdOk=$false; break }
        }
        if ($orderOk -and $createdOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (ordering not deterministic or createdAt not descending)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  SKIP (no keyword targets to order)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: GET keyword-targets isPrimary=true filter (all items match)" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/keyword-targets" @{isPrimary="true"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json; $allOk = $true
        foreach ($item in $p.data) { if ($item.isPrimary -ne $true) { $allOk=$false; break } }
        if ($allOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (non-primary item in isPrimary=true result)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Hammer-Section "SIL-1 LIST TESTS (SERP SNAPSHOTS READ SURFACE)"

try {
    Write-Host "Testing: GET serp-snapshots (basic list -> 200, envelope)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json
        if ($p.data -ne $null -and $p.pagination -ne $null -and $p.pagination.total -ge 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (missing data/pagination or total < 0)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: GET serp-snapshots includePayload=false -> rawPayload absent" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-snapshots" @{includePayload="false";limit="5"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json; $absent = $true
        foreach ($item in $p.data) { $props = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name; if ($props -contains "rawPayload") { $absent=$false; break } }
        if ($absent) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (rawPayload present when includePayload=false)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: GET serp-snapshots includePayload=true -> rawPayload present" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-snapshots" @{includePayload="true";limit="5"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json
        if ($p.data.Count -eq 0) { Write-Host "  SKIP (no snapshots)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
            $present = $true
            foreach ($item in $p.data) { $props = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name; if (-not ($props -contains "rawPayload")) { $present=$false; break } }
            if ($present) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (rawPayload absent when includePayload=true)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Test-Endpoint "GET" (Build-Url "/api/seo/serp-snapshots" @{from="badvalue"})    400 "GET serp-snapshots from=badvalue -> 400"          $Headers
Test-Endpoint "GET" (Build-Url "/api/seo/serp-snapshots" @{from="2025-01-01"}) 400 "GET serp-snapshots from=date-only (no TZ) -> 400"  $Headers
Test-Endpoint "GET" (Build-Url "/api/seo/serp-snapshots" @{includePayload="1"})   400 "GET serp-snapshots includePayload=1 -> 400"      $Headers
Test-Endpoint "GET" (Build-Url "/api/seo/serp-snapshots" @{includePayload="yes"}) 400 "GET serp-snapshots includePayload=yes -> 400"    $Headers

try {
    Write-Host "Testing: GET serp-snapshots ordering deterministic (capturedAt desc, id tiebreak)" -NoNewline
    $o1 = Try-GetJson -Url "$Base/api/seo/serp-snapshots?limit=20" -RequestHeaders $Headers
    $o2 = Try-GetJson -Url "$Base/api/seo/serp-snapshots?limit=20" -RequestHeaders $Headers
    if ($o1 -and $o2 -and $o1.data -and $o2.data) {
        $ids1 = $o1.data | ForEach-Object { $_.id }; $ids2 = $o2.data | ForEach-Object { $_.id }
        $orderOk = ($ids1.Count -eq $ids2.Count)
        if ($orderOk) { for ($i=0; $i -lt $ids1.Count; $i++) { if ($ids1[$i] -ne $ids2[$i]) { $orderOk=$false; break } } }
        $capturedOk = $true
        for ($i=0; $i -lt ($o1.data.Count - 1); $i++) {
            if ([datetime]::Parse($o1.data[$i].capturedAt) -lt [datetime]::Parse($o1.data[$i+1].capturedAt)) { $capturedOk=$false; break }
        }
        if ($orderOk -and $capturedOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (ordering not deterministic or capturedAt not descending)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  SKIP (no serp snapshots to order)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

if (-not $ssResult.ok) {
    Write-Host "Testing: GET serp-snapshots filter by query (normalized)  SKIP (POST snapshot failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    try {
        Write-Host "Testing: GET serp-snapshots filter by query -> only matching items" -NoNewline
        $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-snapshots" @{query=$ssNormalizedQuery;limit="20"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $p = $resp.Content | ConvertFrom-Json; $allMatch=$true; $containsOurs=$false
            foreach ($item in $p.data) {
                if ($item.query -ne $ssNormalizedQuery) { $allMatch=$false }
                if ($item.query -eq $ssNormalizedQuery) { $containsOurs=$true }
            }
            if ($allMatch -and $containsOurs) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (filter returned non-matching items or did not include our snapshot)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
}

try {
    Write-Host "Testing: GET serp-snapshots from/to range filter -> capturedAt within bounds" -NoNewline
    $fromVal = "2020-01-01T00:00:00Z"
    $toVal   = (Get-Date).AddDays(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-snapshots" @{from=$fromVal;to=$toVal;limit="20"}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json; $fromDt=[datetime]::Parse($fromVal); $toDt=[datetime]::Parse($toVal); $inRange=$true
        foreach ($item in $p.data) { $cAt=[datetime]::Parse($item.capturedAt); if ($cAt -lt $fromDt -or $cAt -gt $toDt) { $inRange=$false; break } }
        if ($inRange) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (items outside from/to range)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Hammer-Section "W5 TESTS (OPERATOR SERP SNAPSHOT INGEST)"

$w5RunId   = (Get-Date).Ticks
$w5Query   = "W5 Hammer Query $w5RunId"
$w5Base    = @{ query=$w5Query; locale="en-US"; device="desktop" }

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot confirm=false -> 200 + confirm_required" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body ($w5Base + @{confirm=$false} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d -ne $null -and $d.confirm_required -eq $true -and $null -ne $d.estimated_cost) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (missing confirm_required or estimated_cost)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# Track whether the confirm=true write succeeded so the replay test can depend on it.
$w5WriteOk = $false

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot confirm=true -> 201 + snapshot fields" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body ($w5Base + @{confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d -ne $null -and $null -ne $d.query -and $null -ne $d.locale -and $null -ne $d.device -and $null -ne $d.capturedAt) {
            $w5WriteOk = $true
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host "  FAIL (missing required snapshot fields)" -ForegroundColor Red; Hammer-Record FAIL }
    } elseif ($resp.StatusCode -eq 502) {
        # DataForSEO credentials not configured in this environment — structural SKIP.
        $errBody = try { ($resp.Content | ConvertFrom-Json) } catch { $null }
        $isProviderError = $errBody -and ($errBody.error -eq "provider_error" -or $errBody.message -like "*credentials missing*")
        if ($isProviderError) { Write-Host "  SKIP (DataForSEO credentials not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
        else { Write-Host ("  FAIL (got 502, expected 201; body: " + $resp.Content.Substring(0, [Math]::Min(120, $resp.Content.Length)) + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot replay -> 200 or 201 (idempotency timing-sensitive)" -NoNewline
    if (-not $w5WriteOk) {
        Write-Host "  SKIP (confirm=true write did not succeed; replay not testable)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body ($w5Base + @{confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200 -or $resp.StatusCode -eq 201) { Write-Host ("  PASS (" + $resp.StatusCode + ")") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200 or 201)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot confirm=string -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body ('{"query":"' + $w5Query + '","locale":"en-US","device":"desktop","confirm":"true"}') -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot device=tablet -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body (@{query=$w5Query;locale="en-US";device="tablet";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: POST /api/seo/serp-snapshot malformed JSON -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $Headers -Body "{not valid json{" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: POST /api/seo/serp-snapshot cross-project write -> 201 (isolated)" -NoNewline
        if (-not $w5WriteOk) {
            Write-Host "  SKIP (DataForSEO credentials not configured; provider writes unavailable)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshot" -Method POST -Headers $OtherHeaders -Body ($w5Base + @{confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 201) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } elseif ($resp.StatusCode -eq 502) {
                # Provider may rate-limit or quota-exhaust on repeated calls within the same run.
                # 200 (recent-window replay) would mean the cross-project isolation leaked -- that
                # is a genuine FAIL. 502 from the provider on a third call is a structural SKIP.
                $errBody = try { ($resp.Content | ConvertFrom-Json) } catch { $null }
                $isProviderError = $errBody -and ($errBody.error -eq "provider_error" -or $errBody.message -like "*credentials missing*")
                if ($isProviderError) { Write-Host "  SKIP (provider error on cross-project call; likely rate limit or quota)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
                else { Write-Host ("  FAIL (got 502, expected 201; body: " + $resp.Content.Substring(0, [Math]::Min(120, $resp.Content.Length)) + ")") -ForegroundColor Red; Hammer-Record FAIL }
            } else {
                Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
}
