# hammer-serp-similarity.ps1 -- SERP Structural Similarity Sensor
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/serp-similarity
#
# Setup: creates one KT + 3 snapshots:
#   snap0: domain=wikipedia.org, feature=featured_snippet
#   snap1: domain=wikipedia.org (same), feature=video       (domain Jaccard=1.0, family Jaccard=0.0)
#   snap2: domain=reddit.com    (diff), feature=video (same)(domain Jaccard=0.0, family Jaccard=1.0)
#
# Expected pairs:
#   pair0 (snap0->snap1): domainSimilarity=1.0, familySimilarity=0.0, combined=0.5
#   pair1 (snap1->snap2): domainSimilarity=0.0, familySimilarity=1.0, combined=0.5

Hammer-Section "SERP SIMILARITY TESTS"

$_ssBase   = "/api/seo/keyword-targets"
$_ssRunId  = (Get-Date).Ticks
$_ssQuery  = "ss-test-$_ssRunId"
$_ssKtId   = $null
$_ssSetupOk = $false

# =============================================================================
# Setup
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_ssQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $_ssKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_ssQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_ssKtId) {
    $t0 = (Get-Date).AddMinutes(-8).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt = $t0
            rawPayload = @{
                items = @(
                    @{type="featured_snippet"; url="https://wikipedia.org/fs"; rank_absolute=1}
                    @{type="organic";          url="https://wikipedia.org/o1"; rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t1
            rawPayload = @{
                items = @(
                    @{type="video";   url="https://wikipedia.org/v1"; rank_absolute=1}
                    @{type="organic"; url="https://wikipedia.org/o1"; rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t2
            rawPayload = @{
                items = @(
                    @{type="video";   url="https://reddit.com/v1"; rank_absolute=1}
                    @{type="organic"; url="https://reddit.com/o1"; rank_absolute=2}
                )
            }
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_ssQuery; locale="en-US"; device="desktop"
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
    $_ssSetupOk = $allCreated
}

# =============================================================================
# SS-A: 400 invalid UUID
# =============================================================================
try {
    Write-Host "Testing: SS-A 400 on invalid UUID for :id" -NoNewline
    $failures = @()
    foreach ($bid in @("not-a-uuid","1234","00000000-0000-0000-0000-00000000000Z")) {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$bid/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -ne 400) { $failures += "$bid -> $($r.StatusCode)" }
    }
    if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-B: 400 invalid params
# =============================================================================
try {
    Write-Host "Testing: SS-B 400 on invalid params" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ssKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $cases = @("windowDays=0","windowDays=366","windowDays=abc","limit=0","limit=201","limit=abc")
        $failures = @()
        foreach ($qs in $cases) {
            $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity?$qs" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -ne 400) { $failures += "$qs -> $($r.StatusCode)" }
        }
        if ($failures.Count -eq 0) { Write-Host ("  PASS (" + $cases.Count + " cases)") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-C: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: SS-C 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ssKtId)) {
        Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-D: 200 + required top-level fields
# =============================================================================
try {
    Write-Host "Testing: SS-D 200 + required top-level fields" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays","pairCount","pairs")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL missing: " + ($missing -join ", ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-E: each pair has required fields with similarity scores in [0,1]
# =============================================================================
try {
    Write-Host "Testing: SS-E pair rows have required fields, scores in [0,1]" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $pairs = @(($r.Content | ConvertFrom-Json).data.pairs)
            $required = @("fromSnapshotId","toSnapshotId","capturedAt","domainSimilarity","familySimilarity","combinedSimilarity")
            $failures = @()
            foreach ($p in $pairs) {
                $pp = $p | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $miss = $required | Where-Object { $pp -notcontains $_ }
                if ($miss.Count -gt 0) { $failures += "pair missing: $($miss -join ', ')"; continue }
                foreach ($field in @("domainSimilarity","familySimilarity","combinedSimilarity")) {
                    $v = [double]$p.$field
                    if ($v -lt 0 -or $v -gt 1) { $failures += "pair $field=$v out of [0,1]" }
                }
            }
            if ($failures.Count -eq 0) { Write-Host ("  PASS (" + $pairs.Count + " pairs)") -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-F: pairs sorted capturedAt ASC
# =============================================================================
try {
    Write-Host "Testing: SS-F pairs sorted capturedAt ASC" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $pairs = @(($r.Content | ConvertFrom-Json).data.pairs)
            $fail = $false; $msg = ""
            for ($i = 0; $i -lt ($pairs.Count - 1); $i++) {
                if ([string]$pairs[$i].capturedAt -gt [string]$pairs[$i+1].capturedAt) {
                    $fail = $true; $msg = "pairs[$i] > pairs[$($i+1)]"; break
                }
            }
            if (-not $fail) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL ($msg)") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-G: known values -- pair0 domainSimilarity=1.0, familySimilarity=0.0
# =============================================================================
try {
    Write-Host "Testing: SS-G pair0 domainSimilarity=1.0, familySimilarity=0.0" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $pairs = @(($r.Content | ConvertFrom-Json).data.pairs)
            if ($pairs.Count -lt 1) { Write-Host "  SKIP (no pairs)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
            else {
                $p0 = $pairs[0]
                $domOk = [double]$p0.domainSimilarity -eq 1.0
                $famOk = [double]$p0.familySimilarity -eq 0.0
                $comOk = [double]$p0.combinedSimilarity -eq 0.5
                if ($domOk -and $famOk -and $comOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (dom=$($p0.domainSimilarity) fam=$($p0.familySimilarity) com=$($p0.combinedSimilarity))") -ForegroundColor Red; Hammer-Record FAIL }
            }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-H: known values -- pair1 domainSimilarity=0.0, familySimilarity=1.0
# =============================================================================
try {
    Write-Host "Testing: SS-H pair1 domainSimilarity=0.0, familySimilarity=1.0" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $pairs = @(($r.Content | ConvertFrom-Json).data.pairs)
            if ($pairs.Count -lt 2) { Write-Host "  SKIP (fewer than 2 pairs)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
            else {
                $p1 = $pairs[1]
                $domOk = [double]$p1.domainSimilarity -eq 0.0
                $famOk = [double]$p1.familySimilarity -eq 1.0
                $comOk = [double]$p1.combinedSimilarity -eq 0.5
                if ($domOk -and $famOk -and $comOk) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (dom=$($p1.domainSimilarity) fam=$($p1.familySimilarity) com=$($p1.combinedSimilarity))") -ForegroundColor Red; Hammer-Record FAIL }
            }
        } else { Write-Host ("  FAIL (got " + $r.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SS-I: determinism
# =============================================================================
try {
    Write-Host "Testing: SS-I determinism" -NoNewline
    if (-not $_ssSetupOk) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $url = "$Base$_ssBase/$_ssKtId/serp-similarity"
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
# SS-J: POST rejected
# =============================================================================
try {
    Write-Host "Testing: SS-J POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_ssKtId)) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        $r = Invoke-WebRequest -Uri "$Base$_ssBase/$_ssKtId/serp-similarity" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -in @(404,405)) { Write-Host ("  PASS ($($r.StatusCode))") -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL ($($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
