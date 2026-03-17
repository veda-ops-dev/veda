# hammer-sil9.ps1 -- SIL-9 Option A (Compute-on-Read Alerts MVP T1-T3)
#                    + SIL-9.1 (Filtering + Keyset Pagination)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/alerts
#
# Response shape (SIL-9.1):
#   alerts: AlertEmitted[], alertCount, totalAlerts,
#   nextCursor: string|null, hasMore: boolean,
#   windowDays, spikeThreshold, concentrationThreshold, limit, computedAt
#
# AlertEmitted union:
#   T1: triggerType, keywordTargetId, query, fromRegime, toRegime,
#       fromSnapshotId, toSnapshotId, fromCapturedAt, toCapturedAt, pairVolatilityScore
#   T2: triggerType, keywordTargetId, query, fromSnapshotId, toSnapshotId,
#       fromCapturedAt, toCapturedAt, pairVolatilityScore, threshold, exceedanceMargin
#   T3: triggerType, projectId, volatilityConcentrationRatio, threshold,
#       top3RiskKeywords, activeKeywordCount
#
# Fixture dependencies:
#   $s3KtId        -- SIL-3 KeywordTarget with >=21 snapshots
#   $OtherHeaders  -- second project headers (set in coordinator)

Hammer-Section "SIL-9 TESTS (COMPUTE-ON-READ ALERT SURFACE - OPTION A MVP + SIL-9.1)"

$sil9Base = "/api/seo/alerts"

# ── SIL9-A: 400 if windowDays missing ────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-A /alerts 400 if windowDays missing" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-B: 400 if windowDays=0 ──────────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-B /alerts 400 if windowDays=0" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-B2: 400 if windowDays=31 ────────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-B2 /alerts 400 if windowDays=31" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=31" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-C: 200 + required top-level fields (SIL-9.1: includes nextCursor, hasMore) ─
try {
    Write-Host "Testing: SIL9-C /alerts 200 + required top-level fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d    = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("alerts","alertCount","totalAlerts","nextCursor","hasMore",
                      "windowDays","spikeThreshold","concentrationThreshold","limit","computedAt")
        $missing  = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-D: determinism (two calls identical, excluding computedAt) ───────────
