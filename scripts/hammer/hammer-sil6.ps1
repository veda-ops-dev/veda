# hammer-sil6.ps1 — SIL-6 (SERP History Time Series)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Setup: creates a dedicated KeywordTarget with 4 snapshots:
#   snap-OLD  capturedAt = now - 400 days  (used for windowDays filter test)
#   snap-A    capturedAt = now - 2 minutes (oldest of the "recent" trio)
#   snap-B    capturedAt = now - 1 minute
#   snap-C    capturedAt = now             (most recent)
#
# The endpoint orders capturedAt DESC, id DESC so the expected item order is:
#   snap-C, snap-B, snap-A  (snap-OLD filtered out under windowDays=1)

Hammer-Section "SIL-6 TESTS (SERP HISTORY)"

$s6Url   = "$Base/api/seo/keyword-targets"
$s6RunId = (Get-Date).Ticks

# ── Setup: create KeywordTarget ───────────────────────────────────────────────
$s6Query  = "sil6-history $s6RunId"
$s6KtId   = $null
$s6SnapIds = @{}   # keys: OLD, A, B, C

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($s6Query);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $s6KtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $s6Query } | Select-Object -First 1).id
    }
} catch {}

# ── Setup: create 4 snapshots ─────────────────────────────────────────────────
$s6SnapOk = $false
if ($s6KtId) {
    $tOLD = (Get-Date).AddDays(-400).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tA   = (Get-Date).AddMinutes(-2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tB   = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $tC   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $snapshotDefs = @(
        @{ key="OLD"; capturedAt=$tOLD; aiStatus="absent";  urls=@("https://old.example.com/1","https://old.example.com/2") }
        @{ key="A";   capturedAt=$tA;   aiStatus="absent";  urls=@("https://ex.com/a1","https://ex.com/a2","https://ex.com/a3") }
        @{ key="B";   capturedAt=$tB;   aiStatus="present"; urls=@("https://ex.com/a1","https://ex.com/b1","https://ex.com/b2") }
        @{ key="C";   capturedAt=$tC;   aiStatus="absent";  urls=@("https://ex.com/c1","https://ex.com/a1","https://ex.com/c2") }
    )

    $allCreated = $true
    foreach ($def in $snapshotDefs) {
        $results = @()
        $rank = 1
        foreach ($url in $def.urls) {
            $results += @{url=$url; rank=$rank; title="Title $rank"}
            $rank++
        }
        $body = @{
            query=$s6Query; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus=$def.aiStatus
            rawPayload=@{results=$results}
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -in @(200,201)) {
                $snapId = ($r.Content | ConvertFrom-Json).data.id
                if ($snapId) { $s6SnapIds[$def.key] = $snapId }
                else { $allCreated = $false }
            } else { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $s6SnapOk = $allCreated -and ($s6SnapIds.Count -eq 4)
}

$s6Base = "$s6Url/$s6KtId/serp-history"

# ── SH-1: 200 + required top-level fields ─────────────────────────────────────
try {
    Write-Host "Testing: GET serp-history 200 + required fields" -NoNewline
    if (-not $s6KtId) { Write-Host "  SKIP (no KT)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri $s6Base -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays","items","nextCursor")
            $missing = $required | Where-Object { $props -notcontains $_ }
            $itemsOk = ($d.items -is [array])
            if ($missing.Count -eq 0 -and $itemsOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing=" + ($missing -join ",") + " itemsIsArray=" + $itemsOk + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-2: items.Count <= limit ────────────────────────────────────────────────
try {
    Write-Host "Testing: GET serp-history items.Count <= limit" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?limit=2" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            if ($d.items.Count -le 2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (items.Count=" + $d.items.Count + " > limit=2)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-3: ordering — capturedAt desc (most recent first = snap-C, snap-B, snap-A, snap-OLD) ──
try {
    Write-Host "Testing: GET serp-history ordering capturedAt desc" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = ($resp.Content | ConvertFrom-Json).data.items
            $sortedOk = $true
            for ($i = 0; $i -lt ($items.Count - 1); $i++) {
                $dtA = [datetime]::Parse($items[$i].capturedAt)
                $dtB = [datetime]::Parse($items[$i+1].capturedAt)
                if ($dtA -lt $dtB) { $sortedOk = $false; break }
                # id desc tie-break: if same capturedAt, later id must come first
                if ($dtA -eq $dtB -and $items[$i].snapshotId -lt $items[$i+1].snapshotId) {
                    $sortedOk = $false; break
                }
            }
            # snap-C should be first
            $firstIsC = ($items.Count -gt 0 -and $items[0].snapshotId -eq $s6SnapIds["C"])
            if ($sortedOk -and $firstIsC) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sortedOk=" + $sortedOk + " firstIsC=" + $firstIsC + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-4: topN respected — each item has <= topN results ─────────────────────
try {
    Write-Host "Testing: GET serp-history topN=2 -> each item topResults.Count <= 2" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?topN=2&limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = ($resp.Content | ConvertFrom-Json).data.items
            $allOk = $true
            foreach ($item in $items) {
                if ($item.topResults.Count -gt 2) { $allOk = $false; break }
            }
            if ($allOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (some items have topResults.Count > 2)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-5: includePayload=false → rawPayload absent ───────────────────────────
try {
    Write-Host "Testing: GET serp-history includePayload=false -> rawPayload absent" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?includePayload=false&limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = ($resp.Content | ConvertFrom-Json).data.items
            $noPayload = $true
            foreach ($item in $items) {
                $iProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($iProps -contains "rawPayload") { $noPayload = $false; break }
            }
            if ($noPayload) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (rawPayload present despite includePayload=false)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-6: includePayload=true → rawPayload present ───────────────────────────
try {
    Write-Host "Testing: GET serp-history includePayload=true -> rawPayload present" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?includePayload=true&limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = ($resp.Content | ConvertFrom-Json).data.items
            $allHave = $true
            if ($items.Count -eq 0) { $allHave = $false }
            foreach ($item in $items) {
                $iProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($iProps -notcontains "rawPayload") { $allHave = $false; break }
            }
            if ($allHave) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (rawPayload absent despite includePayload=true)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-7: windowDays=1 → snap-OLD (400 days ago) excluded ────────────────────
try {
    Write-Host "Testing: GET serp-history windowDays=1 excludes 400-day-old snapshot" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $respAll = Invoke-WebRequest -Uri "$($s6Base)?limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        $respWin = Invoke-WebRequest -Uri "$($s6Base)?windowDays=1&limit=50" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($respAll.StatusCode -eq 200 -and $respWin.StatusCode -eq 200) {
            $allItems = ($respAll.Content | ConvertFrom-Json).data.items
            $winItems = ($respWin.Content | ConvertFrom-Json).data.items
            # All results contains snap-OLD; window results must not
            $hasOldInAll = ($allItems | Where-Object { $_.snapshotId -eq $s6SnapIds["OLD"] }).Count -gt 0
            $hasOldInWin = ($winItems | Where-Object { $_.snapshotId -eq $s6SnapIds["OLD"] }).Count -gt 0
            $windowedFewer = ($winItems.Count -lt $allItems.Count)
            if ($hasOldInAll -and -not $hasOldInWin -and $windowedFewer) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (hasOldInAll=" + $hasOldInAll + " hasOldInWin=" + $hasOldInWin + " windowedFewer=" + $windowedFewer + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (statusAll=" + $respAll.StatusCode + " statusWin=" + $respWin.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-8: pagination — limit=1, nextCursor non-null ──────────────────────────
$s6CursorFromPage1 = $null
try {
    Write-Host "Testing: GET serp-history limit=1 -> nextCursor non-null" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s6Base)?limit=1" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            # We have 4 snapshots so page1 with limit=1 must produce a cursor
            if ($d.items.Count -eq 1 -and $null -ne $d.nextCursor -and $d.nextCursor -ne "") {
                $s6CursorFromPage1 = $d.nextCursor
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (items=" + $d.items.Count + " nextCursor=" + $d.nextCursor + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-9: pagination — cursor advances to next snapshot ──────────────────────
try {
    Write-Host "Testing: GET serp-history cursor -> returns next item (different snapshotId)" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    elseif (-not $s6CursorFromPage1) { Write-Host "  SKIP (no cursor from SH-8)" -ForegroundColor DarkYellow; Hammer-Record SKIP }
    else {
        # Page 1 must have been snap-C (most recent). Page 2 must be snap-B.
        $rPage1 = Invoke-WebRequest -Uri "$($s6Base)?limit=1" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        $rPage2 = Invoke-WebRequest -Uri "$($s6Base)?limit=1&cursor=$s6CursorFromPage1" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($rPage1.StatusCode -eq 200 -and $rPage2.StatusCode -eq 200) {
            $p1Item = ($rPage1.Content | ConvertFrom-Json).data.items[0]
            $p2Item = ($rPage2.Content | ConvertFrom-Json).data.items[0]
            $different = ($null -ne $p2Item -and $p1Item.snapshotId -ne $p2Item.snapshotId)
            # Page 2 item must be snap-B (second most recent)
            $isSnapB   = ($null -ne $p2Item -and $p2Item.snapshotId -eq $s6SnapIds["B"])
            if ($different -and $isSnapB) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (different=" + $different + " isSnapB=" + $isSnapB + " p2Id=" + $p2Item.snapshotId + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $rPage1.StatusCode + "/" + $rPage2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-10: determinism — two identical calls yield identical stable fields ────
try {
    Write-Host "Testing: GET serp-history deterministic (two calls match)" -NoNewline
    if (-not $s6SnapOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r1 = Invoke-WebRequest -Uri "$($s6Base)?limit=50&topN=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri "$($s6Base)?limit=50&topN=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $countMatch  = ($d1.items.Count -eq $d2.items.Count)
            $cursorMatch = ($d1.nextCursor -eq $d2.nextCursor)
            $idsMatch = $true
            if ($countMatch -and $d1.items.Count -gt 0) {
                for ($i = 0; $i -lt $d1.items.Count; $i++) {
                    if ($d1.items[$i].snapshotId -ne $d2.items[$i].snapshotId -or
                        $d1.items[$i].capturedAt -ne $d2.items[$i].capturedAt -or
                        $d1.items[$i].aiOverviewStatus -ne $d2.items[$i].aiOverviewStatus) {
                        $idsMatch = $false; break
                    }
                }
            }
            if ($countMatch -and $cursorMatch -and $idsMatch) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (countMatch=" + $countMatch + " cursorMatch=" + $cursorMatch + " idsMatch=" + $idsMatch + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SH-11: cross-project → 404 non-disclosure ─────────────────────────────────
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: GET serp-history cross-project -> 404" -NoNewline
        if (-not $s6KtId) { Write-Host "  SKIP (no KT)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
            $resp = Invoke-WebRequest -Uri "$s6Base" -Method GET -Headers $OtherHeaders `
                -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
            if ($resp.StatusCode -eq 404) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: GET serp-history cross-project -> 404  SKIP (no OtherHeaders)" -ForegroundColor DarkYellow
    Hammer-Record SKIP
}

# ── SH-V: validation errors ───────────────────────────────────────────────────
$s6ValBase = "$s6Url/00000000-0000-4000-a000-000000000001/serp-history"
Test-Endpoint "GET" "$s6Url/not-a-uuid/serp-history"          400 "GET serp-history invalid UUID -> 400"                 $Headers
Test-Endpoint "GET" "$($s6ValBase)?windowDays=0"               400 "GET serp-history windowDays=0 -> 400"                 $Headers
Test-Endpoint "GET" "$($s6ValBase)?windowDays=366"             400 "GET serp-history windowDays=366 -> 400"               $Headers
Test-Endpoint "GET" "$($s6ValBase)?limit=0"                    400 "GET serp-history limit=0 -> 400"                      $Headers
Test-Endpoint "GET" "$($s6ValBase)?limit=201"                  400 "GET serp-history limit=201 -> 400"                    $Headers
Test-Endpoint "GET" "$($s6ValBase)?topN=0"                     400 "GET serp-history topN=0 -> 400"                       $Headers
Test-Endpoint "GET" "$($s6ValBase)?topN=21"                    400 "GET serp-history topN=21 -> 400"                      $Headers
Test-Endpoint "GET" "$($s6ValBase)?includePayload=maybe"       400 "GET serp-history includePayload=maybe -> 400"         $Headers
# Valid UUID but nonexistent → 404
Test-Endpoint "GET" "$s6Url/00000000-0000-4000-a000-000000000001/serp-history" 404 "GET serp-history not found -> 404"   $Headers
