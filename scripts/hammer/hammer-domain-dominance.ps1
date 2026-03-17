# hammer-domain-dominance.ps1 -- Domain Dominance Sensor
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/domain-dominance
#
# Setup: creates one KT + 3 snapshots with controlled domain distribution:
#   snap0: wikipedia.org x2, reddit.com x1, organic only
#   snap1: reddit.com x3, wikipedia.org x1, organic only
#   snap2: medium.com x1, organic only (single domain)
#
# Expected snap0 topDomains[0]: wikipedia.org (count=2), dominanceIndex=0.5
# Expected snap1 topDomains[0]: reddit.com    (count=3), dominanceIndex=0.75

Hammer-Section "DOMAIN DOMINANCE TESTS"

$_ddBase   = "/api/seo/keyword-targets"
$_ddRunId  = (Get-Date).Ticks
$_ddQuery  = "dd-test-$_ddRunId"
$_ddKtId   = $null
$_ddSetupOk = $false

# =============================================================================
# Setup
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ddQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_ddKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ddQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_ddKtId) {
    $t0 = (Get-Date).AddMinutes(-8).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt = $t0
            rawPayload = @{
                items = @(
                    @{type="organic"; url="https://wikipedia.org/a"; rank_absolute=1}
                    @{type="organic"; url="https://wikipedia.org/b"; rank_absolute=2}
                    @{type="organic"; url="https://reddit.com/x";    rank_absolute=3}
                    @{type="organic"; url="https://stackoverflow.com/q"; rank_absolute=4}
                )
            }
        }
        @{
            capturedAt = $t1
            rawPayload = @{
                items = @(
                    @{type="organic"; url="https://reddit.com/a"; rank_absolute=1}
                    @{type="organic"; url="https://reddit.com/b"; rank_absolute=2}
                    @{type="organic"; url="https://reddit.com/c"; rank_absolute=3}
                    @{type="organic"; url="https://wikipedia.org/a"; rank_absolute=4}
                )
            }
        }
        @{
            capturedAt = $t2
            rawPayload = @{
                items = @(
                    @{type="organic"; url="https://medium.com/p1"; rank_absolute=1}
                )
            }
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_ddQuery; locale="en-US"; device="desktop"
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
    $_ddSetupOk = $allCreated
}

# =============================================================================
# DD-A: 400 invalid UUID
# =============================================================================
try {
    Write-Host "Testing: DD-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$bid/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-B: 400 invalid params
# =============================================================================
try {
    Write-Host "Testing: DD-B 400 on invalid params" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ddKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $cases = @("windowDays=0","windowDays=366","windowDays=abc","limit=0","limit=201","limit=abc")
        $failures = @()
        foreach ($qs in $cases) {
            $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance?$qs" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -ne 400) { $failures += "$qs -> $($r.StatusCode)" }
        }
        if ($failures.Count -eq 0) { Write-Host ("  PASS (" + $cases.Count + " cases)") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-C: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: DD-C 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ddKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-D: 200 + required top-level fields
# =============================================================================
try {
    Write-Host "Testing: DD-D 200 + required top-level fields" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays","snapshotCount","snapshots")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL missing: " + ($missing -join ", ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-E: each snapshot row has required fields
# =============================================================================
try {
    Write-Host "Testing: DD-E snapshot rows have required fields" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $rows = @(($r.Content | ConvertFrom-Json).data.snapshots)
            $required = @("snapshotId","capturedAt","totalResults","uniqueDomains","dominanceIndex","topDomains")
            $failures = @()
            foreach ($row in $rows) {
                $rp = $row | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $miss = $required | Where-Object { $rp -notcontains $_ }
                if ($miss.Count -gt 0) { $failures += "row missing: $($miss -join ', ')" }
            }
            if ($failures.Count -eq 0) { Write-Host ("  PASS (" + $rows.Count + " rows)") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-F: snapshots ordered capturedAt ASC
# =============================================================================
try {
    Write-Host "Testing: DD-F snapshots ordered capturedAt ASC" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $rows = @(($r.Content | ConvertFrom-Json).data.snapshots)
            $fail = $false; $msg = ""
            for ($i = 0; $i -lt ($rows.Count - 1); $i++) {
                if ([string]$rows[$i].capturedAt -gt [string]$rows[$i+1].capturedAt) {
                    $fail = $true; $msg = "rows[$i] > rows[$($i+1)]"; break
                }
            }
            if (-not $fail) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL ($msg)") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-G: topDomains sorted count DESC, domain ASC
# =============================================================================
try {
    Write-Host "Testing: DD-G topDomains sorted count DESC, domain ASC" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $rows = @(($r.Content | ConvertFrom-Json).data.snapshots)
            $failures = @()
            foreach ($row in $rows) {
                $td = @($row.topDomains)
                for ($i = 0; $i -lt ($td.Count - 1); $i++) {
                    $ca = [int]$td[$i].count; $cb = [int]$td[$i+1].count
                    if ($ca -lt $cb) { $failures += "snap $($row.snapshotId): count not DESC at [$i]"; break }
                    if ($ca -eq $cb -and [string]$td[$i].domain -gt [string]$td[$i+1].domain) {
                        $failures += "snap $($row.snapshotId): domain not ASC at [$i]"; break
                    }
                }
            }
            if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-H: known domain counts for snap0 (wikipedia x2, reddit x1)
# =============================================================================
try {
    Write-Host "Testing: DD-H known snap0 domain counts" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $rows = @(($r.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 1) { Write-Host "  SKIP (no rows)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
            else {
                $s0 = $rows[0]
                $top = @($s0.topDomains)
                $wikiEntry = $top | Where-Object { $_.domain -eq "wikipedia.org" } | Select-Object -First 1
                $wikiOk = $wikiEntry -and [int]$wikiEntry.count -eq 2
                $diOk   = [double]$s0.dominanceIndex -eq 0.5
                if ($wikiOk -and $diOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else {
                    Write-Host ("  FAIL (wikiCount=$($wikiEntry.count) dominanceIndex=$($s0.dominanceIndex))") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# DD-I: determinism
# =============================================================================
try {
    Write-Host "Testing: DD-I determinism" -NoNewline
    if (-not $_ddSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_ddBase/$_ddKtId/domain-dominance"
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
# DD-J: POST rejected
# =============================================================================
try {
    Write-Host "Testing: DD-J POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ddKtId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ddBase/$_ddKtId/domain-dominance" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
