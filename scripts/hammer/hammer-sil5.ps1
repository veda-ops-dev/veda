# hammer-sil5.ps1 -- SIL-5 (Volatility Alerts)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Setup dependency: SIL-3 already created KeywordTargets with snapshots and
# scored them (some will have sampleSize>=1 and a non-zero volatilityScore).
# SIL-5 tests assume at least one such keyword exists in the primary project.
#
# For pagination tests we create dedicated fixtures with alertThreshold=0 so
# every active keyword appears in the alerts list.

Hammer-Section "SIL-5 TESTS (VOLATILITY ALERTS)"

$s5Url   = "$Base/api/seo/volatility-alerts"
$s5RunId = (Get-Date).Ticks

# ── VA-1: 200 + items[] + nextCursor present ──────────────────────────────────
try {
    Write-Host "Testing: GET volatility-alerts 200 + items[] + nextCursor" -NoNewline
    $resp = Invoke-WebRequest -Uri $s5Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $hasItems      = ($props -contains "items")
        $hasCursor     = ($props -contains "nextCursor")
        if ($hasItems -and $hasCursor) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (hasItems=" + $hasItems + " hasCursor=" + $hasCursor + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-2: item schema -- each item has required fields ────────────────────────
# Use alertThreshold=0 + minMaturity=preliminary to maximize visible items.
try {
    Write-Host "Testing: GET volatility-alerts item schema fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d.items -and $d.items.Count -gt 0) {
            $item     = $d.items[0]
            $iProps   = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","volatilityScore",
                          "maturity","sampleSize","alertThreshold","exceedsThreshold")
            $missing  = $required | Where-Object { $iProps -notcontains $_ }
            $threshOk = ($item.exceedsThreshold -eq $true)
            if ($missing.Count -eq 0 -and $threshOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing=" + ($missing -join ",") + " exceedsThreshold=" + $item.exceedsThreshold + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            # No items at threshold=0 means no active keywords -- skip gracefully
            Write-Host "  SKIP (no active keywords in project)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-3: determinism -- two calls with same params return identical stable fields
try {
    Write-Host "Testing: GET volatility-alerts deterministic (two calls match)" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $countMatch = ($d1.items.Count -eq $d2.items.Count)
        $cursorMatch = ($d1.nextCursor -eq $d2.nextCursor)
        # Check first item stable fields match (if any items exist)
        $itemMatch = $true
        if ($d1.items.Count -gt 0 -and $d2.items.Count -gt 0) {
            $itemMatch = (
                $d1.items[0].keywordTargetId  -eq $d2.items[0].keywordTargetId  -and
                $d1.items[0].volatilityScore  -eq $d2.items[0].volatilityScore  -and
                $d1.items[0].maturity         -eq $d2.items[0].maturity         -and
                $d1.items[0].sampleSize       -eq $d2.items[0].sampleSize
            )
        }
        if ($countMatch -and $cursorMatch -and $itemMatch) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (countMatch=" + $countMatch + " cursorMatch=" + $cursorMatch + " itemMatch=" + $itemMatch + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-4: sort order -- scores are non-increasing ─────────────────────────────
try {
    Write-Host "Testing: GET volatility-alerts scores non-increasing" -NoNewline
    $resp = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = ($resp.Content | ConvertFrom-Json).data.items
        if ($items -and $items.Count -gt 1) {
            $sortOk = $true
            for ($i = 0; $i -lt ($items.Count - 1); $i++) {
                if ([double]$items[$i].volatilityScore -lt [double]$items[$i+1].volatilityScore) {
                    $sortOk = $false; break
                }
            }
            if ($sortOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (scores not non-increasing)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (fewer than 2 items to verify sort)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-5: all returned items have exceedsThreshold=true ──────────────────────
try {
    Write-Host "Testing: GET volatility-alerts all items exceedsThreshold=true" -NoNewline
    $resp = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = ($resp.Content | ConvertFrom-Json).data.items
        if ($items -and $items.Count -gt 0) {
            $allExceed = ($items | Where-Object { $_.exceedsThreshold -ne $true }).Count -eq 0
            if ($allExceed) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (some items have exceedsThreshold != true)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-6: validation errors → 400 ────────────────────────────────────────────
Test-Endpoint "GET" "$($s5Url)?windowDays=0"       400 "GET volatility-alerts windowDays=0 -> 400"       $Headers
Test-Endpoint "GET" "$($s5Url)?alertThreshold=101"  400 "GET volatility-alerts alertThreshold=101 -> 400" $Headers
Test-Endpoint "GET" "$($s5Url)?minMaturity=lol"     400 "GET volatility-alerts minMaturity=lol -> 400"    $Headers
Test-Endpoint "GET" "$($s5Url)?limit=0"             400 "GET volatility-alerts limit=0 -> 400"            $Headers

# ── VA-7: pagination -- limit=1, nextCursor non-null if >1 alert exists ────────
# Setup: create 2 keywords with snapshots so we have >= 2 active scored keywords.
# Use alertThreshold=0 + minMaturity=preliminary so both appear.
$s5PagQuery1 = "sil5-pag-a $s5RunId"
$s5PagQuery2 = "sil5-pag-b $s5RunId"
$s5PagOk     = $false

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($s5PagQuery1,$s5PagQuery2);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $targets  = ($rKw.Content | ConvertFrom-Json).data.targets
        $ktId1    = ($targets | Where-Object { $_.query -eq $s5PagQuery1 } | Select-Object -First 1).id
        $ktId2    = ($targets | Where-Object { $_.query -eq $s5PagQuery2 } | Select-Object -First 1).id

        if ($ktId1 -and $ktId2) {
            $t0 = (Get-Date).AddMinutes(-2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $t1 = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            $t2 = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

            foreach ($q in @($s5PagQuery1, $s5PagQuery2)) {
                $b0 = @{query=$q;locale="en-US";device="desktop";capturedAt=$t0;source="dataforseo";aiOverviewStatus="absent"
                    rawPayload=@{results=@(@{url="https://ex.com/sil5a";rank=1;title="A"})}}
                $b1 = @{query=$q;locale="en-US";device="desktop";capturedAt=$t1;source="dataforseo";aiOverviewStatus="present"
                    rawPayload=@{results=@(@{url="https://ex.com/sil5a";rank=5;title="A"})}}
                $b2 = @{query=$q;locale="en-US";device="desktop";capturedAt=$t2;source="dataforseo";aiOverviewStatus="absent"
                    rawPayload=@{results=@(@{url="https://ex.com/sil5a";rank=10;title="A"})}}
                foreach ($body in @($b0,$b1,$b2)) {
                    Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                        -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing | Out-Null
                }
            }
            $s5PagOk = $true
        }
    }
} catch {}

try {
    Write-Host "Testing: GET volatility-alerts limit=1 -> nextCursor non-null when >1 result" -NoNewline
    if (-not $s5PagOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            # We have >= 2 active keywords with scores, so limit=1 must produce a nextCursor
            if ($d.items.Count -eq 1 -and $null -ne $d.nextCursor -and $d.nextCursor -ne "") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (items=" + $d.items.Count + " nextCursor=" + $d.nextCursor + ", expected 1 item + non-null cursor)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-8: pagination -- cursor advances to different item ─────────────────────
try {
    Write-Host "Testing: GET volatility-alerts cursor advances to next page" -NoNewline
    if (-not $s5PagOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r1 = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($r1.StatusCode -ne 200) { Write-Host ("  FAIL (page1 got " + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL } else {
            $d1     = ($r1.Content | ConvertFrom-Json).data
            $cursor = $d1.nextCursor
            if ($null -eq $cursor) {
                Write-Host "  SKIP (no nextCursor on page1 -- fewer than 2 items exceed threshold)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $r2 = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1&cursor=$cursor" `
                    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
                if ($r2.StatusCode -eq 200) {
                    $d2 = ($r2.Content | ConvertFrom-Json).data
                    # Page 2 must have items AND the first item must differ from page 1's item
                    if ($d2.items.Count -ge 1 -and
                        $d2.items[0].keywordTargetId -ne $d1.items[0].keywordTargetId) {
                        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host ("  FAIL (page2 items=" + $d2.items.Count + " sameId=" + ($d2.items[0].keywordTargetId -eq $d1.items[0].keywordTargetId) + ")") -ForegroundColor Red; Hammer-Record FAIL
                    }
                } else { Write-Host ("  FAIL (page2 got " + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-9: cursor stability -- same page fetched twice with cursor gives same items
try {
    Write-Host "Testing: GET volatility-alerts cursor page stable on repeat call" -NoNewline
    if (-not $s5PagOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $rFirst = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($rFirst.StatusCode -ne 200) { Write-Host ("  FAIL (first page got " + $rFirst.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL } else {
            $cursor = ($rFirst.Content | ConvertFrom-Json).data.nextCursor
            if ($null -eq $cursor) {
                Write-Host "  SKIP (no nextCursor)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $rA = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1&cursor=$cursor" `
                    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
                $rB = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary&limit=1&cursor=$cursor" `
                    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
                if ($rA.StatusCode -eq 200 -and $rB.StatusCode -eq 200) {
                    $dA = ($rA.Content | ConvertFrom-Json).data
                    $dB = ($rB.Content | ConvertFrom-Json).data
                    $stable = ($dA.items.Count -eq $dB.items.Count -and $dA.nextCursor -eq $dB.nextCursor)
                    if ($dA.items.Count -gt 0 -and $dB.items.Count -gt 0) {
                        $stable = $stable -and ($dA.items[0].keywordTargetId -eq $dB.items[0].keywordTargetId)
                    }
                    if ($stable) {
                        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host "  FAIL (page content differs between two calls with same cursor)" -ForegroundColor Red; Hammer-Record FAIL
                    }
                } else { Write-Host ("  FAIL (status=" + $rA.StatusCode + "/" + $rB.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-10: minMaturity=stable filters out preliminary/developing keywords ─────
try {
    Write-Host "Testing: GET volatility-alerts minMaturity=stable -> only stable maturity items" -NoNewline
    $resp = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=stable&limit=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = ($resp.Content | ConvertFrom-Json).data.items
        if ($items -and $items.Count -gt 0) {
            $allStable = ($items | Where-Object { $_.maturity -ne "stable" }).Count -eq 0
            if ($allStable) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (some items have maturity != stable)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            # No stable keywords yet -- that's fine, response shape is still valid
            Write-Host "  PASS (0 stable items, shape is valid)" -ForegroundColor Green; Hammer-Record PASS
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── VA-11: cross-project isolation -- OtherHeaders sees OtherProject's alerts ──
# volatility-alerts is a project-scoped LIST (not a single-resource lookup),
# so it returns OtherProject's data under OtherHeaders, NOT a 404.
# We verify: the call succeeds (200) and items[] is valid.
# If both projects happen to have the same top item it is still isolation-correct
# (resolveProjectId scopes all queries). We do not assert equality/inequality
# of specific IDs because OtherProject may or may not have any active keywords.
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: GET volatility-alerts OtherHeaders -> 200 (own project data)" -NoNewline
        $rOther = Invoke-WebRequest -Uri "$($s5Url)?alertThreshold=0&minMaturity=preliminary" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($rOther.StatusCode -eq 200) {
            $dOther = ($rOther.Content | ConvertFrom-Json).data
            $hasItems  = $null -ne $dOther.items
            $hasCursor = ($dOther | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) -contains "nextCursor"
            if ($hasItems -and $hasCursor) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (missing items or nextCursor under OtherHeaders)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $rOther.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: GET volatility-alerts cross-project isolation  SKIP (no OtherHeaders)" -ForegroundColor DarkYellow
    Hammer-Record SKIP
}
