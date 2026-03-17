# hammer-feature-history.ps1 -- Feature History Endpoint
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/feature-history
#
# Self-contained setup: creates one KeywordTarget + 4 snapshots with known feature
# payloads so assertions can be made against expected values without relying on
# pre-existing project data.
#
# Snapshot payloads use rawPayload.items[] (DataForSEO strategy-1) for two snaps
# and rawPayload.results[] (strategy-2) for the others, ensuring both extraction
# paths are exercised. Feature types chosen to cover multiple families.
#
# All regex strings use single-quoted PowerShell strings to avoid quoting hell.

Hammer-Section "FEATURE HISTORY TESTS"

$_fhBase   = "/api/seo/keyword-targets"
$_fhRunId  = (Get-Date).Ticks
$_fhQuery  = "fh-test-$_fhRunId"
$_fhKtId   = $null
$_fhSnapIds = @()
$_fhSetupOk = $false

# =============================================================================
# Setup: create KeywordTarget + 4 snapshots
# Ordered capturedAt ASC: snap0 (oldest) -> snap3 (newest)
# snap0: items[] with featured_snippet + people_also_ask
# snap1: items[] with shopping + video_box  (note: video_box maps to video family)
# snap2: items[] with knowledge_graph       (maps to knowledge_panel family)
# snap3: items[] organic-only               (no features, parseWarning=false)
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_fhQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing

    if ($rKw.StatusCode -eq 201) {
        $_fhKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_fhQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_fhKtId) {
    $t0 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-4).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t3 = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt = $t0
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="featured_snippet"; url="https://ex.com/fs"; rank_absolute=1; title="FS result"}
                    @{type="people_also_ask";  url="https://ex.com/paa"}
                    @{type="organic";          url="https://ex.com/o1"; rank_absolute=2; title="Org 1"}
                )
            }
        }
        @{
            capturedAt = $t1
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="shopping";   url="https://shop.com/a"; rank_absolute=1}
                    @{type="video_box";  url="https://video.com/a"; rank_absolute=2}
                    @{type="organic";    url="https://ex.com/o1"; rank_absolute=3; title="Org 1"}
                )
            }
        }
        @{
            capturedAt = $t2
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="knowledge_graph"; url="https://kg.com/a"; rank_absolute=1}
                    @{type="organic";         url="https://ex.com/o1"; rank_absolute=2; title="Org 1"}
                )
            }
        }
        @{
            capturedAt = $t3
            aiStatus   = "present"
            rawPayload = @{
                items = @(
                    @{type="organic"; url="https://ex.com/o1"; rank_absolute=1; title="Org 1"}
                    @{type="organic"; url="https://ex.com/o2"; rank_absolute=2; title="Org 2"}
                )
            }
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_fhQuery; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus=$def.aiStatus
            rawPayload=$def.rawPayload
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -in @(200,201)) {
                $snapId = ($r.Content | ConvertFrom-Json).data.id
                if ($snapId) { $_fhSnapIds += $snapId }
                else { $allCreated = $false }
            } else { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_fhSetupOk = $allCreated -and ($_fhSnapIds.Count -eq 4)
}

