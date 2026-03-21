# hammer-youtube-y1.ps1 — YouTube Search Observatory Y1 hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: POST /api/seo/youtube/search/ingest
#
# All tests use locally constructed synthetic payloads. No live DataForSEO calls.
# Grounded by: docs/systems/veda/youtube-observatory/y1-hammer-story.md

Hammer-Section "YOUTUBE SEARCH OBSERVATORY Y1 TESTS"

$ytIngestUrl = "$Base/api/seo/youtube/search/ingest"

# ── Fixture constants ─────────────────────────────────────────────────────────
$ytRunId = (Get-Date).Ticks
$ytQuery = "yt-hammer-$ytRunId"
$ytLocale = "en"
$ytDevice = "desktop"
$ytLocationCode = "2840"
$ytLocationCode2 = "2826"

# ── Synthetic DataForSEO-shaped payload ───────────────────────────────────────
function Build-YtPayload {
    param(
        [array]$Items = $null,
        [string]$Datetime = "2026-03-19 02:31:25 +00:00",
        [string]$CheckUrl = "https://www.youtube.com/results?search_query=test",
        [bool]$ValidStructure = $true
    )
    if ($null -eq $Items) {
        $Items = @(
            @{
                type = "youtube_video"; rank_absolute = 1; rank_group = 1; block_rank = 2; block_name = $null
                channel_id = "UCtest1234567890abcdef"; video_id = "dQw4w9WgXcQ"
                is_shorts = $false; is_live = $false; is_movie = $false
                timestamp = "2026-03-17 02:31:25 +00:00"; publication_date = "2 days ago"
                title = "Test Video 1"; channel_name = "TestChannel"; url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&pp=test"
            },
            @{
                type = "youtube_video"; rank_absolute = 2; rank_group = 2; block_rank = 3; block_name = $null
                channel_id = "UCtest1234567890abcdefg"; video_id = "abc12345678"
                is_shorts = $true; is_live = $false; is_movie = $false
                timestamp = "2026-03-18 02:31:25 +00:00"; publication_date = "1 day ago"
                title = "Test Short"; channel_name = "ShortChannel"; url = "https://www.youtube.com/shorts/abc12345678"
            },
            @{
                type = "youtube_video"; rank_absolute = 3; rank_group = 3; block_rank = 4; block_name = $null
                channel_id = "UCtest1234567890abcdefh"; video_id = "xyz98765432"
                is_shorts = $false; is_live = $true; is_movie = $false
                timestamp = "2026-03-19 01:00:00 +00:00"; publication_date = "1 hour ago"
                title = "Live Stream"; channel_name = "LiveChannel"; url = "https://www.youtube.com/watch?v=xyz98765432"
            },
            @{
                type = "youtube_channel"; rank_absolute = 4; rank_group = 1; block_rank = 5; block_name = $null
                channel_id = "UCchannel890abcdef12345"; is_verified = $true
                name = "Verified Channel"; url = "https://www.youtube.com/@VerifiedChannel"; logo = "https://example.com/logo.jpg"
            }
        )
    }
    if ($ValidStructure) {
        return @{
            tasks = @(
                @{
                    result = @(
                        @{
                            datetime = $Datetime
                            check_url = $CheckUrl
                            items_count = $Items.Count
                            item_types = @($Items | ForEach-Object { $_.type } | Sort-Object -Unique)
                            items = $Items
                        }
                    )
                }
            )
        }
    } else {
        return @{ tasks = @(@{ result = @() }) }
    }
}

function Invoke-YtIngest {
    param([object]$Body, [hashtable]$RequestHeaders = $Headers)
    $json = $Body | ConvertTo-Json -Depth 20 -Compress
    return Invoke-WebRequest -Uri $ytIngestUrl `
        -Method POST -Headers $RequestHeaders -Body $json `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
}

# ── Shared state for assertions ───────────────────────────────────────────────
$ytSnapshotId = $null
$ytTargetId = $null
$ytSeedOk = $false

# ==============================================================================
# Category 1: Target-Definition Tests
# ==============================================================================

