# hammer-w5-persistence.ps1 — Deterministic SERP snapshot persistence tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: POST /api/test/persist-serp-snapshot
#
# These tests exercise the extracted persistSerpSnapshot() function
# WITHOUT any external provider dependency. Every test is deterministic.
#
# The test route returns 404 in production (NODE_ENV=production guard).
# If the route returns 404, all tests SKIP gracefully.

Hammer-Section "W5 PERSISTENCE TESTS (DETERMINISTIC — NO PROVIDER)"

$w5pBase = "/api/test/persist-serp-snapshot"

# ── Gate: verify the test route is available ─────────────────────────────────
$w5pAvailable = $false
try {
    $gateBody = @{ query="gate-probe"; locale="en-US"; device="desktop" } | ConvertTo-Json -Compress
    $gateResp = Invoke-WebRequest -Uri "$Base$w5pBase" -Method POST -Headers $Headers `
        -Body $gateBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($gateResp.StatusCode -ne 404) { $w5pAvailable = $true }
} catch {}

if (-not $w5pAvailable) {
    Write-Host "Test route $w5pBase not available (404 or unreachable). Likely production mode." -ForegroundColor DarkYellow
    Write-Host "Skipping all W5 persistence tests." -ForegroundColor DarkYellow
    Hammer-Record SKIP
} else {

$w5pRunId = (Get-Date).Ticks

# Helper: POST to test persist route
function Invoke-TestPersist {
    param([object]$Body, [hashtable]$RequestHeaders = $Headers)
    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    return Invoke-WebRequest -Uri "$Base$w5pBase" `
        -Method POST -Headers $RequestHeaders -Body $json `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
}

# ── W5P-A: basic persist returns 201 with correct fields ─────────────────────
try {
    Write-Host "Testing: W5P-A persist returns 201 with snapshot fields" -NoNewline
    $body = @{
        query  = "  W5P Hammer Query $w5pRunId  "
        locale = "en-US"
        device = "desktop"
        rawPayload = @{ results = @(); features = @() }
        aiOverviewStatus = "absent"
        organicResultCount = 3
        aiOverviewPresent = $false
        features = @("people_also_ask")
    }
    $resp = Invoke-TestPersist -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $hasFields = ($null -ne $d.id -and $null -ne $d.query -and $null -ne $d.locale `
            -and $null -ne $d.device -and $null -ne $d.capturedAt -and $null -ne $d.createdAt `
            -and $d.source -eq "dataforseo" -and $d._created -eq $true)
        if ($hasFields) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (missing or incorrect fields)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-B: query normalization applied ────────────────────────────────────────
try {
    Write-Host "Testing: W5P-B query normalized (lowercase, trimmed)" -NoNewline
    $body = @{
        query  = "  W5P NORMALIZE $w5pRunId  "
        locale = "en-US"
        device = "desktop"
    }
    $resp = Invoke-TestPersist -Body $body
    if ($resp.StatusCode -eq 201) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $expected = "w5p normalize $w5pRunId"
        if ($d.query -eq $expected) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (got '" + $d.query + "', expected '" + $expected + "')") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-C: P2002 idempotent replay with same capturedAt ──────────────────────
try {
    Write-Host "Testing: W5P-C idempotent replay (same capturedAt) returns 200" -NoNewline
    $fixedTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $body = @{
        query      = "w5p idempotent $w5pRunId"
        locale     = "en-US"
        device     = "desktop"
        capturedAt = $fixedTime
    }
    $r1 = Invoke-TestPersist -Body $body
    if ($r1.StatusCode -ne 201) {
        Write-Host ("  FAIL (first call got " + $r1.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $r2 = Invoke-TestPersist -Body $body
        if ($r2.StatusCode -eq 200) {
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $d1 = ($r1.Content | ConvertFrom-Json).data
            if ($d2.id -eq $d1.id -and $d2._created -eq $false) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (replay returned different id or _created=true)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (replay got " + $r2.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-D: EventLog written on create ─────────────────────────────────────────
try {
    Write-Host "Testing: W5P-D EventLog entry created for new snapshot" -NoNewline
    $evtQuery = "w5p eventlog $w5pRunId"
    $body = @{ query = $evtQuery; locale = "en-US"; device = "desktop" }
    $resp = Invoke-TestPersist -Body $body
    if ($resp.StatusCode -ne 201) {
        Write-Host ("  FAIL (persist got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $d = ($resp.Content | ConvertFrom-Json).data
        # Verify via audit/event-log endpoint if available
        $evtResp = try {
            Invoke-WebRequest -Uri "$Base/api/audit?entityId=$($d.id)&limit=5" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        } catch { $null }
        if ($evtResp -and $evtResp.StatusCode -eq 200) {
            $evtData = ($evtResp.Content | ConvertFrom-Json).data
            $found = $evtData | Where-Object { $_.eventType -eq "SERP_SNAPSHOT_RECORDED" -and $_.entityId -eq $d.id }
            if ($found) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (EventLog entry not found for entityId)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            # Audit endpoint may not be available — test the write, skip the read-back
            Write-Host "  SKIP (audit endpoint not available for EventLog verification)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-E: cross-project isolation ────────────────────────────────────────────
try {
    Write-Host "Testing: W5P-E cross-project writes are isolated" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $isoQuery = "w5p isolation $w5pRunId"
        $fixedTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $body = @{ query = $isoQuery; locale = "en-US"; device = "desktop"; capturedAt = $fixedTime }

        # Write to project A
        $rA = Invoke-TestPersist -Body $body -RequestHeaders $Headers
        # Write to project B (same query, same capturedAt)
        $rB = Invoke-TestPersist -Body $body -RequestHeaders $OtherHeaders

        if ($rA.StatusCode -eq 201 -and $rB.StatusCode -eq 201) {
            $dA = ($rA.Content | ConvertFrom-Json).data
            $dB = ($rB.Content | ConvertFrom-Json).data
            if ($dA.id -ne $dB.id) {
                Write-Host "  PASS (different IDs across projects)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (same ID returned for different projects — isolation breach)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (A=" + $rA.StatusCode + " B=" + $rB.StatusCode + ", expected both 201)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-F: validation — missing required fields ──────────────────────────────
try {
    Write-Host "Testing: W5P-F validation rejects missing/invalid fields" -NoNewline
    $cases = @(
        @{ locale = "en-US"; device = "desktop" },                                        # missing query
        @{ query = "test"; device = "desktop" },                                           # missing locale
        @{ query = "test"; locale = "en-US"; device = "tablet" },                          # invalid device
        @{ query = "test"; locale = "en-US"; device = "desktop"; unknownField = "x" }      # strict: extra field
    )
    $failures = @()
    foreach ($bodyCase in $cases) {
        $json = $bodyCase | ConvertTo-Json -Depth 5 -Compress
        $resp = Invoke-WebRequest -Uri "$Base$w5pBase" -Method POST -Headers $Headers `
            -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) {
            $failures += "body=" + $json + " -> " + $resp.StatusCode
        }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $cases.Count + " invalid cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (" + $failures.Count + " cases: " + ($failures -join "; ") + ")") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-G: malformed JSON ────────────────────────────────────────────────────
try {
    Write-Host "Testing: W5P-G malformed JSON returns 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$w5pBase" -Method POST -Headers $Headers `
        -Body "{not valid" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── W5P-H: snapshot visible in serp-snapshots list ───────────────────────────
try {
    Write-Host "Testing: W5P-H persisted snapshot visible in GET serp-snapshots" -NoNewline
    $listQuery = "w5p list visible $w5pRunId"
    $body = @{ query = $listQuery; locale = "en-US"; device = "desktop" }
    $resp = Invoke-TestPersist -Body $body
    if ($resp.StatusCode -ne 201) {
        Write-Host ("  FAIL (persist got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $normalizedListQuery = $listQuery.ToLower().Trim()
        $listResp = Invoke-WebRequest -Uri (Build-Url "/api/seo/serp-snapshots" @{query=$normalizedListQuery;limit="5"}) `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($listResp.StatusCode -eq 200) {
            $listData = ($listResp.Content | ConvertFrom-Json).data
            $found = $listData | Where-Object { $_.query -eq $normalizedListQuery }
            if ($found) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (snapshot not found in list endpoint)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (list endpoint got " + $listResp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# End of availability gate
}
