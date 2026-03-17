# hammer-sil11-briefing.ps1 -- Operator Briefing Packet
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/operator-briefing
#
# Response shape:
#   projectId, windowDays, alertThreshold,
#   summary{keywordCount,activeKeywordCount,averageVolatility,maxVolatility,
#           alertKeywordCount,alertRatio,alertThreshold,
#           weightedProjectVolatilityScore,volatilityConcentrationRatio},
#   topAlerts[], riskAttributionSummary{rankShare,aiShare,featureShare}|null,
#   operatorReasoning{observations[],hypotheses[],recommendedActions[]},
#   deltas[],
#   promptText (string)
#
# Determinism rule: requestTime is floored to the current minute in the route,
# so two calls within the same minute are identical. Tests account for this.

Hammer-Section "SIL-11 BRIEFING TESTS (OPERATOR BRIEFING PACKET)"

$silBBase = "/api/seo/operator-briefing"

# ── SILB-A: 400 on invalid params ────────────────────────────────────────────
try {
    Write-Host "Testing: SILB-A 400 on invalid / unknown params" -NoNewline
    $cases = @(
        "windowDays=0",
        "windowDays=366",
        "windowDays=abc",
        "alertThreshold=-1",
        "alertThreshold=101",
        "alertThreshold=xyz",
        "limitAlerts=0",
        "limitAlerts=201",
        "limitAlerts=abc",
        "limitDeltas=-1",
        "limitDeltas=201",
        "limitDeltas=abc",
        "unknownParam=true",
        "windowDays=30&bogus=1"
    )
    $failures = @()
    foreach ($qs in $cases) {
        $resp = Invoke-WebRequest -Uri "$Base$silBBase`?$qs" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) {
            $failures += "$qs -> $($resp.StatusCode)"
        }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $cases.Count + " invalid cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (" + $failures.Count + " cases did not return 400: " + ($failures -join "; ") + ")") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-B: 200 + required top-level fields ───────────────────────────────────
try {
    Write-Host "Testing: SILB-B 200 + required top-level fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60&alertThreshold=60&limitAlerts=50&limitDeltas=0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d     = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("projectId","windowDays","alertThreshold","summary",
                      "topAlerts","riskAttributionSummary","operatorReasoning","deltas","promptText")
        $missing = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-C: summary sub-fields present ───────────────────────────────────────
