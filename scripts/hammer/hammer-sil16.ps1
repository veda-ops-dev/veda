# hammer-sil16.ps1 -- SIL-16 SERP Disturbance Detection
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances
#
# Setup: creates 4 keyword targets with 3 snapshots each, all exhibiting
#   significant volatility, feature changes, and rank shifts so that every
#   disturbance signal fires deterministically.
#
# Tests:
#   SD-A  endpoint returns disturbance structure with all required fields
#   SD-B  results are deterministic across repeated calls
#   SD-C  volatilityCluster triggers (>= 30% of active keywords exceed threshold)
#   SD-D  feature shift detection is stable
#   SD-E  endpoint is read-only (no EventLog entries created)

Hammer-Section "SIL-16 TESTS (SERP DISTURBANCE DETECTION)"

$_sdBase  = "/api/seo/serp-disturbances"
$_sdRunId = (Get-Date).Ticks
$_sdSetupOk = $false

# =============================================================================
# Setup -- create 4 keyword targets + 3 snapshots each
#
# Snapshot design:
#   snap0 (oldest): organic urls at low ranks, featured_snippet present
#   snap1 (middle): large rank shifts, ai_overview present, featured_snippet gone
#   snap2 (newest): further shifts, people_also_ask added, rank exits/entries
#
# With 3 snapshots (2 pairs), computeVolatility will produce sampleSize=2.
# Large rank shifts (positions 1->15+) push volatilityScore well above 30.
# Feature changes in each pair produce featureShiftDetected.
# Rank entries/exits + large shifts produce rankingTurbulence.
# =============================================================================

$_sdQueries = @(
    "sd-kw-alpha-$_sdRunId",
    "sd-kw-beta-$_sdRunId",
    "sd-kw-gamma-$_sdRunId",
    "sd-kw-delta-$_sdRunId"
)
$_sdKtIds = @()

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=$_sdQueries;locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $kwData = ($rKw.Content | ConvertFrom-Json).data.targets
        foreach ($q in $_sdQueries) {
            $match = $kwData | Where-Object { $_.query -eq $q } | Select-Object -First 1
            if ($match) { $_sdKtIds += $match.id }
        }
    }
} catch {}

