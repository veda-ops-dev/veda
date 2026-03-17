# hammer-intent-drift.ps1 -- Intent Drift Sensor
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/intent-drift
#
# Setup: creates one KT + 3 snapshots with controlled intent transitions:
#   snap0: featured_snippet only  -> informational dominant
#   snap1: video only             -> video dominant       (dominantChanged=true)
#   snap2: shopping only          -> transactional dominant (dominantChanged=true)
#
# Expected: 2 transitions (snap0->snap1, snap1->snap2)
# Default significanceThreshold=34 ensures shifts of 100% trigger as significant.

Hammer-Section "INTENT DRIFT TESTS"

$_idBase   = "/api/seo/keyword-targets"
$_idRunId  = (Get-Date).Ticks
$_idQuery  = "id-test-$_idRunId"
$_idKtId   = $null
$_idSetupOk = $false

# =============================================================================
# Setup
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_idQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_idKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_idQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_idKtId) {
    $t0 = (Get-Date).AddMinutes(-8).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt = $t0
            rawPayload = @{
                items = @(
                    @{type="featured_snippet"; url="https://ex.com/fs"; rank_absolute=1}
                    @{type="organic";          url="https://ex.com/o1"; rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t1
            rawPayload = @{
                items = @(
                    @{type="video";   url="https://youtube.com/v1"; rank_absolute=1}
                    @{type="organic"; url="https://ex.com/o1";      rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t2
            rawPayload = @{
                items = @(
                    @{type="shopping"; url="https://shop.com/a"; rank_absolute=1}
                    @{type="organic";  url="https://ex.com/o1"; rank_absolute=2}
                )
            }
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_idQuery; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"; aiOverviewStatus="absent"
            rawPayload=$def.rawPayload
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_idSetupOk = $allCreated
}

# =============================================================================
# ID-A: 400 invalid UUID
# =============================================================================
try {
    Write-Host "Testing: ID-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$bid/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-B: 400 invalid params
# =============================================================================
try {
    Write-Host "Testing: ID-B 400 on invalid params" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_idKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $cases = @(
            "windowDays=0","windowDays=366","windowDays=abc",
            "significanceThreshold=0","significanceThreshold=101","significanceThreshold=abc",
            "limitTransitions=0","limitTransitions=201","limitTransitions=abc"
        )
        $failures = @()
        foreach ($qs in $cases) {
            $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift?$qs" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -ne 400) { $failures += "$qs -> $($r.StatusCode)" }
        }
        if ($failures.Count -eq 0) { Write-Host ("  PASS (" + $cases.Count + " cases)") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-C: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: ID-C 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_idKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-D: 200 + required top-level fields
# =============================================================================
try {
    Write-Host "Testing: ID-D 200 + required top-level fields" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays",
                          "significanceThreshold","snapshotCount","transitionCount","snapshots","transitions")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL missing: " + ($missing -join ", ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-E: expected 2 transitions detected
# =============================================================================
try {
    Write-Host "Testing: ID-E 2 transitions detected from 3 snapshots" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $tc = [int]$d.transitionCount
            if ($tc -eq 2) { Write-Host "  PASS (transitionCount=2)" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (transitionCount=$tc, expected 2)") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-F: dominantChanged=true on both transitions
# =============================================================================
try {
    Write-Host "Testing: ID-F dominantChanged=true on both transitions" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $txs = @(($r.Content | ConvertFrom-Json).data.transitions)
            if ($txs.Count -lt 2) { Write-Host "  SKIP (fewer than 2 transitions)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
            else {
                $ok = ($txs[0].dominantChanged -eq $true) -and ($txs[1].dominantChanged -eq $true)
                if ($ok) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (dc0=$($txs[0].dominantChanged) dc1=$($txs[1].dominantChanged))") -ForegroundColor Red; Hammer-Record FAIL }
            }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-G: snap0 dominant = informational
# =============================================================================
try {
    Write-Host "Testing: ID-G snap0 dominant = informational" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $snaps = @(($r.Content | ConvertFrom-Json).data.snapshots)
            if ($snaps.Count -lt 1) { Write-Host "  SKIP (no snaps)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
            else {
                $dom = $snaps[0].distribution.dominant
                if ($dom -eq "informational") { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (dominant=$dom)") -ForegroundColor Red; Hammer-Record FAIL }
            }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-H: transitions sorted capturedAt ASC
# =============================================================================
try {
    Write-Host "Testing: ID-H transitions sorted capturedAt ASC" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $txs = @(($r.Content | ConvertFrom-Json).data.transitions)
            $fail = $false; $msg = ""
            for ($i = 0; $i -lt ($txs.Count - 1); $i++) {
                if ([string]$txs[$i].capturedAt -gt [string]$txs[$i+1].capturedAt) {
                    $fail = $true; $msg = "txs[$i] > txs[$($i+1)]"; break
                }
            }
            if (-not $fail) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL ($msg)") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-I: determinism
# =============================================================================
try {
    Write-Host "Testing: ID-I determinism" -NoNewline
    if (-not $_idSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_idBase/$_idKtId/intent-drift"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (responses differ)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# ID-J: POST rejected
# =============================================================================
try {
    Write-Host "Testing: ID-J POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_idKtId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_idBase/$_idKtId/intent-drift" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