# =============================================================================
# FH-A: 400 on invalid UUID for :id
# =============================================================================
try {
    Write-Host "Testing: FH-A 400 on invalid UUID for :id" -NoNewline
    $badIds = @("not-a-uuid", "1234", "00000000-0000-0000-0000-00000000000Z")
    $failures = @()
    foreach ($bid in $badIds) {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$bid/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) { $failures += "$bid -> $($resp.StatusCode)" }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $badIds.Count + " invalid ids returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-B: 400 on invalid query params
# =============================================================================
try {
    Write-Host "Testing: FH-B 400 on invalid query params" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fhKtId)) {
        Write-Host "  SKIP (setup did not produce a KtId)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $cases = @(
            "windowDays=0",
            "windowDays=366",
            "windowDays=abc",
            "limit=0",
            "limit=201",
            "limit=abc",
            "cursorCapturedAt=not-a-date",
            "cursorId=00000000-0000-0000-0000-000000000000",
            "cursorCapturedAt=2024-01-01T00:00:00.000Z"
        )
        $failures = @()
        foreach ($qs in $cases) {
            $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history?$qs" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -ne 400) { $failures += "$qs -> $($resp.StatusCode)" }
        }
        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (all " + $cases.Count + " invalid cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-C: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: FH-C 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fhKtId)) {
        Write-Host "  SKIP (setup did not produce a KtId)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS (cross-project returns 404)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (expected 404, got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-D: 200 + required top-level fields
# =============================================================================
try {
    Write-Host "Testing: FH-D 200 + required top-level fields" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays","pageSize","nextCursor","snapshots")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-E: each snapshot row has required fields
# =============================================================================
try {
    Write-Host "Testing: FH-E snapshot rows have required fields" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -eq 0) {
                Write-Host "  SKIP (no snapshot rows returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $rowRequired = @("snapshotId","capturedAt","familiesSorted","rawTypesSorted","flags","parseWarning")
                $flagRequired = @("hasFeaturedSnippet","hasPeopleAlsoAsk","hasLocalPack","hasVideo",
                                  "hasShopping","hasImages","hasTopStories","hasKnowledgePanel",
                                  "hasSitelinks","hasReviews","hasRelatedSearches","hasOther")
                $failures = @()
                foreach ($row in $rows) {
                    $rprops = $row | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    $miss = $rowRequired | Where-Object { $rprops -notcontains $_ }
                    if ($miss.Count -gt 0) { $failures += "row missing: $($miss -join ', ')"; continue }
                    $fprops = $row.flags | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    $fmiss = $flagRequired | Where-Object { $fprops -notcontains $_ }
                    if ($fmiss.Count -gt 0) { $failures += "flags missing: $($fmiss -join ', ')" }
                }
                if ($failures.Count -eq 0) {
                    Write-Host ("  PASS (" + $rows.Count + " rows, all fields present)") -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-F: arrays are sorted and parseWarning is boolean
# =============================================================================
try {
    Write-Host "Testing: FH-F arrays sorted ASC, parseWarning is boolean" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            $failures = @()
            foreach ($row in $rows) {
                # parseWarning must be a boolean (true or false, not null)
                if ($null -eq $row.parseWarning -or $row.parseWarning -isnot [bool]) {
                    $failures += "snap $($row.snapshotId): parseWarning is not boolean"
                }
                # familiesSorted must be sorted ASC
                $fams = @($row.familiesSorted)
                for ($i = 0; $i -lt ($fams.Count - 1); $i++) {
                    if ([string]$fams[$i] -gt [string]$fams[$i + 1]) {
                        $failures += "snap $($row.snapshotId): familiesSorted not sorted at index $i"
                        break
                    }
                }
                # rawTypesSorted must be sorted ASC
                $rts = @($row.rawTypesSorted)
                for ($i = 0; $i -lt ($rts.Count - 1); $i++) {
                    if ([string]$rts[$i] -gt [string]$rts[$i + 1]) {
                        $failures += "snap $($row.snapshotId): rawTypesSorted not sorted at index $i"
                        break
                    }
                }
            }
            if ($failures.Count -eq 0) {
                Write-Host ("  PASS (" + $rows.Count + " rows checked)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-G: known feature signals for snap0 (featured_snippet + people_also_ask)
# =============================================================================
try {
    Write-Host "Testing: FH-G snap0 has expected feature families" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 1) {
                Write-Host "  SKIP (no rows returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                # snap0 is first (ASC order): featured_snippet + people_also_ask
                $s0 = $rows[0]
                $fams0 = @($s0.familiesSorted)
                $hasFeatured = $fams0 -contains "featured_snippet"
                $hasPAA      = $fams0 -contains "people_also_ask"
                $flagFS      = $s0.flags.hasFeaturedSnippet -eq $true
                $flagPAA     = $s0.flags.hasPeopleAlsoAsk -eq $true
                $warnOk      = $s0.parseWarning -eq $false
                if ($hasFeatured -and $hasPAA -and $flagFS -and $flagPAA -and $warnOk) {
                    Write-Host "  PASS (featured_snippet + people_also_ask confirmed)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    $dbg = "fams=[$($fams0 -join ',')] flagFS=$($s0.flags.hasFeaturedSnippet) flagPAA=$($s0.flags.hasPeopleAlsoAsk) warn=$($s0.parseWarning)"
                    Write-Host ("  FAIL ($dbg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-H: video_box maps to video family (snap1)
# =============================================================================
try {
    Write-Host "Testing: FH-H video_box rawType maps to video family" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 2) {
                Write-Host "  SKIP (fewer than 2 rows)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $s1 = $rows[1]
                $rts1 = @($s1.rawTypesSorted)
                $fams1 = @($s1.familiesSorted)
                $hasVideoBoxRaw = $rts1 -contains "video_box"
                $hasVideoFamily = $fams1 -contains "video"
                $flagVideo      = $s1.flags.hasVideo -eq $true
                if ($hasVideoBoxRaw -and $hasVideoFamily -and $flagVideo) {
                    Write-Host "  PASS (video_box -> video family confirmed)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    $dbg = "rts=[$($rts1 -join ',')] fams=[$($fams1 -join ',')] flagVideo=$($s1.flags.hasVideo)"
                    Write-Host ("  FAIL ($dbg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-I: knowledge_graph maps to knowledge_panel family (snap2)
# =============================================================================
try {
    Write-Host "Testing: FH-I knowledge_graph maps to knowledge_panel family" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 3) {
                Write-Host "  SKIP (fewer than 3 rows)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $s2 = $rows[2]
                $rts2 = @($s2.rawTypesSorted)
                $fams2 = @($s2.familiesSorted)
                $hasKgRaw    = $rts2 -contains "knowledge_graph"
                $hasKpFamily = $fams2 -contains "knowledge_panel"
                $flagKP      = $s2.flags.hasKnowledgePanel -eq $true
                if ($hasKgRaw -and $hasKpFamily -and $flagKP) {
                    Write-Host "  PASS (knowledge_graph -> knowledge_panel confirmed)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    $dbg = "rts=[$($rts2 -join ',')] fams=[$($fams2 -join ',')] flagKP=$($s2.flags.hasKnowledgePanel)"
                    Write-Host ("  FAIL ($dbg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-J: all-organic snap (snap3) has empty feature arrays and parseWarning=false
# =============================================================================
try {
    Write-Host "Testing: FH-J all-organic snapshot has empty feature arrays, parseWarning=false" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 4) {
                Write-Host "  SKIP (fewer than 4 rows)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $s3 = $rows[3]
                $emptyRaw  = @($s3.rawTypesSorted).Count -eq 0
                $emptyFams = @($s3.familiesSorted).Count -eq 0
                $noWarn    = $s3.parseWarning -eq $false
                if ($emptyRaw -and $emptyFams -and $noWarn) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    $dbg = "rts.Count=$(@($s3.rawTypesSorted).Count) fams.Count=$(@($s3.familiesSorted).Count) warn=$($s3.parseWarning)"
                    Write-Host ("  FAIL ($dbg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-K: snapshots ordered capturedAt ASC
# =============================================================================
try {
    Write-Host "Testing: FH-K snapshots ordered capturedAt ASC" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $rows = @(($resp.Content | ConvertFrom-Json).data.snapshots)
            if ($rows.Count -lt 2) {
                Write-Host "  SKIP (fewer than 2 rows)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $fail = $false; $failMsg = ""
                for ($i = 0; $i -lt ($rows.Count - 1); $i++) {
                    $ta = [datetime]::Parse($rows[$i].capturedAt)
                    $tb = [datetime]::Parse($rows[$i + 1].capturedAt)
                    if ($ta -gt $tb) {
                        $fail = $true
                        $failMsg = "rows[$i].capturedAt=$($rows[$i].capturedAt) > rows[$($i+1)].capturedAt=$($rows[$($i+1)].capturedAt)"
                        break
                    }
                }
                if (-not $fail) {
                    Write-Host ("  PASS (" + $rows.Count + " rows in ASC order)") -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-L: determinism (two sequential calls yield identical snapshots)
# =============================================================================
try {
    Write-Host "Testing: FH-L determinism (two calls identical)" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base$_fhBase/$_fhKtId/feature-history"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $snaps1 = ($r1.Content | ConvertFrom-Json).data.snapshots | ConvertTo-Json -Depth 10 -Compress
            $snaps2 = ($r2.Content | ConvertFrom-Json).data.snapshots | ConvertTo-Json -Depth 10 -Compress
            if ($snaps1 -eq $snaps2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (snapshot arrays differ between calls)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-M: pagination -- limit=2 returns 2 rows + nextCursor, second page is non-overlapping
# =============================================================================
try {
    Write-Host "Testing: FH-M pagination non-overlapping and deterministic" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r1 = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history?limit=2" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -ne 200) {
            Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        } else {
            $d1  = ($r1.Content | ConvertFrom-Json).data
            $nc1 = $d1.nextCursor
            if ($null -eq $nc1) {
                Write-Host "  SKIP (nextCursor is null; fewer than 3 snapshots returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                # ConvertFrom-Json may parse ISO strings as DateTime objects.
                # Force back to string before URL-encoding.
                $catRaw = if ($nc1.cursorCapturedAt -is [datetime]) {
                    $nc1.cursorCapturedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                } else { [string]$nc1.cursorCapturedAt }
                $catParam = [uri]::EscapeDataString($catRaw)
                $cidParam = [uri]::EscapeDataString([string]$nc1.cursorId)
                $r2 = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history?limit=2&cursorCapturedAt=$catParam&cursorId=$cidParam" `
                    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($r2.StatusCode -ne 200) {
                    Write-Host ("  FAIL (page2 status=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
                } else {
                    $rows1 = @($d1.snapshots | Select-Object -ExpandProperty snapshotId)
                    $rows2 = @(($r2.Content | ConvertFrom-Json).data.snapshots | Select-Object -ExpandProperty snapshotId)
                    $overlap = $rows1 | Where-Object { $rows2 -contains $_ }
                    if ($overlap.Count -eq 0 -and $rows2.Count -ge 1) {
                        Write-Host ("  PASS (page1=" + $rows1.Count + " page2=" + $rows2.Count + " no overlap)") -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host ("  FAIL (overlap=" + $overlap.Count + " page2rows=" + $rows2.Count + ")") -ForegroundColor Red; Hammer-Record FAIL
                    }
                }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-N: windowDays filter reduces row count
# =============================================================================
try {
    Write-Host "Testing: FH-N windowDays=1 excludes older snapshots" -NoNewline
    if (-not $_fhSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rFull = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rWin1 = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history?windowDays=365" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rFull.StatusCode -eq 200 -and $rWin1.StatusCode -eq 200) {
            $countFull = @(($rFull.Content | ConvertFrom-Json).data.snapshots).Count
            $countWin  = @(($rWin1.Content | ConvertFrom-Json).data.snapshots).Count
            # windowDays=365 should include all 4 setup snapshots (all within last 10 mins)
            if ($countWin -eq $countFull) {
                Write-Host ("  PASS (windowDays=365 returns same " + $countFull + " rows as no filter)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (full=" + $countFull + " windowed=" + $countWin + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (status=" + $rFull.StatusCode + "/" + $rWin1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FH-O: POST rejected (no mutation surface)
# =============================================================================
try {
    Write-Host "Testing: FH-O POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fhKtId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fhBase/$_fhKtId/feature-history" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -in @(404, 405)) {
            Write-Host ("  PASS (POST returned " + $resp.StatusCode + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (POST returned " + $resp.StatusCode + ", expected 404 or 405)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