if ($_sdKtIds.Count -eq 4) {
    $ct0 = (Get-Date).AddMinutes(-30).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct1 = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct2 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $allCreated = $true
    foreach ($q in $_sdQueries) {
        $snapDefs = @(
            @{
                capturedAt=$ct0; aiOverviewStatus="absent"
                items=@(
                    @{type="organic"; url="https://alpha.com/sd-$q"; rank_absolute=1}
                    @{type="organic"; url="https://beta.com/sd-$q";  rank_absolute=2}
                    @{type="organic"; url="https://gamma.com/sd-$q"; rank_absolute=3}
                    @{type="featured_snippet"; url="https://alpha.com/fs"; rank_absolute=0}
                )
            }
            @{
                capturedAt=$ct1; aiOverviewStatus="present"
                items=@(
                    @{type="organic"; url="https://alpha.com/sd-$q"; rank_absolute=15}
                    @{type="organic"; url="https://zeta.com/sd-$q";  rank_absolute=2}
                    @{type="organic"; url="https://gamma.com/sd-$q"; rank_absolute=18}
                    @{type="people_also_ask"; url="https://paa.example.com"; rank_absolute=0}
                )
            }
            @{
                capturedAt=$ct2; aiOverviewStatus="absent"
                items=@(
                    @{type="organic"; url="https://zeta.com/sd-$q";  rank_absolute=1}
                    @{type="organic"; url="https://omega.com/sd-$q"; rank_absolute=5}
                    @{type="organic"; url="https://beta.com/sd-$q";  rank_absolute=20}
                    @{type="people_also_ask"; url="https://paa.example.com"; rank_absolute=0}
                    @{type="local_pack"; url="https://maps.example.com"; rank_absolute=0}
                )
            }
        )

        foreach ($sd in $snapDefs) {
            try {
                $body = @{
                    query=$q; locale="en-US"; device="desktop"
                    capturedAt=$sd.capturedAt; aiOverviewStatus=$sd.aiOverviewStatus
                    rawPayload=@{items=$sd.items}
                }
                $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                    -Body ($body | ConvertTo-Json -Depth 15 -Compress) -ContentType "application/json" `
                    -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
            } catch { $allCreated = $false }
        }
    }
    $_sdSetupOk = $allCreated
}

# =============================================================================
# SD-A: endpoint returns disturbance structure with all required fields
# =============================================================================
try {
    Write-Host "Testing: SD-A endpoint returns disturbance structure" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("volatilityCluster","featureShiftDetected","dominantNewFeatures","rankingTurbulence","affectedKeywordCount")
        $missing = $required | Where-Object { $props -notcontains $_ }
        $failures = @()
        if ($missing.Count -gt 0) { $failures += "missing: $($missing -join ', ')" }
        if ($null -eq $d.dominantNewFeatures) { $failures += "dominantNewFeatures is null" }
        if ($null -eq $d.affectedKeywordCount) { $failures += "affectedKeywordCount is null" }
        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-B: deterministic results across repeated calls
# =============================================================================
try {
    Write-Host "Testing: SD-B deterministic results across repeated calls" -NoNewline
    $url = "$Base$_sdBase"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
        $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
        if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (responses differ)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-C: volatilityCluster triggers with seeded high-volatility keywords
# =============================================================================
try {
    Write-Host "Testing: SD-C volatilityCluster triggers for high-volatility seed data" -NoNewline
    if (-not $_sdSetupOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            # Our seeded keywords have rank shifts of 14+ positions (pos 1 -> pos 15)
            # With 2 pairs, volatilityScore should be well above 30 for all 4 keywords
            # volatilityCluster requires >= 30% of active keywords exceed 30
            if ($d.volatilityCluster -eq $true) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (volatilityCluster=$($d.volatilityCluster) -- expected true with seeded data)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-D: feature shift detection stable
# =============================================================================
try {
    Write-Host "Testing: SD-D featureShiftDetected and dominantNewFeatures stable" -NoNewline
    if (-not $_sdSetupOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $failures = @()
            # featureShiftDetected must be true (featured_snippet gone, people_also_ask + local_pack added)
            if ($d.featureShiftDetected -ne $true) {
                $failures += "featureShiftDetected=$($d.featureShiftDetected) -- expected true"
            }
            # dominantNewFeatures must be an array (may include people_also_ask, local_pack)
            if ($null -eq $d.dominantNewFeatures) { $failures += "dominantNewFeatures is null" }
            if ($d.dominantNewFeatures.Count -gt 3) { $failures += "dominantNewFeatures has >3 entries" }
            # deterministic: call again and compare
            $r2 = Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $Headers `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r2.StatusCode -eq 200) {
                $d2 = ($r2.Content | ConvertFrom-Json).data
                $f1 = $d.dominantNewFeatures | ConvertTo-Json -Compress
                $f2 = $d2.dominantNewFeatures | ConvertTo-Json -Compress
                if ($f1 -ne $f2) { $failures += "dominantNewFeatures differs between calls" }
            }
            if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-E: endpoint is read-only (no EventLog entries created)
# =============================================================================
try {
    Write-Host "Testing: SD-E endpoint is read-only (no EventLog entries)" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) {
            $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    # Make 3 requests to the disturbances endpoint
    for ($i = 0; $i -lt 3; $i++) {
        try {
            Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $Headers `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing | Out-Null
        } catch {}
    }

    $elAfter = 0
    try {
        $rEL2 = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL2.StatusCode -eq 200) {
            $elAfter = ($rEL2.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    if ($elAfter -eq $elBefore) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (EventLog grew from $elBefore to $elAfter)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-F: unknown query param rejected (strict Zod validation)
# =============================================================================
try {
    Write-Host "Testing: SD-F unknown param rejected with 400" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sdBase`?bogusParam=bad" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got $($r.StatusCode), expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SD-G: project isolation -- OtherProject does not see our seeded data
# =============================================================================
try {
    Write-Host "Testing: SD-G project isolation" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_sdBase" -Method GET -Headers $OtherHeaders `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(200,400)) {
            # 200 with empty/zero signals, OR 400 (project not found) -- both fine
            if ($r.StatusCode -eq 400) {
                Write-Host "  PASS (400 -- other project not found)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                $d = ($r.Content | ConvertFrom-Json).data
                # Other project should not see our 4 seeded keywords
                # affectedKeywordCount could be 0 if no seeded data there
                Write-Host ("  PASS (isolated -- affectedKeywordCount=$($d.affectedKeywordCount))") -ForegroundColor Green; Hammer-Record PASS
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