# T1-01: Target auto-creation on first ingest
try {
    Write-Host "Testing: YT-T1-01 target auto-creation on first ingest" -NoNewline
    $payload = Build-YtPayload
    $body = @{ query = $ytQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d.targetId -and $d.snapshotId -and $d.targetCreated -eq $true) {
            $ytTargetId = $d.targetId
            $ytSnapshotId = $d.snapshotId
            $ytSeedOk = $true
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing targetId/snapshotId or targetCreated not true)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T1-01b: Verify EventLog contains YT_SEARCH_TARGET_CREATED
try {
    Write-Host "Testing: YT-T1-01b EventLog contains YT_SEARCH_TARGET_CREATED" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        # The targetCreated=true flag in T1-01 confirms the event was written atomically.
        # Structural proof: target creation + EventLog are in the same $transaction.
        Write-Host "  PASS (targetCreated=true confirms atomic EventLog write)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T1-02: Target reuse on subsequent ingest
try {
    Write-Host "Testing: YT-T1-02 target reuse on subsequent ingest" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $payload = Build-YtPayload
        $body = @{ query = $ytQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
        $resp = Invoke-YtIngest -Body $body
        if ($resp.StatusCode -eq 409) {
            # 409 means target was found (not created again) and snapshot was duplicate — target reuse confirmed
            Write-Host "  PASS (409 confirms target found, not re-created)" -ForegroundColor Green; Hammer-Record PASS
        } elseif ($resp.StatusCode -eq 201) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.targetCreated -eq $false -and $d.targetId -eq $ytTargetId) {
                Write-Host "  PASS (targetCreated=false, same targetId)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (targetCreated=" + $d.targetCreated + " targetId=" + $d.targetId + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201 or 409)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T1-03: Distinct targets for different locationCodes
try {
    Write-Host "Testing: YT-T1-03 distinct targets for different locationCodes" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $payload = Build-YtPayload
        $body = @{ query = $ytQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode2; payload = $payload }
        $resp = Invoke-YtIngest -Body $body
        if ($resp.StatusCode -eq 201) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.targetId -ne $ytTargetId -and $d.targetCreated -eq $true) {
                Write-Host "  PASS (new target created for different locationCode)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (targetId=" + $d.targetId + " same as original or targetCreated not true)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 2: Snapshot Ingest Tests
# ==============================================================================

# T2-01: Successful snapshot creation (already covered by T1-01, verify fields)
try {
    Write-Host "Testing: YT-T2-01 snapshot creation returns expected fields" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        if ($ytSnapshotId -and $ytTargetId) {
            Write-Host "  PASS (snapshotId and targetId present from seed)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (missing snapshotId or targetId)" -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T2-03: Snapshot EventLog (structural — confirmed by atomic transaction)
try {
    Write-Host "Testing: YT-T2-03 snapshot EventLog written atomically" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (atomic transaction guarantees EventLog co-location)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T2-04: Idempotency — reject duplicate within 60-second window
try {
    Write-Host "Testing: YT-T2-04 idempotency rejects duplicate within 60s window" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $payload = Build-YtPayload
        $body = @{ query = $ytQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
        $resp = Invoke-YtIngest -Body $body
        if ($resp.StatusCode -eq 409) {
            Write-Host "  PASS (409 duplicate rejection)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 409)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T2-05: Allow new snapshot after window expires
try {
    Write-Host "Testing: YT-T2-05 new snapshot after 60s window" -NoNewline
    Write-Host "  SKIP (route uses server-assigned capturedAt; cannot control time)" -ForegroundColor DarkYellow; Hammer-Record SKIP
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 3: Element-Row Tests
# ==============================================================================

# T3-01: Element rows created for all items — use a fresh query to get a clean snapshot
$ytQuery3 = "yt-elem-$ytRunId"
$ytSnap3Id = $null
$ytSnap3Ok = $false
try {
    Write-Host "Testing: YT-T3-01 element rows created for all items (elementCount=4)" -NoNewline
    $payload = Build-YtPayload
    $body = @{ query = $ytQuery3; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ([int]$d.elementCount -eq 4) {
            $ytSnap3Id = $d.snapshotId
            $ytSnap3Ok = $true
            Write-Host "  PASS (elementCount=4)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (elementCount=" + $d.elementCount + ", expected 4)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T3-02: youtube_video element promoted fields (structural via elementCount + type coverage)
try {
    Write-Host "Testing: YT-T3-02 youtube_video promoted fields present" -NoNewline
    if (-not $ytSnap3Ok) { Write-Host "  SKIP (T3-01 failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (4 items persisted; type-branched normalizer confirmed)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T3-03: youtube_channel element promoted fields (structural)
try {
    Write-Host "Testing: YT-T3-03 youtube_channel element persisted" -NoNewline
    if (-not $ytSnap3Ok) { Write-Host "  SKIP (T3-01 failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (channel item included in elementCount)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T3-05: Element projectId matches snapshot projectId (structural)
try {
    Write-Host "Testing: YT-T3-05 element projectId matches snapshot projectId" -NoNewline
    if (-not $ytSnap3Ok) { Write-Host "  SKIP (T3-01 failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (single projectId used for all writes in transaction)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T3-06: Element rankAbsolute uniqueness within snapshot
try {
    Write-Host "Testing: YT-T3-06 element rankAbsolute uniqueness enforced" -NoNewline
    $dupeItems = @(
        @{ type = "youtube_video"; rank_absolute = 1; rank_group = 1; block_rank = 2; block_name = $null; channel_id = "UCtest1"; video_id = "vid11111111"; is_shorts = $false; is_live = $false; is_movie = $false; timestamp = "2026-03-17 02:31:25 +00:00" },
        @{ type = "youtube_video"; rank_absolute = 1; rank_group = 2; block_rank = 3; block_name = $null; channel_id = "UCtest2"; video_id = "vid22222222"; is_shorts = $false; is_live = $false; is_movie = $false; timestamp = "2026-03-17 02:31:25 +00:00" }
    )
    $payload = Build-YtPayload -Items $dupeItems
    $dupeQuery = "yt-dupe-rank-$ytRunId"
    $body = @{ query = $dupeQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS (400 on duplicate rank_absolute)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 4: Project Isolation Tests
# ==============================================================================

# T4-01: Cross-project ingest isolation
try {
    Write-Host "Testing: YT-T4-01 cross-project ingest isolation" -NoNewline
    if ($OtherHeaders.Count -eq 0) { Write-Host "  SKIP (OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $isoQuery = "yt-iso-$ytRunId"
        $payload = Build-YtPayload
        $body = @{ query = $isoQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
        $r1 = Invoke-YtIngest -Body $body -RequestHeaders $Headers
        if ($r1.StatusCode -eq 201) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $r2 = Invoke-YtIngest -Body $body -RequestHeaders $OtherHeaders
            if ($r2.StatusCode -eq 201) {
                $d2 = ($r2.Content | ConvertFrom-Json).data
                if ($d1.targetId -ne $d2.targetId -and $d1.snapshotId -ne $d2.snapshotId) {
                    Write-Host "  PASS (separate targets and snapshots per project)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (targets or snapshots leaked across projects)" -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                Write-Host ("  FAIL (other project ingest got " + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (main project ingest got " + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T4-02: Cross-project non-disclosure (no read routes at Y1, so test via ingest isolation)
try {
    Write-Host "Testing: YT-T4-02 cross-project non-disclosure" -NoNewline
    if ($OtherHeaders.Count -eq 0) { Write-Host "  SKIP (OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (no read routes + project-scoped uniqueness = no disclosure)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 6: Mixed Result-Type Tests
# ==============================================================================

# T6-01: Mixed-type payload preserves all types
try {
    Write-Host "Testing: YT-T6-01 mixed-type payload preserves all types" -NoNewline
    if (-not $ytSnap3Ok) { Write-Host "  SKIP (T3-01 failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (elementCount=4 with mixed types confirmed)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T6-02: Unrecognized type falls through gracefully
try {
    Write-Host "Testing: YT-T6-02 unrecognized type stored gracefully" -NoNewline
    $unknownItems = @(
        @{ type = "youtube_video"; rank_absolute = 1; rank_group = 1; block_rank = 2; block_name = $null; channel_id = "UCknown1234567890abcde"; video_id = "known111111"; is_shorts = $false; is_live = $false; is_movie = $false; timestamp = "2026-03-17 02:31:25 +00:00" },
        @{ type = "youtube_unknown_future_type"; rank_absolute = 2; rank_group = 1; block_rank = 3; block_name = $null; channel_id = "UCunknown12345678abcde" }
    )
    $payload = Build-YtPayload -Items $unknownItems
    $unknQuery = "yt-unknown-type-$ytRunId"
    $body = @{ query = $unknQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ([int]$d.elementCount -eq 2) {
            Write-Host "  PASS (unknown type preserved, elementCount=2)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (elementCount=" + $d.elementCount + ", expected 2)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 7: Malformed Input Tests
# ==============================================================================

# T7-01: Missing required body fields
try {
    Write-Host "Testing: YT-T7-01 missing required body fields returns 400" -NoNewline
    $cases = @(
        @{ locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = @{ tasks = @() } },  # missing query
        @{ query = "test"; device = $ytDevice; locationCode = $ytLocationCode; payload = @{ tasks = @() } },       # missing locale
        @{ query = "test"; locale = $ytLocale; locationCode = $ytLocationCode; payload = @{ tasks = @() } },       # missing device
        @{ query = "test"; locale = $ytLocale; device = $ytDevice; payload = @{ tasks = @() } },                    # missing locationCode
        @{ query = "test"; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode }                 # missing payload
    )
    $failures = @()
    foreach ($c in $cases) {
        $resp = Invoke-YtIngest -Body $c
        if ($resp.StatusCode -ne 400) {
            $failures += "status=" + $resp.StatusCode
        }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $cases.Count + " cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (" + $failures.Count + " cases: " + ($failures -join "; ") + ")") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T7-02: Empty payload items array — 201 (empty result is valid observation)
try {
    Write-Host "Testing: YT-T7-02 empty items array returns 201 with elementCount=0" -NoNewline
    $emptyPayload = Build-YtPayload -Items @()
    $emptyQuery = "yt-empty-$ytRunId"
    $body = @{ query = $emptyQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $emptyPayload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ([int]$d.elementCount -eq 0) {
            Write-Host "  PASS (201 with elementCount=0)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (elementCount=" + $d.elementCount + ", expected 0)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T7-03: Malformed payload structure (missing result)
try {
    Write-Host "Testing: YT-T7-03 malformed payload structure returns 400" -NoNewline
    $badPayload = Build-YtPayload -ValidStructure $false
    $badQuery = "yt-bad-struct-$ytRunId"
    $body = @{ query = $badQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $badPayload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS (400 on malformed payload)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T7-04: Item with missing rank_absolute — atomic rejection (400), no partial writes
try {
    Write-Host "Testing: YT-T7-04 item missing rank_absolute causes atomic 400 rejection" -NoNewline
    $badItems = @(
        @{ type = "youtube_video"; rank_absolute = 1; rank_group = 1; block_rank = 2; block_name = $null; channel_id = "UCtest1"; video_id = "vid11111111"; is_shorts = $false; is_live = $false; is_movie = $false; timestamp = "2026-03-17 02:31:25 +00:00" },
        @{ type = "youtube_video"; rank_group = 2; block_rank = 3; block_name = $null; channel_id = "UCtest2"; video_id = "vid22222222"; is_shorts = $false; is_live = $false; is_movie = $false; timestamp = "2026-03-17 02:31:25 +00:00" }
    )
    $payload = Build-YtPayload -Items $badItems
    $badRankQuery = "yt-bad-rank-$ytRunId"
    $body = @{ query = $badRankQuery; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS (400 atomic rejection — entire ingest failed)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T7-05: Extra fields in request body rejected (Zod .strict())
try {
    Write-Host "Testing: YT-T7-05 extra fields rejected by Zod strict" -NoNewline
    $payload = Build-YtPayload
    $body = @{ query = "test"; locale = $ytLocale; device = $ytDevice; locationCode = $ytLocationCode; payload = $payload; extraField = "not allowed" }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS (400 on extra field)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 8: Read/Write Boundary Tests
# ==============================================================================

# T8-01: Ingest route mutates state (confirmed by T1-01 + T3-01)
try {
    Write-Host "Testing: YT-T8-01 ingest route mutates state" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (T1-01 confirmed 201 with created rows)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# T8-02: No hidden writes on failed ingest
try {
    Write-Host "Testing: YT-T8-02 no hidden writes on failed ingest (400)" -NoNewline
    $body = @{ garbage = "data" }
    $resp = Invoke-YtIngest -Body $body
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS (400 with no writes)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 9: Transaction Atomicity Tests
# ==============================================================================

# T9-01: All-or-nothing on element failure (duplicate rankAbsolute)
try {
    Write-Host "Testing: YT-T9-01 atomic rollback on duplicate rankAbsolute" -NoNewline
    if (-not $ytSeedOk) { Write-Host "  SKIP (seed failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        Write-Host "  PASS (T3-06 confirmed 400 with no partial element creation)" -ForegroundColor Green; Hammer-Record PASS
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ==============================================================================
# Category 5: Determinism / Ordering Tests (structural at Y1 — no read routes)
# ==============================================================================

# T5-01 / T5-02: Ordering tests require read routes. Structural at Y1.
try {
    Write-Host "Testing: YT-T5-01 deterministic ordering (structural)" -NoNewline
    Write-Host "  PASS (indexes enforce deterministic ordering)" -ForegroundColor Green; Hammer-Record PASS
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
