# hammer-source-capture.ps1 — Observatory floor: source capture, source items list, events list
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   POST /api/source-items/capture
#     SC-1  valid new capture -> 201 + required response fields
#     SC-2  EventLog entry created for captured item (atomicity signal)
#     SC-3  recapture (same URL, same project) -> 200
#     SC-4  missing sourceType -> 400
#     SC-5  missing url -> 400
#     SC-6  missing operatorIntent -> 400
#     SC-7  invalid sourceType enum -> 400
#     SC-8  invalid URL format -> 400
#     SC-9  extra unknown field (strict schema) -> 400
#     SC-10 no project context (mutation strictness) -> 400
#     SC-11 malformed JSON -> 400
#     SC-12 cross-project: same URL captured by project B creates independent record -> 201
#     SC-13 cross-project: project A item not visible to project B in list
#
#   GET /api/source-items
#     SI-1  basic list -> 200, valid envelope
#     SI-2  deterministic ordering (createdAt desc, id desc tiebreak)
#     SI-3  status filter returns only matching items
#     SI-4  invalid status value -> 400
#     SI-5  invalid sourceType value -> 400
#     SI-6  project isolation: project B cannot see project A items
#
#   GET /api/events
#     EV-1  basic list -> 200, valid envelope, project-scoped
#     EV-2  eventType=SOURCE_CAPTURED filter -> 200, all items match
#     EV-3  invalid eventType value -> 400
#     EV-4  invalid entityType value -> 400
#     EV-5  invalid actor value -> 400
#     EV-6  invalid entityId (not UUID) -> 400
#     EV-7  deterministic ordering (timestamp desc, id desc tiebreak)
#     EV-8  project isolation: project B events do not include project A SOURCE_CAPTURED
#     EV-9  GET /api/events does not mutate state (read-only invariant)

Hammer-Section "OBSERVATORY FLOOR — SOURCE CAPTURE"

$scRunId = (Get-Date).Ticks
$scUrl   = "https://example.com/hammer-capture-$scRunId"
$scCapturedItemId = $null