try {
    Write-Host "Testing: SILB-C summary contains required sub-fields" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $s    = ($resp.Content | ConvertFrom-Json).data.summary
        $props = $s | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $req  = @("keywordCount","activeKeywordCount","averageVolatility","maxVolatility",
                  "alertKeywordCount","alertRatio","alertThreshold",
                  "weightedProjectVolatilityScore","volatilityConcentrationRatio")
        $miss = $req | Where-Object { $props -notcontains $_ }
        if ($miss.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing summary fields: " + ($miss -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-D: operatorReasoning sub-fields present ──────────────────────────────
try {
    Write-Host "Testing: SILB-D operatorReasoning has observations/hypotheses/recommendedActions" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $or   = ($resp.Content | ConvertFrom-Json).data.operatorReasoning
        $props = $or | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $req  = @("observations","hypotheses","recommendedActions")
        $miss = $req | Where-Object { $props -notcontains $_ }
        if ($miss.Count -eq 0) {
            Write-Host ("  PASS") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($miss -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-E: deltas is always an array (even when limitDeltas=0) ───────────────
try {
    Write-Host "Testing: SILB-E deltas field is always an array regardless of limitDeltas" -NoNewline
    $cases = @("limitDeltas=0", "limitDeltas=5")
    $failures = @()
    foreach ($qs in $cases) {
        $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60&$qs" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 200) { $failures += "$qs -> HTTP $($resp.StatusCode)"; continue }
        $deltas = ($resp.Content | ConvertFrom-Json).data.deltas
        # Null is not acceptable; must be an array (possibly empty)
        if ($null -eq $deltas) { $failures += "$qs -> deltas is null" }
    }
    if ($failures.Count -eq 0) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-F: promptText is a non-empty string ─────────────────────────────────
try {
    Write-Host "Testing: SILB-F promptText is a non-empty string" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $pt = ($resp.Content | ConvertFrom-Json).data.promptText
        if ($null -ne $pt -and [string]$pt -ne "") {
            Write-Host ("  PASS (length=" + ([string]$pt).Length + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (promptText is null or empty)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-G: promptText contains required sections ────────────────────────────
try {
    Write-Host "Testing: SILB-G promptText contains all required section headers" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $pt  = [string](($resp.Content | ConvertFrom-Json).data.promptText)
        $req = @(
            "SYSTEM RULES (NO MUTATIONS)",
            "PROJECT SUMMARY",
            "TOP ALERTS",
            "OPERATOR REASONING (SIL-11)",
            "TASK FOR CLAUDE"
        )
        $missing = $req | Where-Object { $pt -notmatch [regex]::Escape($_) }
        if ($missing.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing sections: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-H: promptText must NOT contain computedAt or "generated at" ─────────
try {
    Write-Host "Testing: SILB-H promptText does not contain computedAt or 'generated at'" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $pt     = [string](($resp.Content | ConvertFrom-Json).data.promptText)
        $banned = @("computedAt", "generated at", "Generated at", "Generated At")
        $found  = $banned | Where-Object { $pt -match [regex]::Escape($_) }
        if ($found.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (promptText contains banned strings: " + ($found -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-I: promptText instructs LLM to return proposals only ────────────────
try {
    Write-Host "Testing: SILB-I promptText contains proposal-only instruction and no-mutation constraint" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $pt       = [string](($resp.Content | ConvertFrom-Json).data.promptText)
        $mustHave = @("proposal", "NO MUTATIONS", "MUST NOT", "JSON")
        $missing  = $mustHave | Where-Object { $pt -notmatch [regex]::Escape($_) }
        if ($missing.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (promptText missing required strings: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-J: determinism (two sequential calls within same minute are identical) ─
try {
    Write-Host "Testing: SILB-J determinism (two sequential calls yield identical response)" -NoNewline
    $url = "$Base$silBBase`?windowDays=60&alertThreshold=60&limitAlerts=50&limitDeltas=0"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        # Compare structural fields that must be identical
        $pt1   = [string]$d1.promptText
        $pt2   = [string]$d2.promptText
        $sum1  = $d1.summary | ConvertTo-Json -Compress
        $sum2  = $d2.summary | ConvertTo-Json -Compress
        $or1   = $d1.operatorReasoning | ConvertTo-Json -Depth 10 -Compress
        $or2   = $d2.operatorReasoning | ConvertTo-Json -Depth 10 -Compress
        $ta1   = $d1.topAlerts | ConvertTo-Json -Depth 10 -Compress
        $ta2   = $d2.topAlerts | ConvertTo-Json -Depth 10 -Compress
        if ($pt1 -eq $pt2 -and $sum1 -eq $sum2 -and $or1 -eq $or2 -and $ta1 -eq $ta2) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $diffFields = @()
            if ($pt1  -ne $pt2)  { $diffFields += "promptText" }
            if ($sum1 -ne $sum2) { $diffFields += "summary" }
            if ($or1  -ne $or2)  { $diffFields += "operatorReasoning" }
            if ($ta1  -ne $ta2)  { $diffFields += "topAlerts" }
            Write-Host ("  FAIL (differs: " + ($diffFields -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-K: isolation (OtherHeaders -> different projectId or 404) ────────────
try {
    Write-Host "Testing: SILB-K cross-project isolation" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url       = "$Base$silBBase`?windowDays=60"
        $respMain  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers      -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $respOther = Invoke-WebRequest -Uri $url -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($respOther.StatusCode -eq 404) {
            Write-Host "  PASS (other project 404 -- isolation enforced)" -ForegroundColor Green; Hammer-Record PASS
        } elseif ($respMain.StatusCode -eq 200 -and $respOther.StatusCode -eq 200) {
            $mainPid  = ($respMain.Content  | ConvertFrom-Json).data.projectId
            $otherPid = ($respOther.Content | ConvertFrom-Json).data.projectId
            if ($mainPid -ne $otherPid) {
                Write-Host ("  PASS (projectId differs: main=$mainPid other=$otherPid)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (both returned same projectId=$mainPid -- isolation may be broken)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (main=" + $respMain.StatusCode + " other=" + $respOther.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-L: limitAlerts respected (topAlerts.Count <= limitAlerts) ────────────
try {
    Write-Host "Testing: SILB-L limitAlerts param respected" -NoNewline
    $testLimit = 3
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60&limitAlerts=$testLimit" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $count = @(($resp.Content | ConvertFrom-Json).data.topAlerts).Count
        if ($count -le $testLimit) {
            Write-Host ("  PASS (topAlerts.Count=$count <= limitAlerts=$testLimit)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (topAlerts.Count=$count exceeds limitAlerts=$testLimit)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-M: limitDeltas=0 means deltas is empty array ────────────────────────
try {
    Write-Host "Testing: SILB-M limitDeltas=0 returns empty deltas array" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60&limitDeltas=0" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $count = @(($resp.Content | ConvertFrom-Json).data.deltas).Count
        if ($count -eq 0) {
            Write-Host "  PASS (deltas=[]) " -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (deltas.Count=$count, expected 0 when limitDeltas=0)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-N: topAlerts sorted volatilityScore DESC ────────────────────────────
try {
    Write-Host "Testing: SILB-N topAlerts sorted volatilityScore DESC" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase`?windowDays=60&limitAlerts=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $alerts = @(($resp.Content | ConvertFrom-Json).data.topAlerts)
        if ($alerts.Count -lt 2) {
            Write-Host ("  SKIP (fewer than 2 alerts; cannot verify sort)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $fail = $false; $failMsg = ""
            for ($i = 0; $i -lt ($alerts.Count - 1); $i++) {
                $a = [double]$alerts[$i].volatilityScore
                $b = [double]$alerts[$i + 1].volatilityScore
                if ($a -lt $b) {
                    $fail = $true
                    $failMsg = "alerts[$i].score=$a < alerts[$($i+1)].score=$b (must be DESC)"
                    break
                }
            }
            if (-not $fail) {
                Write-Host ("  PASS (" + $alerts.Count + " alerts in DESC order)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SILB-O: POST returns 405 / 404 (no write surface) ────────────────────────
try {
    Write-Host "Testing: SILB-O POST rejected (no mutation surface)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$silBBase" `
        -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 405 -or $resp.StatusCode -eq 404) {
        Write-Host ("  PASS (POST returned " + $resp.StatusCode + ")") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (POST returned " + $resp.StatusCode + ", expected 405 or 404)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