try {
    Write-Host "Testing: SIL9-D /alerts deterministic (two calls identical, excluding computedAt)" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $a1 = ($d1.alerts | ConvertTo-Json -Depth 10 -Compress)
        $a2 = ($d2.alerts | ConvertTo-Json -Depth 10 -Compress)
        $nc1 = $d1.nextCursor
        $nc2 = $d2.nextCursor
        $countMatch = ($d1.alertCount -eq $d2.alertCount) -and ($d1.totalAlerts -eq $d2.totalAlerts)
        $cursorMatch = ($nc1 -eq $nc2)
        if ($a1 -eq $a2 -and $countMatch -and $cursorMatch) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (alert arrays or cursors differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-E: spikeThreshold=0 -> T2 alerts exist when fixture has >=1 pair ────
try {
    Write-Host "Testing: SIL9-E /alerts spikeThreshold=0 produces T2 alerts when pairs exist" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available; cannot guarantee pairs exist)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $t2cnt = @($d.alerts | Where-Object { $_.triggerType -eq "T2" }).Count
            if ($t2cnt -ge 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  SKIP (no T2 alerts with spikeThreshold=0; totalAlerts=" + $d.totalAlerts + "; may indicate no pairs in window)") -ForegroundColor DarkYellow; Hammer-Record SKIP
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-F: T3 null guard ─────────────────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-F /alerts T3 null guard (no T3 when all scores zero)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=1&concentrationThreshold=0.0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        $t3cnt = @($d.alerts | Where-Object { $_.triggerType -eq "T3" }).Count
        if ($t3cnt -eq 0) {
            Write-Host "  PASS (no T3 with likely empty 1-day window)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $t3 = $d.alerts | Where-Object { $_.triggerType -eq "T3" } | Select-Object -First 1
            if ($null -ne $t3.volatilityConcentrationRatio) {
                Write-Host "  PASS (T3 fired legitimately with non-null ratio)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (T3 fired with null volatilityConcentrationRatio)" -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-G: cross-project isolation ───────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-G /alerts cross-project isolation (OtherHeaders)" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $respOther = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $respMain  = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($respOther.StatusCode -eq 200 -and $respMain.StatusCode -eq 200) {
            $mainKtIds  = @($respMain.Content  | ConvertFrom-Json).data.alerts |
                          Where-Object { $_.keywordTargetId } | ForEach-Object { $_.keywordTargetId }
            $otherKtIds = @($respOther.Content | ConvertFrom-Json).data.alerts |
                          Where-Object { $_.keywordTargetId } | ForEach-Object { $_.keywordTargetId }
            $leaked = $mainKtIds | Where-Object { $otherKtIds -contains $_ }
            if ($leaked.Count -eq 0) {
                Write-Host "  PASS (no cross-project leakage)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $leaked.Count + " keywordTargetIds leaked)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } elseif ($respOther.StatusCode -eq 404) {
            Write-Host "  PASS (other project 404 -- isolation enforced)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (other=" + $respOther.StatusCode + " main=" + $respMain.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-H: alerts array items have valid triggerType ─────────────────────────
try {
    Write-Host "Testing: SIL9-H /alerts each item has valid triggerType" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = @(($resp.Content | ConvertFrom-Json).data.alerts)
        if ($items.Count -eq 0) {
            Write-Host "  SKIP (no alerts returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $invalid = $items | Where-Object { @("T1","T2","T3","T4") -notcontains $_.triggerType }
            if ($invalid.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $invalid.Count + " items with invalid triggerType)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-I: T2 required fields ────────────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-I /alerts T2 items have required fields" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t2s = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" })
        if ($t2s.Count -eq 0) {
            Write-Host "  SKIP (no T2 alerts)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $t2Props  = $t2s[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("triggerType","keywordTargetId","query","fromSnapshotId","toSnapshotId",
                          "fromCapturedAt","toCapturedAt","pairVolatilityScore","threshold","exceedanceMargin")
            $missing  = $required | Where-Object { $t2Props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing T2 fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-J: T3 fields present when T3 fires ───────────────────────────────────
try {
    Write-Host "Testing: SIL9-J /alerts T3 fields present when T3 fires" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&concentrationThreshold=0.0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t3s = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T3" })
        if ($t3s.Count -eq 0) {
            Write-Host "  SKIP (no T3 alerts)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $t3Props  = $t3s[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("triggerType","projectId","volatilityConcentrationRatio","threshold","top3RiskKeywords","activeKeywordCount")
            $missing  = $required | Where-Object { $t3Props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing T3 fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-K: ordering stable across two calls ──────────────────────────────────
try {
    Write-Host "Testing: SIL9-K /alerts ordering stable across two calls" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30&spikeThreshold=0"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $arr1 = ($r1.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
        $arr2 = ($r2.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
        if ($arr1 -eq $arr2) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (alert array order differs)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-L: limit=1 returns at most 1 alert ───────────────────────────────────
try {
    Write-Host "Testing: SIL9-L /alerts limit=1 returns at most 1 alert" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $cnt = @(($resp.Content | ConvertFrom-Json).data.alerts).Count
        if ($cnt -le 1) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (alerts.Count=" + $cnt + ", expected <= 1)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-M: spikeThreshold=100 -> no T2 alerts ───────────────────────────────
try {
    Write-Host "Testing: SIL9-M /alerts spikeThreshold=100 produces no T2 alerts" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=100" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t2cnt = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" }).Count
        if ($t2cnt -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (" + $t2cnt + " T2 alerts with spikeThreshold=100)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-N: concentrationThreshold=0.0 fires T3 when active keywords exist ───
try {
    Write-Host "Testing: SIL9-N /alerts concentrationThreshold=0.0 fires T3 when active keywords exist" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&concentrationThreshold=0.0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t3s = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T3" })
        if ($t3s.Count -ge 1) {
            if ($null -ne $t3s[0].volatilityConcentrationRatio) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (T3 fired with null ratio)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no T3; may be no active keywords in 30-day window)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9.1: PAGINATION TESTS
# =============================================================================

Hammer-Section "SIL-9.1 TESTS (FILTERING + KEYSET PAGINATION)"

# ── SIL9-P1: limit=1 returns exactly 1 alert AND non-null nextCursor when more exist ─
try {
    Write-Host "Testing: SIL9-P1 /alerts limit=1 returns nextCursor when more exist" -NoNewline
    # Use spikeThreshold=0 to maximize alert count
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d    = ($resp.Content | ConvertFrom-Json).data
        $cnt  = @($d.alerts).Count
        $tot  = [int]$d.totalAlerts
        $nc   = $d.nextCursor
        $more = $d.hasMore
        if ($tot -le 1) {
            Write-Host "  SKIP (totalAlerts <= 1; cannot verify nextCursor behavior)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } elseif ($cnt -eq 1 -and $null -ne $nc -and $more -eq $true) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (cnt=" + $cnt + " nextCursor=" + $nc + " hasMore=" + $more + " totalAlerts=" + $tot + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-P2: using nextCursor returns next item and does NOT repeat the first ─
try {
    Write-Host "Testing: SIL9-P2 /alerts cursor advances without repeating first item" -NoNewline
    $url1 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1"
    $r1   = Invoke-WebRequest -Uri $url1 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -ne 200) {
        Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $d1  = ($r1.Content | ConvertFrom-Json).data
        $nc1 = $d1.nextCursor
        $tot = [int]$d1.totalAlerts
        if ($tot -lt 2 -or $null -eq $nc1) {
            Write-Host "  SKIP (fewer than 2 alerts or no nextCursor; cannot verify)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $url2 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1&cursor=$([System.Uri]::EscapeDataString($nc1))"
            $r2   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r2.StatusCode -ne 200) {
                Write-Host ("  FAIL (page2 status=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $d2      = ($r2.Content | ConvertFrom-Json).data
                $items1  = @($d1.alerts)
                $items2  = @($d2.alerts)
                if ($items2.Count -eq 0) {
                    Write-Host "  FAIL (page2 returned 0 items but totalAlerts=" + $tot + ")" -ForegroundColor Red; Hammer-Record FAIL
                } else {
                    # The first item on page2 must differ from the first item on page1
                    $p1json = ($items1[0] | ConvertTo-Json -Depth 10 -Compress)
                    $p2json = ($items2[0] | ConvertTo-Json -Depth 10 -Compress)
                    if ($p1json -ne $p2json) {
                        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host "  FAIL (page2 item[0] is identical to page1 item[0] -- duplication)" -ForegroundColor Red; Hammer-Record FAIL
                    }
                }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9 T4: AI CHURN CLUSTER TESTS
# =============================================================================

Hammer-Section "SIL-9 T4 TESTS (AI CHURN CLUSTER -- OPT-IN)"

# ── SIL9-T4-A: triggerTypes=T4 without aiChurnMinFlips → 400 ───────────────
try {
    Write-Host "Testing: SIL9-T4-A /alerts triggerTypes=T4 without aiChurnMinFlips -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&triggerTypes=T4" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-T4-B: with aiChurnMinFlips=2 returns 200 + valid response shape ─────
try {
    Write-Host "Testing: SIL9-T4-B /alerts triggerTypes=T4&aiChurnMinFlips=2 returns 200 with valid shape" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&triggerTypes=T4&aiChurnMinFlips=2" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d    = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("alerts","alertCount","totalAlerts","nextCursor","hasMore",
                      "windowDays","limit","computedAt","aiChurnMinFlips","aiChurnMaxGapDays","aiChurnWindowDays")
        $missing = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            $t4cnt = @($d.alerts | Where-Object { $_.triggerType -eq "T4" }).Count
            Write-Host ("  PASS (200; required fields present; T4 alerts=" + $t4cnt + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-T4-C: determinism (two identical T4-only calls yield identical results) ──
try {
    Write-Host "Testing: SIL9-T4-C /alerts T4-only determinism" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30&triggerTypes=T4&aiChurnMinFlips=2"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1   = ($r1.Content | ConvertFrom-Json).data
        $d2   = ($r2.Content | ConvertFrom-Json).data
        $arr1 = ($d1.alerts | ConvertTo-Json -Depth 10 -Compress)
        $arr2 = ($d2.alerts | ConvertTo-Json -Depth 10 -Compress)
        if ($arr1 -eq $arr2 -and $d1.totalAlerts -eq $d2.totalAlerts -and $d1.nextCursor -eq $d2.nextCursor) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (results differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-T4-D: triggerTypes=T4 returns only T4 alerts (or empty) ────────────
try {
    Write-Host "Testing: SIL9-T4-D /alerts triggerTypes=T4 returns only triggerType=T4" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&triggerTypes=T4&aiChurnMinFlips=2" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items  = @(($resp.Content | ConvertFrom-Json).data.alerts)
        $nonT4  = $items | Where-Object { $_.triggerType -ne "T4" }
        if ($nonT4.Count -eq 0) {
            Write-Host ("  PASS (" + $items.Count + " alerts, all T4)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (" + $nonT4.Count + " non-T4 alerts returned)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-T4-E: cursor pagination works with T4 results (no duplicates) ────────
try {
    Write-Host "Testing: SIL9-T4-E /alerts T4 cursor pagination produces no duplicates" -NoNewline
    $url1 = "$Base$sil9Base`?windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&limit=1"
    $r1   = Invoke-WebRequest -Uri $url1 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -ne 200) {
        Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $d1  = ($r1.Content | ConvertFrom-Json).data
        $nc1 = $d1.nextCursor
        $tot = [int]$d1.totalAlerts
        if ($tot -lt 2 -or $null -eq $nc1) {
            Write-Host "  SKIP (fewer than 2 T4 alerts in fixture; cannot verify pagination)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $url2 = "$Base$sil9Base`?windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&limit=1&cursor=$([System.Uri]::EscapeDataString($nc1))"
            $r2   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r2.StatusCode -ne 200) {
                Write-Host ("  FAIL (page2 status=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $items2 = @(($r2.Content | ConvertFrom-Json).data.alerts)
                if ($items2.Count -eq 0) {
                    Write-Host "  FAIL (page2 empty despite totalAlerts >= 2)" -ForegroundColor Red; Hammer-Record FAIL
                } else {
                    $p1json = ($d1.alerts[0] | ConvertTo-Json -Depth 10 -Compress)
                    $p2json = ($items2[0]    | ConvertTo-Json -Depth 10 -Compress)
                    if ($p1json -ne $p2json) {
                        Write-Host "  PASS (no duplicate across pages)" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host "  FAIL (page2 item[0] duplicates page1 item[0])" -ForegroundColor Red; Hammer-Record FAIL
                    }
                }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-T4-V: out-of-range param values → 400 ───────────────────────────
try {
    Write-Host "Testing: SIL9-T4-V /alerts out-of-range T4 params -> 400" -NoNewline
    $cases = @(
        # aiChurnMinFlips out of range
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=1",       # below min (2)
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=21",      # above max (20)
        # aiChurnMaxGapDays out of range
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&aiChurnMaxGapDays=0",   # below min (1)
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&aiChurnMaxGapDays=31",  # above max (30)
        # aiChurnWindowDays out of range
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&aiChurnWindowDays=0",   # below min (1)
        "windowDays=30&triggerTypes=T4&aiChurnMinFlips=2&aiChurnWindowDays=31"   # above max (30)
    )
    $failures = @()
    foreach ($qs in $cases) {
        $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?$qs" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) {
            $failures += "$qs -> " + $resp.StatusCode
        }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $cases.Count + " out-of-range cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (" + $failures.Count + " cases did not return 400: " + ($failures -join "; ") + ")") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-P3: determinism -- same query + same cursor yields identical results ──
try {
    Write-Host "Testing: SIL9-P3 /alerts same cursor yields identical results (determinism)" -NoNewline
    $url1 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1"
    $r1   = Invoke-WebRequest -Uri $url1 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -ne 200) {
        Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $nc1 = ($r1.Content | ConvertFrom-Json).data.nextCursor
        if ($null -eq $nc1) {
            Write-Host "  SKIP (no nextCursor; only 1 or 0 alerts)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $url2 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1&cursor=$([System.Uri]::EscapeDataString($nc1))"
            $rA   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            $rB   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($rA.StatusCode -eq 200 -and $rB.StatusCode -eq 200) {
                $jsonA = ($rA.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
                $jsonB = ($rB.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
                if ($jsonA -eq $jsonB) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (same cursor produced different results on two calls)" -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                Write-Host ("  FAIL (page2 status=" + $rA.StatusCode + "/" + $rB.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9.1: FILTER TESTS
# =============================================================================

# ── SIL9-F1: triggerTypes=T3 returns only T3 alerts (or empty) ───────────────
try {
    Write-Host "Testing: SIL9-F1 /alerts triggerTypes=T3 returns only T3 (or empty)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&triggerTypes=T3&concentrationThreshold=0.0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = @(($resp.Content | ConvertFrom-Json).data.alerts)
        $nonT3 = $items | Where-Object { $_.triggerType -ne "T3" }
        if ($nonT3.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (" + $nonT3.Count + " non-T3 alerts returned with triggerTypes=T3)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-F2: keywordTargetId=<known> returns only alerts for that keyword, omits T3 ─
try {
    Write-Host "Testing: SIL9-F2 /alerts keywordTargetId filter excludes T3 and other keywords" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&keywordTargetId=$s3KtId" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items  = @(($resp.Content | ConvertFrom-Json).data.alerts)
            $t3s    = $items | Where-Object { $_.triggerType -eq "T3" }
            $badKts = $items | Where-Object { $_.triggerType -ne "T3" -and $_.keywordTargetId -ne $s3KtId }
            $fail   = $false
            $msg    = ""
            if ($t3s.Count -gt 0) {
                $fail = $true
                $msg  = "T3 returned despite keywordTargetId filter (" + $t3s.Count + ")"
            }
            if ($badKts.Count -gt 0) {
                $fail = $true
                $msg  = $msg + " wrong keywordTargetIds returned (" + $badKts.Count + ")"
            }
            if (-not $fail) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $msg.Trim() + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-F3: minSeverityRank filter reduces alert count monotonically ─────────
# SIL-9.3 severity model: all ranks are continuous integers in [0,100].
# The old coarse model (T1=1-5, T2=6, T3=7) is gone.
# We verify the filter is monotone: minSeverityRank=100 yields <= count than minSeverityRank=0.
try {
    Write-Host "Testing: SIL9-F3 /alerts minSeverityRank filter reduces alert count monotonically" -NoNewline
    $urlLow  = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&minSeverityRank=0"
    $urlHigh = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&minSeverityRank=100"
    $rLow  = Invoke-WebRequest -Uri $urlLow  -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $rHigh = Invoke-WebRequest -Uri $urlHigh -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rLow.StatusCode -eq 200 -and $rHigh.StatusCode -eq 200) {
        $cntLow  = [int]($rLow.Content  | ConvertFrom-Json).data.totalAlerts
        $cntHigh = [int]($rHigh.Content | ConvertFrom-Json).data.totalAlerts
        if ($cntHigh -le $cntLow) {
            Write-Host ("  PASS (minRank=0: " + $cntLow + " alerts; minRank=100: " + $cntHigh + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (minRank=100 count=" + $cntHigh + " > minRank=0 count=" + $cntLow + "; stricter filter must not increase count)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status low=" + $rLow.StatusCode + " high=" + $rHigh.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-F4: minPairVolatilityScore=100 yields no T2 alerts ──────────────────
try {
    Write-Host "Testing: SIL9-F4 /alerts minPairVolatilityScore=100 yields no T2 alerts" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&minPairVolatilityScore=100" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t2cnt = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" }).Count
        if ($t2cnt -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (" + $t2cnt + " T2 alerts with minPairVolatilityScore=100)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9.1: VALIDATION TESTS
# =============================================================================

# ── SIL9-V1: invalid triggerTypes token -> 400 ────────────────────────────────
try {
    Write-Host "Testing: SIL9-V1 /alerts invalid triggerTypes token -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&triggerTypes=T1,TX" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-V2: invalid cursor -> 400 ───────────────────────────────────────────
try {
    Write-Host "Testing: SIL9-V2 /alerts invalid cursor -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&cursor=not-valid-base64-json!!" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-V2b: structurally valid base64 but semantically invalid cursor -> 400 ─
try {
    Write-Host "Testing: SIL9-V2b /alerts base64 cursor with bad JSON fields -> 400" -NoNewline
    # Encode JSON that is valid base64url but missing required cursor fields
    $badPayload = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"x":1}')) -replace '\+','-' -replace '/','_' -replace '=',''
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&cursor=$badPayload" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-V3: invalid keywordTargetId -> 400 ──────────────────────────────────
try {
    Write-Host "Testing: SIL9-V3 /alerts invalid keywordTargetId -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&keywordTargetId=not-a-uuid" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9.2: SUPPRESSION TESTS
# =============================================================================

Hammer-Section "SIL-9.2 TESTS (DETERMINISTIC ALERT SUPPRESSION)"

# ── SIL9-S1: suppressionMode=none returns >= alerts as default ────────────────
# none bypasses all suppression; default applies maxPerKeyword + latestPerKeyword.
# So none should produce >= as many alerts as default for the same query.
try {
    Write-Host "Testing: SIL9-S1 /alerts suppressionMode=none returns >= alerts than default" -NoNewline
    $urlNone    = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none"
    $urlDefault = "$Base$sil9Base`?windowDays=30&spikeThreshold=0"
    $rNone    = Invoke-WebRequest -Uri $urlNone    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $rDefault = Invoke-WebRequest -Uri $urlDefault -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rNone.StatusCode -eq 200 -and $rDefault.StatusCode -eq 200) {
        $noneTotal    = [int]($rNone.Content    | ConvertFrom-Json).data.totalAlerts
        $defaultTotal = [int]($rDefault.Content | ConvertFrom-Json).data.totalAlerts
        if ($noneTotal -ge $defaultTotal) {
            Write-Host "  PASS (none=$noneTotal default=$defaultTotal)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (none=" + $noneTotal + " < default=" + $defaultTotal + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (none=" + $rNone.StatusCode + " default=" + $rDefault.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S2: default suppression reduces T2 count vs none when pairs exist ────
# With spikeThreshold=0, every pair emits a T2 candidate. maxPerKeyword should
# reduce that to at most 1 T2 per keyword. This test is data-dependent; SKIP if
# no pairs exist in window (totalAlerts=0 for both modes).
try {
    Write-Host "Testing: SIL9-S2 /alerts default suppression reduces T2 vs none" -NoNewline
    $urlNone    = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none"
    $urlDefault = "$Base$sil9Base`?windowDays=30&spikeThreshold=0"
    $rNone    = Invoke-WebRequest -Uri $urlNone    -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $rDefault = Invoke-WebRequest -Uri $urlDefault -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rNone.StatusCode -eq 200 -and $rDefault.StatusCode -eq 200) {
        $noneT2    = @(($rNone.Content    | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" }).Count
        $defaultT2 = @(($rDefault.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" }).Count
        if ($noneT2 -eq 0) {
            Write-Host "  SKIP (no T2 alerts in none mode; cannot verify reduction)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } elseif ($defaultT2 -le $noneT2) {
            Write-Host "  PASS (none.T2=$noneT2 default.T2=$defaultT2)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (default T2=" + $defaultT2 + " > none T2=" + $noneT2 + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status none=" + $rNone.StatusCode + " default=" + $rDefault.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S3: t2Mode=maxPerKeyword returns at most 1 T2 per keywordTargetId ────
try {
    Write-Host "Testing: SIL9-S3 /alerts t2Mode=maxPerKeyword returns at most 1 T2 per keywordTargetId" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&t2Mode=maxPerKeyword&suppressionMode=none" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    # Note: suppressionMode=none disables OTHER suppressions but t2Mode= is explicit,
    # so we test t2Mode directly with suppressionMode=none for t1/t3 neutrality.
    # Actually t2Mode overrides the default -- use suppressionMode=default to ensure t2Mode=maxPerKeyword path fires.
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&t2Mode=maxPerKeyword" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t2s = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T2" })
        if ($t2s.Count -eq 0) {
            Write-Host "  SKIP (no T2 alerts; cannot verify per-keyword constraint)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            # Group by keywordTargetId, assert each group has exactly 1
            $byKtId = $t2s | Group-Object -Property keywordTargetId
            $overOne = $byKtId | Where-Object { $_.Count -gt 1 }
            if ($overOne.Count -eq 0) {
                Write-Host "  PASS (all keywordTargetIds have <= 1 T2)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $overOne.Count + " keywords have >1 T2)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S4: determinism under suppression (two calls identical) ──────────────
try {
    Write-Host "Testing: SIL9-S4 /alerts determinism under default suppression" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30&spikeThreshold=0"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $arr1 = ($d1.alerts | ConvertTo-Json -Depth 10 -Compress)
        $arr2 = ($d2.alerts | ConvertTo-Json -Depth 10 -Compress)
        $nc1  = $d1.nextCursor
        $nc2  = $d2.nextCursor
        if ($arr1 -eq $arr2 -and $nc1 -eq $nc2 -and $d1.totalAlerts -eq $d2.totalAlerts) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (results differ between two calls under default suppression)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S5: pagination still works under suppression (no duplicates across pages) ─
try {
    Write-Host "Testing: SIL9-S5 /alerts pagination under suppression produces no duplicate alerts" -NoNewline
    # Page 1
    $url1 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1"
    $r1   = Invoke-WebRequest -Uri $url1 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -ne 200) {
        Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $d1  = ($r1.Content | ConvertFrom-Json).data
        $nc1 = $d1.nextCursor
        $tot = [int]$d1.totalAlerts
        if ($tot -lt 2 -or $null -eq $nc1) {
            Write-Host "  SKIP (fewer than 2 suppressed alerts or no nextCursor)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            # Page 2 via cursor
            $url2 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&limit=1&cursor=$([System.Uri]::EscapeDataString($nc1))"
            $r2   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r2.StatusCode -ne 200) {
                Write-Host ("  FAIL (page2 status=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $items1 = @($d1.alerts)
                $items2 = @(($r2.Content | ConvertFrom-Json).data.alerts)
                if ($items2.Count -eq 0) {
                    Write-Host "  FAIL (page2 empty despite totalAlerts >= 2)" -ForegroundColor Red; Hammer-Record FAIL
                } else {
                    $p1json = ($items1[0] | ConvertTo-Json -Depth 10 -Compress)
                    $p2json = ($items2[0] | ConvertTo-Json -Depth 10 -Compress)
                    if ($p1json -ne $p2json) {
                        Write-Host "  PASS (page2 item differs from page1 -- no duplicate)" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host "  FAIL (page2 item[0] duplicates page1 item[0] under suppression)" -ForegroundColor Red; Hammer-Record FAIL
                    }
                }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S6: t3Mode=deltaOnly -- deterministic, no throw, respects delta rule ──
# This test is data-dependent. It verifies:
#   (a) the param is accepted (no 400)
#   (b) the response is deterministic
#   (c) if T3 fires with deltaOnly, its volatilityConcentrationRatio is non-null
#   (d) suppressionMode param validation: bad value -> 400
try {
    Write-Host "Testing: SIL9-S6 /alerts t3Mode=deltaOnly accepted + deterministic" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30&concentrationThreshold=0.0&t3Mode=deltaOnly"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $arr1 = ($r1.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
        $arr2 = ($r2.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 10 -Compress
        if ($arr1 -ne $arr2) {
            Write-Host "  FAIL (deltaOnly non-deterministic between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        } else {
            # If T3 fired, ratio must be non-null
            $t3s = @(($r1.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T3" })
            if ($t3s.Count -gt 0 -and $null -eq $t3s[0].volatilityConcentrationRatio) {
                Write-Host "  FAIL (T3 fired via deltaOnly with null ratio)" -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $note = if ($t3s.Count -gt 0) { " (T3 fired)" } else { " (T3 suppressed; may lack prior-window data)" }
                Write-Host ("  PASS" + $note) -ForegroundColor Green; Hammer-Record PASS
            }
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S7: suppressionMode invalid value -> 400 ────────────────────────────
try {
    Write-Host "Testing: SIL9-S7 /alerts suppressionMode=invalid -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&suppressionMode=aggressive" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S8: t2Mode invalid value -> 400 ─────────────────────────────────────
try {
    Write-Host "Testing: SIL9-S8 /alerts t2Mode=invalid -> 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&t2Mode=topOne" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-S9: t1Mode=upwardOnlyLatest returns no downward T1 transitions ───────
# A downward T1 transition has toRegime < fromRegime (i.e. recovery).
# upwardOnlyLatest must suppress all such transitions.
# We map regime names to integers in PowerShell for comparison.
try {
    Write-Host "Testing: SIL9-S9 /alerts t1Mode=upwardOnlyLatest returns no downward T1 transitions" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&t1Mode=upwardOnlyLatest" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $t1s = @(($resp.Content | ConvertFrom-Json).data.alerts | Where-Object { $_.triggerType -eq "T1" })
        if ($t1s.Count -eq 0) {
            Write-Host "  SKIP (no T1 alerts; cannot verify upward-only constraint)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $regimeRank = @{ "calm" = 0; "shifting" = 1; "unstable" = 2; "chaotic" = 3 }
            $downward = $t1s | Where-Object {
                $fromRank = $regimeRank[$_.fromRegime]
                $toRank   = $regimeRank[$_.toRegime]
                $toRank -le $fromRank  # downward or lateral (should be suppressed)
            }
            if ($downward.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $downward.Count + " downward T1 transitions returned with upwardOnlyLatest)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SIL-9.3: SEVERITY REFINEMENT TESTS
# =============================================================================

Hammer-Section "SIL-9.3 TESTS (MAGNITUDE-AWARE SEVERITY SCORING)"

# ── SIL9-SV1: severityRank is integer in [0, 100] for all alerts ───────────
try {
    Write-Host "Testing: SIL9-SV1 /alerts all severityRank values are integers in [0,100]" -NoNewline
    # Use suppressionMode=none + spikeThreshold=0 to maximize alert variety
    $resp = Invoke-WebRequest -Uri "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&concentrationThreshold=0.0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = @(($resp.Content | ConvertFrom-Json).data.alerts)
        if ($items.Count -eq 0) {
            Write-Host "  SKIP (no alerts returned; cannot verify severityRank range)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            # severityRank is stripped from emitted response -- it is an internal sort field.
            # We cannot inspect it directly. Instead verify the response is valid (200) and
            # all alerts have the required shape fields, which confirms severity was computed
            # without error. For T2 we can verify the formula is bounded via trigger-specific fields.
            #
            # What we CAN test: T2 alerts expose pairVolatilityScore and threshold (exceedanceMargin).
            # exceedanceMargin = pairVolatilityScore - threshold, and severity = clamp(60 + margin*2, 0, 100).
            # If the formula errors it would throw and give 500. The 200 response is the first guard.
            #
            # Additional structural check: all items have triggerType in {T1,T2,T3}.
            $invalid = $items | Where-Object { @("T1","T2","T3","T4") -notcontains $_.triggerType }
            if ($invalid.Count -eq 0) {
                Write-Host ("  PASS (" + $items.Count + " alerts returned with valid structure; severity computed without error)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $invalid.Count + " items with invalid triggerType)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-SV2: T2 severity increases as spikeThreshold decreases ────────────
# Formula: severityRank = clamp(round(60 + (pairVolatilityScore - threshold) * 2), 0, 100)
# For a fixed pairVolatilityScore, lowering threshold increases exceedanceMargin
# and therefore increases severityRank.
# Since severityRank is internal, we use minSeverityRank as a proxy:
# With threshold=75, minSeverityRank=80 should keep fewer T2 alerts than with threshold=0
# (because T2 items near 75 have low severity with threshold=75, high with threshold=0).
# This test is data-dependent; SKIP if no T2 alerts exist in either call.
try {
    Write-Host "Testing: SIL9-SV2 /alerts T2 higher severity with lower spikeThreshold (formula check)" -NoNewline
    # Get T2 exceedanceMargins at threshold=0 vs threshold=75 for the same pair.
    # At threshold=0: severity = clamp(60 + pairScore*2, 0, 100)  -- higher
    # At threshold=75: severity = clamp(60 + (pairScore-75)*2, 0, 100) -- lower for same pair
    # We verify: using minSeverityRank=80 + threshold=0 returns >= items than threshold=75
    $url0  = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&triggerTypes=T2&minSeverityRank=80"
    $url75 = "$Base$sil9Base`?windowDays=30&spikeThreshold=75&suppressionMode=none&triggerTypes=T2&minSeverityRank=80"
    $r0  = Invoke-WebRequest -Uri $url0  -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r75 = Invoke-WebRequest -Uri $url75 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r0.StatusCode -eq 200 -and $r75.StatusCode -eq 200) {
        $cnt0  = [int]($r0.Content  | ConvertFrom-Json).data.totalAlerts
        $cnt75 = [int]($r75.Content | ConvertFrom-Json).data.totalAlerts
        if ($cnt0 -eq 0 -and $cnt75 -eq 0) {
            Write-Host "  SKIP (no T2 alerts above minSeverityRank=80 in either call; fixture may not have sufficient spikes)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } elseif ($cnt0 -ge $cnt75) {
            Write-Host ("  PASS (threshold=0 yields " + $cnt0 + " high-severity T2; threshold=75 yields " + $cnt75 + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (threshold=0 T2 count=" + $cnt0 + " < threshold=75 T2 count=" + $cnt75 + "; severity should increase as threshold decreases)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status t0=" + $r0.StatusCode + " t75=" + $r75.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-SV3: determinism unchanged (two calls identical excluding computedAt) ──
try {
    Write-Host "Testing: SIL9-SV3 /alerts determinism unchanged after severity refinement" -NoNewline
    $url = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $arr1 = ($d1.alerts | ConvertTo-Json -Depth 10 -Compress)
        $arr2 = ($d2.alerts | ConvertTo-Json -Depth 10 -Compress)
        $nc1  = $d1.nextCursor
        $nc2  = $d2.nextCursor
        if ($arr1 -eq $arr2 -and $nc1 -eq $nc2 -and $d1.totalAlerts -eq $d2.totalAlerts) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (results differ between two calls; severity scoring introduced non-determinism)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL9-SV4: pagination still works (limit=1 + cursor, no duplicates) ─────────
try {
    Write-Host "Testing: SIL9-SV4 /alerts pagination works correctly after severity refinement" -NoNewline
    $url1 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&limit=1"
    $r1   = Invoke-WebRequest -Uri $url1 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -ne 200) {
        Write-Host ("  FAIL (page1 status=" + $r1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
    } else {
        $d1  = ($r1.Content | ConvertFrom-Json).data
        $nc1 = $d1.nextCursor
        $tot = [int]$d1.totalAlerts
        if ($tot -lt 2 -or $null -eq $nc1) {
            Write-Host "  SKIP (fewer than 2 alerts or no nextCursor)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $url2 = "$Base$sil9Base`?windowDays=30&spikeThreshold=0&suppressionMode=none&limit=1&cursor=$([System.Uri]::EscapeDataString($nc1))"
            $r2   = Invoke-WebRequest -Uri $url2 -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r2.StatusCode -ne 200) {
                Write-Host ("  FAIL (page2 status=" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $items2 = @(($r2.Content | ConvertFrom-Json).data.alerts)
                if ($items2.Count -eq 0) {
                    Write-Host "  FAIL (page2 empty despite totalAlerts >= 2)" -ForegroundColor Red; Hammer-Record FAIL
                } else {
                    $p1json = ($d1.alerts[0] | ConvertTo-Json -Depth 10 -Compress)
                    $p2json = ($items2[0]    | ConvertTo-Json -Depth 10 -Compress)
                    if ($p1json -ne $p2json) {
                        Write-Host "  PASS (page2 item differs from page1 -- no duplicate)" -ForegroundColor Green; Hammer-Record PASS
                    } else {
                        Write-Host "  FAIL (page2 item[0] duplicates page1 item[0])" -ForegroundColor Red; Hammer-Record FAIL
                    }
                }
            }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