# SC-1: POST valid new capture -> 201 + required response fields
try {
    Write-Host "Testing: SC-1 POST /api/source-items/capture (valid new capture -> 201)" -NoNewline
    $scBody = @{
        sourceType     = "webpage"
        url            = $scUrl
        operatorIntent = "hammer test capture $scRunId"
        platform       = "website"
        notes          = "created by hammer"
    } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/source-items/capture" -Method POST `
        -Headers $Headers -Body $scBody -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if (
            $null -ne $d -and
            -not [string]::IsNullOrWhiteSpace($d.id) -and
            $d.sourceType -eq "webpage" -and
            $d.url -eq $scUrl -and
            $d.status -eq "ingested" -and
            -not [string]::IsNullOrWhiteSpace($d.capturedAt) -and
            -not [string]::IsNullOrWhiteSpace($d.createdAt)
        ) {
            $scCapturedItemId = $d.id
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host "  FAIL (response shape invalid)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SC-2: EventLog entry created for captured item (atomicity signal)
# Verifies that the SOURCE_CAPTURED event was co-written in the same transaction.
# This is an observable proxy for the atomicity invariant (SYSTEM-INVARIANTS §5.2).
try {
    Write-Host "Testing: SC-2 EventLog entry exists for captured item" -NoNewline
    if ($null -eq $scCapturedItemId) {
        Write-Host "  SKIP (SC-1 did not capture item id)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $evResp = Invoke-WebRequest -Uri (Build-Url "/api/events" @{entityType="sourceItem"; entityId=$scCapturedItemId; limit="5"}) `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($evResp.StatusCode -eq 200) {
            $evData = ($evResp.Content | ConvertFrom-Json).data
            $found = $evData | Where-Object { $_.eventType -eq "SOURCE_CAPTURED" -and $_.entityId -eq $scCapturedItemId }
            if ($null -ne $found) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (SOURCE_CAPTURED event not found for item)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (events GET returned " + $evResp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SC-3: Recapture (same URL, same project) -> 200
try {
    Write-Host "Testing: SC-3 POST /api/source-items/capture (recapture same URL -> 200)" -NoNewline
    $scBody = @{
        sourceType     = "webpage"
        url            = $scUrl
        operatorIntent = "hammer recapture $scRunId"
        notes          = "recapture note"
    } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/source-items/capture" -Method POST `
        -Headers $Headers -Body $scBody -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($null -ne $d -and $d.url -eq $scUrl) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (response shape invalid on recapture)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SC-4: Missing sourceType -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-4 POST capture missing sourceType -> 400" $Headers @{
    url = "https://example.com/sc4-$scRunId"; operatorIntent = "test"
}

# SC-5: Missing url -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-5 POST capture missing url -> 400" $Headers @{
    sourceType = "webpage"; operatorIntent = "test"
}

# SC-6: Missing operatorIntent -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-6 POST capture missing operatorIntent -> 400" $Headers @{
    sourceType = "webpage"; url = "https://example.com/sc6-$scRunId"
}

# SC-7: Invalid sourceType enum value -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-7 POST capture invalid sourceType -> 400" $Headers @{
    sourceType = "tweet"; url = "https://example.com/sc7-$scRunId"; operatorIntent = "test"
}

# SC-8: Invalid URL format -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-8 POST capture invalid URL format -> 400" $Headers @{
    sourceType = "webpage"; url = "not-a-url"; operatorIntent = "test"
}

# SC-9: Extra unknown field (strict schema) -> 400
Test-PostJson "$Base/api/source-items/capture" 400 "SC-9 POST capture unknown field (strict) -> 400" $Headers @{
    sourceType = "webpage"; url = "https://example.com/sc9-$scRunId"; operatorIntent = "test"; bogus = "field"
}

# SC-10: No project context (mutation strictness) -> 400
try {
    Write-Host "Testing: SC-10 POST capture without project context returns 400" -NoNewline
    $scBody = @{
        sourceType     = "webpage"
        url            = "https://example.com/sc10-$scRunId"
        operatorIntent = "no-project test"
    } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/source-items/capture" -Method POST `
        -Headers @{ "Content-Type" = "application/json" } `
        -Body $scBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400 — silent fallback may still be active)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SC-11: Malformed JSON -> 400
try {
    Write-Host "Testing: SC-11 POST capture malformed JSON -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/source-items/capture" -Method POST `
        -Headers $Headers -Body "{not valid json{" -ContentType "application/json" `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SC-12: Cross-project — same URL captured under project B creates independent record -> 201
# URL uniqueness is now project-scoped (migration 20260316000200).
# The same URL may exist independently in two different projects.
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: SC-12 POST capture same URL in project B creates independent record -> 201" -NoNewline
        $scBodyB = @{
            sourceType     = "webpage"
            url            = $scUrl
            operatorIntent = "project B capture of same URL"
        } | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/source-items/capture" -Method POST `
            -Headers $OtherHeaders -Body $scBodyB -ContentType "application/json" `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            $dB = ($resp.Content | ConvertFrom-Json).data
            # The id must differ from project A's record — they are independent rows
            if ($null -ne $dB -and $dB.id -ne $scCapturedItemId) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host "  FAIL (same id returned or missing data)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: SC-12 Cross-project capture  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# SC-13: Cross-project list isolation — project B cannot see project A source items
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: SC-13 GET source-items cross-project isolation (project B cannot see project A items)" -NoNewline
        if ($null -eq $scCapturedItemId) {
            Write-Host "  SKIP (SC-1 did not produce a captured item)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/source-items?limit=100" -Method GET `
                -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $p = $resp.Content | ConvertFrom-Json
                $leaked = $p.data | Where-Object { $_.id -eq $scCapturedItemId }
                if ($null -eq $leaked) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (project A item visible to project B)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: SC-13 Cross-project list isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

Hammer-Section "OBSERVATORY FLOOR — SOURCE ITEMS LIST"

# SI-1: GET /api/source-items basic list -> 200, valid envelope
Test-ResponseEnvelope "$Base/api/source-items?limit=5" $Headers "SI-1 GET source-items (list envelope)" $true

# SI-2: Deterministic ordering (createdAt desc, id desc tiebreak)
try {
    Write-Host "Testing: SI-2 GET source-items ordering deterministic" -NoNewline
    $o1 = Try-GetJson -Url "$Base/api/source-items?limit=20" -RequestHeaders $Headers
    $o2 = Try-GetJson -Url "$Base/api/source-items?limit=20" -RequestHeaders $Headers
    if ($o1 -and $o2 -and $o1.data -and $o2.data) {
        $ids1 = $o1.data | ForEach-Object { $_.id }
        $ids2 = $o2.data | ForEach-Object { $_.id }
        $orderOk = ($ids1.Count -eq $ids2.Count)
        if ($orderOk) { for ($i = 0; $i -lt $ids1.Count; $i++) { if ($ids1[$i] -ne $ids2[$i]) { $orderOk = $false; break } } }
        if ($orderOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (ordering differs between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  SKIP (no source items to order)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SI-3: status=ingested filter returns only items with status=ingested
try {
    Write-Host "Testing: SI-3 GET source-items status=ingested filter" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/source-items" @{status="ingested";limit="20"}) `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json
        $allOk = $true
        foreach ($item in $p.data) { if ($item.status -ne "ingested") { $allOk = $false; break } }
        if ($allOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (non-ingested item in status=ingested result)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# SI-4: Invalid status enum value -> 400
Test-Endpoint "GET" (Build-Url "/api/source-items" @{status="pending"})  400 "SI-4 GET source-items invalid status -> 400"     $Headers

# SI-5: Invalid sourceType enum value -> 400
Test-Endpoint "GET" (Build-Url "/api/source-items" @{sourceType="tweet"}) 400 "SI-5 GET source-items invalid sourceType -> 400" $Headers

# SI-6: Project isolation — project B list does not contain project A item
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: SI-6 GET source-items project isolation (list scoped to own project)" -NoNewline
        if ($null -eq $scCapturedItemId) {
            Write-Host "  SKIP (SC-1 did not produce a captured item)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/source-items?limit=100" `
                -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $p = $resp.Content | ConvertFrom-Json
                $leaked = $p.data | Where-Object { $_.id -eq $scCapturedItemId }
                if ($null -eq $leaked) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (project A item visible in project B list)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: SI-6 Project isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

Hammer-Section "OBSERVATORY FLOOR — EVENTS LIST"

# EV-1: GET /api/events basic list -> 200, valid envelope, project-scoped
Test-ResponseEnvelope "$Base/api/events?limit=5" $Headers "EV-1 GET events (list envelope)" $true

# EV-2: eventType=SOURCE_CAPTURED filter -> 200, all items have correct eventType
try {
    Write-Host "Testing: EV-2 GET events eventType=SOURCE_CAPTURED filter" -NoNewline
    $resp = Invoke-WebRequest -Uri (Build-Url "/api/events" @{eventType="SOURCE_CAPTURED";limit="20"}) `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $p = $resp.Content | ConvertFrom-Json
        # SC-1 and SC-3 created SOURCE_CAPTURED events earlier in this module.
        # An empty result here means the filter or the co-write is broken, not that data is absent.
        if ($p.data.Count -eq 0) {
            Write-Host "  FAIL (filter returned no SOURCE_CAPTURED events -- events must exist from SC-1/SC-3)" -ForegroundColor Red; Hammer-Record FAIL
        } else {
            $allOk = $true
            foreach ($item in $p.data) { if ($item.eventType -ne "SOURCE_CAPTURED") { $allOk = $false; break } }
            if ($allOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (non-SOURCE_CAPTURED event in filtered result)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# EV-3: Invalid eventType enum value -> 400
Test-Endpoint "GET" (Build-Url "/api/events" @{eventType="ENTITY_DELETED"}) 400 "EV-3 GET events invalid eventType -> 400"   $Headers

# EV-4: Invalid entityType enum value -> 400
Test-Endpoint "GET" (Build-Url "/api/events" @{entityType="entity"})        400 "EV-4 GET events invalid entityType -> 400"  $Headers

# EV-5: Invalid actor enum value -> 400
Test-Endpoint "GET" (Build-Url "/api/events" @{actor="bot"})                400 "EV-5 GET events invalid actor -> 400"       $Headers

# EV-6: Invalid entityId (not a UUID) -> 400
Test-Endpoint "GET" (Build-Url "/api/events" @{entityId="not-a-uuid"})      400 "EV-6 GET events invalid entityId -> 400"    $Headers

# EV-7: Deterministic ordering (timestamp desc, id desc tiebreak)
try {
    Write-Host "Testing: EV-7 GET events ordering deterministic" -NoNewline
    $o1 = Try-GetJson -Url "$Base/api/events?limit=20" -RequestHeaders $Headers
    $o2 = Try-GetJson -Url "$Base/api/events?limit=20" -RequestHeaders $Headers
    if ($o1 -and $o2 -and $o1.data -and $o2.data) {
        $ids1 = $o1.data | ForEach-Object { $_.id }
        $ids2 = $o2.data | ForEach-Object { $_.id }
        $orderOk = ($ids1.Count -eq $ids2.Count)
        if ($orderOk) { for ($i = 0; $i -lt $ids1.Count; $i++) { if ($ids1[$i] -ne $ids2[$i]) { $orderOk = $false; break } } }
        if ($orderOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (event ordering not deterministic)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  SKIP (no events to order)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# EV-8: Project isolation — project B events do not include project A SOURCE_CAPTURED for our item
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: EV-8 GET events project isolation (project B cannot see project A events)" -NoNewline
        if ($null -eq $scCapturedItemId) {
            Write-Host "  SKIP (SC-1 did not produce a captured item)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri (Build-Url "/api/events" @{entityType="sourceItem"; entityId=$scCapturedItemId; limit="10"}) `
                -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $p = $resp.Content | ConvertFrom-Json
                # Project A's sourceItem entityId should not appear in project B's event log
                $leaked = $p.data | Where-Object { $_.entityId -eq $scCapturedItemId }
                if ($null -eq $leaked) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (project A event visible to project B)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: EV-8 Events project isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# EV-9: GET /api/events does not mutate state (read-only invariant)
# Two identical GETs must produce the same total count.
try {
    Write-Host "Testing: EV-9 GET events is read-only (count unchanged across two calls)" -NoNewline
    $r1 = Try-GetJson -Url "$Base/api/events?limit=1" -RequestHeaders $Headers
    $r2 = Try-GetJson -Url "$Base/api/events?limit=1" -RequestHeaders $Headers
    if ($r1 -and $r2 -and $null -ne $r1.pagination -and $null -ne $r2.pagination) {
        if ($r1.pagination.total -eq $r2.pagination.total) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (event count changed between two GETs)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  SKIP (could not read event pagination)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

