# hammer-sil2.ps1 — W4 (keyword-research wrapper) + SIL-2 (SERP deltas)
# Dot-sourced by api-hammer.ps1. Inherits all symbols from hammer-lib.ps1 + coordinator.

Hammer-Section "W4 TESTS (KEYWORD RESEARCH WRAPPER)"

$w4RunId   = (Get-Date).Ticks
$w4Keywords = @("best crm software $w4RunId", "  CRM  Comparison $w4RunId  ", "crm pricing $w4RunId")
$w4Locale  = "en-US"
$w4Device  = "desktop"

# W4-1: confirm=false -> 200 + confirm_required + normalized_keywords count
try {
    Write-Host "Testing: POST /api/seo/keyword-research confirm=false -> 200 + confirm_required" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body (@{keywords=$w4Keywords;locale=$w4Locale;device=$w4Device;confirm=$false} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $nkLen = if ($d.normalized_keywords) { $d.normalized_keywords.Count } else { -1 }
        if ($d -ne $null -and $d.confirm_required -eq $true -and $nkLen -eq $w4Keywords.Count) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (missing confirm_required, normalized_keywords, or wrong count)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# W4-2: confirm=true -> 201 + created>=1 + targets sorted asc
try {
    Write-Host "Testing: POST /api/seo/keyword-research confirm=true -> 201 + created>=1 + ordered" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body (@{keywords=$w4Keywords;locale=$w4Locale;device=$w4Device;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $created = if ($null -ne $d.created) { [int]$d.created } else { -1 }
        $targets = $d.targets; $orderOk = $true
        if ($targets -and $targets.Count -gt 1) {
            for ($i=0; $i -lt ($targets.Count - 1); $i++) {
                if ([string]::Compare($targets[$i].query, $targets[$i+1].query, $true) -gt 0) { $orderOk=$false; break }
            }
        }
        if ($created -ge 1 -and $orderOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (created=" + $created + ", orderOk=" + $orderOk + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# W4-3: idempotent replay -> 201 + created=0 + skipped>=1
try {
    Write-Host "Testing: POST /api/seo/keyword-research idempotent replay -> 201 created=0 skipped>=1" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body (@{keywords=$w4Keywords;locale=$w4Locale;device=$w4Device;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $created = if ($null -ne $d.created) { [int]$d.created } else { -1 }
        $skipped = if ($null -ne $d.skipped) { [int]$d.skipped } else { -1 }
        if ($created -eq 0 -and $skipped -ge 1) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (created=" + $created + ", skipped=" + $skipped + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# W4-4: empty keywords -> 400
Test-PostJson "$Base/api/seo/keyword-research" 400 "POST keyword-research empty keywords -> 400" $Headers @{keywords=@();locale=$w4Locale;device=$w4Device;confirm=$false}

# W4-5: 20 keywords -> 400 (max 19)
try {
    Write-Host "Testing: POST /api/seo/keyword-research 20 keywords -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body (@{keywords=(1..20|ForEach-Object{"keyword $_ run $w4RunId"});locale=$w4Locale;device=$w4Device;confirm=$false} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# W4-6: malformed JSON -> 400
try {
    Write-Host "Testing: POST /api/seo/keyword-research malformed JSON -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body "{not valid json{" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# W4-7: cross-project -> 201 + created>=1
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: POST /api/seo/keyword-research cross-project -> 201 (isolated, created>=1)" -NoNewline
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $OtherHeaders -Body (@{keywords=$w4Keywords;locale=$w4Locale;device=$w4Device;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            $created = if ($null -ne ($resp.Content | ConvertFrom-Json).data.created) { [int]($resp.Content | ConvertFrom-Json).data.created } else { -1 }
            if ($created -ge 1) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got 201 but created=" + $created + ")") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
}

# ─────────────────────────────────────────────────────────────────────────────

Hammer-Section "SIL-2 TESTS (SERP DELTAS)"

$sdRunId  = (Get-Date).Ticks
$sdQuery  = "serp delta hammer $sdRunId"
$sdLocale = "en-US"
$sdDevice = "desktop"
$sdKtId   = $null

# Setup: KeywordTarget
try {
    Write-Host "Testing: SIL-2 setup: create KeywordTarget via keyword-research" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers -Body (@{keywords=@($sdQuery);locale=$sdLocale;device=$sdDevice;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $sdKtId = (($resp.Content | ConvertFrom-Json).data.targets | Where-Object { $_.query -eq $sdQuery } | Select-Object -First 1).id
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

if ([string]::IsNullOrWhiteSpace($sdKtId) -or $sdKtId -notmatch '^[0-9a-fA-F-]{36}$') { $sdKtId = $null }

$sdSnapshotId1 = $null
$sdSnapshotId2 = $null

if ($sdKtId) {
    # Snapshot 1 (from): page-a #1, page-b #2, page-c #3; absent
    try {
        Write-Host "Testing: SIL-2 setup: create snapshot 1 (from)" -NoNewline
        $body = @{
            query=$sdQuery; locale=$sdLocale; device=$sdDevice
            capturedAt=(Get-Date).AddMinutes(-10).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            rawPayload=@{results=@(
                @{url="https://example.com/page-a";rank=1;title="Page A"}
                @{url="https://example.com/page-b";rank=2;title="Page B"}
                @{url="https://example.com/page-c";rank=3;title="Page C"}
            )}
            source="dataforseo"; aiOverviewStatus="absent"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) { $sdSnapshotId1 = ($resp.Content | ConvertFrom-Json).data.id; Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # Snapshot 2 (to): page-b #1, page-a #2, page-d #3; page-c exited; present
    try {
        Write-Host "Testing: SIL-2 setup: create snapshot 2 (to)" -NoNewline
        $body = @{
            query=$sdQuery; locale=$sdLocale; device=$sdDevice
            capturedAt=(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            rawPayload=@{results=@(
                @{url="https://example.com/page-b";rank=1;title="Page B"}
                @{url="https://example.com/page-a";rank=2;title="Page A"}
                @{url="https://example.com/page-d";rank=3;title="Page D"}
            )}
            source="dataforseo"; aiOverviewStatus="present"
        }
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201 -or $resp.StatusCode -eq 200) { $sdSnapshotId2 = ($resp.Content | ConvertFrom-Json).data.id; Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
}

# SD-1: missing keywordTargetId -> 400
Test-Endpoint "GET" (Build-Url "/api/seo/serp-deltas" @{})                                                              400 "GET serp-deltas missing keywordTargetId -> 400" $Headers
# SD-2: invalid UUID -> 400
Test-Endpoint "GET" (Build-Url "/api/seo/serp-deltas" @{keywordTargetId="not-a-uuid"})                                  400 "GET serp-deltas invalid UUID -> 400"            $Headers
# SD-3: nonexistent -> 404
Test-Endpoint "GET" (Build-Url "/api/seo/serp-deltas" @{keywordTargetId="00000000-0000-4000-a000-000000000099"})        404 "GET serp-deltas not found -> 404"              $Headers

if ($sdKtId) {
    # SD-4: auto-select -> 200 + delta + AI overview changed
    try {
        Write-Host "Testing: GET serp-deltas auto-select -> 200 + delta + ai_overview changed" -NoNewline
        $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $deltaOk = ($d.delta -ne $null -and $null -ne $d.delta.summary)
            $metaOk  = ($d.metadata -ne $null -and $d.metadata.insufficient_snapshots -eq $false)
            $aioChg  = ($d.delta -ne $null -and $d.delta.ai_overview.changed -eq $true)
            if ($deltaOk -and $metaOk -and $aioChg) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (deltaOk=" + $deltaOk + " metaOk=" + $metaOk + " aioChanged=" + $aioChg + ")") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # SD-5: entered=1, exited=1, moved=2
    try {
        Write-Host "Testing: GET serp-deltas entered/exited/moved counts correct" -NoNewline
        $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $s = ($resp.Content | ConvertFrom-Json).data.delta.summary
            if ($s.entered_count -eq 1 -and $s.exited_count -eq 1 -and $s.moved_count -eq 2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (entered=" + $s.entered_count + " exited=" + $s.exited_count + " moved=" + $s.moved_count + ", expected 1/1/2)") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    # SD-6: only fromSnapshotId without toSnapshotId -> 400
    if ($sdSnapshotId1) {
        Test-Endpoint "GET" (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId;fromSnapshotId=$sdSnapshotId1}) 400 "GET serp-deltas only fromSnapshotId -> 400" $Headers
    }

    # SD-7: explicit pair -> 200 + delta present
    if ($sdSnapshotId1 -and $sdSnapshotId2) {
        try {
            Write-Host "Testing: GET serp-deltas explicit snapshot pair -> 200" -NoNewline
            $resp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId;fromSnapshotId=$sdSnapshotId1;toSnapshotId=$sdSnapshotId2}) -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $delta = ($resp.Content | ConvertFrom-Json).data.delta
                if ($delta -ne $null -and $null -ne $delta.summary) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (missing delta or summary)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }

    # SD-8: cross-project -> 404
    if ($OtherHeaders.Count -gt 0) {
        Test-Endpoint "GET" (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId}) 404 "GET serp-deltas cross-project -> 404" $OtherHeaders
    }
} else {
    Write-Host "Skipping SD-4 through SD-8: KeywordTarget creation failed" -ForegroundColor DarkYellow
    Hammer-Record SKIP; Hammer-Record SKIP; Hammer-Record SKIP; Hammer-Record SKIP; Hammer-Record SKIP
}

# =============================================================================
Hammer-Section "SIL-2 PAYLOAD HETEROGENEITY TORTURE TESTS"
# =============================================================================
# Each sub-group creates its own KeywordTarget + snapshots to avoid
# interference with the main SIL-2 suite above.

$phRunId  = (Get-Date).Ticks
$phLocale = "en-US"
$phDevice = "desktop"

# Helper: create a KeywordTarget and return its id (or null on failure)
function New-PhKeywordTarget {
    param([string]$Query)
    try {
        $r = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
            -Body (@{keywords=@($Query);locale=$phLocale;device=$phDevice;confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
            -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 201) {
            return (($r.Content | ConvertFrom-Json).data.targets |
                Where-Object { $_.query -eq $Query } | Select-Object -First 1).id
        }
    } catch {}
    return $null
}

# Helper: create a snapshot and return its id (or null on failure)
function New-PhSnapshot {
    param([string]$Query, [string]$CapturedAt, [hashtable]$Payload, [string]$AioStatus = "absent")
    try {
        $body = @{
            query=$Query; locale=$phLocale; device=$phDevice
            capturedAt=$CapturedAt; rawPayload=$Payload
            source="dataforseo"; aiOverviewStatus=$AioStatus
        }
        $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
            -Body ($body | ConvertTo-Json -Depth 10 -Compress) `
            -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(200,201)) { return ($r.Content | ConvertFrom-Json).data.id }
    } catch {}
    return $null
}

# Helper: call serp-deltas and return parsed response or null
function Get-SerpDelta {
    param([string]$KtId)
    try {
        $r = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$KtId}) `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) { return $r.Content | ConvertFrom-Json }
    } catch {}
    return $null
}

# ─────────────────────────────────────────────────────────────────────────────
# PH-A: from = {} (no results key), to = normal results
# ─────────────────────────────────────────────────────────────────────────────
$phAQuery = "ph-missing-results $phRunId"
$phAKtId  = New-PhKeywordTarget $phAQuery
$phAOk    = $false

if ($phAKtId) {
    $t0  = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $t1  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $ss1 = New-PhSnapshot $phAQuery $t0 @{} "absent"    # empty object — no results key
    $ss2 = New-PhSnapshot $phAQuery $t1 @{results=@(@{url="https://ex.com/a";rank=1;title="A"})} "absent"
    $phAOk = ($null -ne $ss1 -and $null -ne $ss2)
}

try {
    Write-Host "Testing: serp-deltas from={} to=results -> 200, no crash, entered=1" -NoNewline
    if (-not $phAOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Get-SerpDelta $phAKtId
        if ($null -eq $resp) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            $s = $resp.data.delta.summary
            # from has 0 results -> everything in 'to' is entered
            if ($s.entered_count -eq 1 -and $s.moved_count -eq 0 -and $s.exited_count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (entered=" + $s.entered_count + " moved=" + $s.moved_count + " exited=" + $s.exited_count + ", expected 1/0/0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: serp-deltas from={} payload_parse_warning=true" -NoNewline
    if (-not $phAOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Get-SerpDelta $phAKtId
        if ($null -eq $resp) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            if ($resp.data.metadata.payload_parse_warning -eq $true) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (expected payload_parse_warning=true)" -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ─────────────────────────────────────────────────────────────────────────────
# PH-B: from = { results: [] } (empty array), to = normal results
# ─────────────────────────────────────────────────────────────────────────────
$phBQuery = "ph-empty-results $phRunId"
$phBKtId  = New-PhKeywordTarget $phBQuery
$phBOk    = $false

if ($phBKtId) {
    $t0  = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $t1  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $ss1 = New-PhSnapshot $phBQuery $t0 @{results=@()} "absent"     # empty array
    $ss2 = New-PhSnapshot $phBQuery $t1 @{results=@(
        @{url="https://ex.com/x";rank=1;title="X"}
        @{url="https://ex.com/y";rank=2;title="Y"}
    )} "absent"
    $phBOk = ($null -ne $ss1 -and $null -ne $ss2)
}

try {
    Write-Host "Testing: serp-deltas from={results:[]} to=2 results -> entered=2, exited=0" -NoNewline
    if (-not $phBOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Get-SerpDelta $phBKtId
        if ($null -eq $resp) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            $s = $resp.data.delta.summary
            if ($s.entered_count -eq 2 -and $s.exited_count -eq 0 -and $s.moved_count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (entered=" + $s.entered_count + " exited=" + $s.exited_count + " moved=" + $s.moved_count + ", expected 2/0/0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ─────────────────────────────────────────────────────────────────────────────
# PH-C: mixed rank field names (rank vs position vs rank_absolute)
# Strategy 2 (simple results array) reads: rank, then position.
# ─────────────────────────────────────────────────────────────────────────────
$phCQuery = "ph-mixed-rank $phRunId"
$phCKtId  = New-PhKeywordTarget $phCQuery
$phCOk    = $false

if ($phCKtId) {
    $t0 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $t1 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    # from: uses 'rank' field
    $ss1 = New-PhSnapshot $phCQuery $t0 @{results=@(
        @{url="https://ex.com/p";rank=1;title="P"}
        @{url="https://ex.com/q";rank=2;title="Q"}
    )} "absent"
    # to: uses 'position' field (no 'rank' key)
    $ss2 = New-PhSnapshot $phCQuery $t1 @{results=@(
        @{url="https://ex.com/p";position=2;title="P"}
        @{url="https://ex.com/q";position=1;title="Q"}
    )} "absent"
    $phCOk = ($null -ne $ss1 -and $null -ne $ss2)
}

try {
    Write-Host "Testing: serp-deltas mixed rank/position fields -> 200, moved_count=2 stable" -NoNewline
    if (-not $phCOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r1 = Get-SerpDelta $phCKtId
        $r2 = Get-SerpDelta $phCKtId
        if ($null -eq $r1 -or $null -eq $r2) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            $s1 = $r1.data.delta.summary
            $s2 = $r2.data.delta.summary
            # Both URLs present in both snapshots -> moved_count=2; determinism -> two calls identical
            $movOk = ($s1.moved_count -eq 2)
            $detOk = ($s1.moved_count -eq $s2.moved_count -and $s1.entered_count -eq $s2.entered_count)
            if ($movOk -and $detOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (moved=" + $s1.moved_count + " det=" + $detOk + ", expected moved=2)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ─────────────────────────────────────────────────────────────────────────────
# PH-D: duplicate URLs in same snapshot (first-wins rule)
# from: url /dup appears at rank 1 and rank 3 (first-wins -> rank 1)
# to:   url /dup appears at rank 2 and rank 5 (first-wins -> rank 2)
# ─────────────────────────────────────────────────────────────────────────────
$phDQuery = "ph-duplicate-url $phRunId"
$phDKtId  = New-PhKeywordTarget $phDQuery
$phDOk    = $false

if ($phDKtId) {
    $t0 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $t1 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $ss1 = New-PhSnapshot $phDQuery $t0 @{results=@(
        @{url="https://ex.com/dup";rank=1;title="Dup first"}
        @{url="https://ex.com/other";rank=2;title="Other"}
        @{url="https://ex.com/dup";rank=3;title="Dup second"}   # duplicate
    )} "absent"
    $ss2 = New-PhSnapshot $phDQuery $t1 @{results=@(
        @{url="https://ex.com/other";rank=1;title="Other"}
        @{url="https://ex.com/dup";rank=2;title="Dup first"}
        @{url="https://ex.com/dup";rank=5;title="Dup second"}   # duplicate
    )} "absent"
    $phDOk = ($null -ne $ss1 -and $null -ne $ss2)
}

try {
    Write-Host "Testing: serp-deltas duplicate URLs -> first-wins, deterministic" -NoNewline
    if (-not $phDOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r1 = Get-SerpDelta $phDKtId
        $r2 = Get-SerpDelta $phDKtId
        if ($null -eq $r1 -or $null -eq $r2) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            $s1 = $r1.data.delta.summary
            $s2 = $r2.data.delta.summary
            # After first-wins dedup: from has {dup@1, other@2}, to has {other@1, dup@2}
            # -> both URLs in both snapshots -> moved_count=2, entered=0, exited=0
            $movOk = ($s1.moved_count -eq 2 -and $s1.entered_count -eq 0 -and $s1.exited_count -eq 0)
            $detOk = ($s1.moved_count -eq $s2.moved_count -and $s1.entered_count -eq $s2.entered_count -and $s1.exited_count -eq $s2.exited_count)
            if ($movOk -and $detOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (moved=" + $s1.moved_count + " entered=" + $s1.entered_count + " exited=" + $s1.exited_count + " det=" + $detOk + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ─────────────────────────────────────────────────────────────────────────────
# PH-E: results with missing url/domain fields are silently ignored
# ─────────────────────────────────────────────────────────────────────────────
$phEQuery = "ph-missing-url $phRunId"
$phEKtId  = New-PhKeywordTarget $phEQuery
$phEOk    = $false

if ($phEKtId) {
    $t0 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $t1 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $ss1 = New-PhSnapshot $phEQuery $t0 @{results=@(
        @{url="https://ex.com/good";rank=1;title="Good"}
        @{rank=2;title="No URL"}           # no url field -> ignored
        @{url=$null;rank=3;title="Null"}   # null url -> ignored by extractor
    )} "absent"
    $ss2 = New-PhSnapshot $phEQuery $t1 @{results=@(
        @{url="https://ex.com/good";rank=1;title="Good"}
        @{rank=2;title="Still no URL"}     # no url field -> ignored
    )} "absent"
    $phEOk = ($null -ne $ss1 -and $null -ne $ss2)
}

try {
    Write-Host "Testing: serp-deltas missing url entries silently ignored, no crash" -NoNewline
    if (-not $phEOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Get-SerpDelta $phEKtId
        if ($null -eq $resp) { Write-Host "  FAIL (no 200 response)" -ForegroundColor Red; Hammer-Record FAIL } else {
            $s = $resp.data.delta.summary
            # Only 'good' url is valid in both -> moved_count=1 (rank unchanged=0 shift), entered=0, exited=0
            if ($s.moved_count -eq 1 -and $s.entered_count -eq 0 -and $s.exited_count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (moved=" + $s.moved_count + " entered=" + $s.entered_count + " exited=" + $s.exited_count + ", expected 1/0/0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ─────────────────────────────────────────────────────────────────────────────
# PH-F: serp-deltas determinism (same setup, two calls, stable fields match)
# Uses the main SIL-2 KeywordTarget if it was created; otherwise skip.
# ─────────────────────────────────────────────────────────────────────────────
try {
    Write-Host "Testing: serp-deltas two calls identical stable fields" -NoNewline
    if (-not $sdKtId) { Write-Host "  SKIP (main SIL-2 KT not created)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r1 = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId}) `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-deltas" @{keywordTargetId=$sdKtId}) `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $s1 = ($r1.Content | ConvertFrom-Json).data.delta.summary
            $s2 = ($r2.Content | ConvertFrom-Json).data.delta.summary
            $match = (
                $s1.moved_count    -eq $s2.moved_count    -and
                $s1.entered_count  -eq $s2.entered_count  -and
                $s1.exited_count   -eq $s2.exited_count   -and
                $s1.improved_count -eq $s2.improved_count -and
                $s1.declined_count -eq $s2.declined_count
            )
            if ($match) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (summary mismatch between two calls)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
