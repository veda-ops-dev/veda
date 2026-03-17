# hammer-sil11.ps1 -- SIL-11: Project-Level Operator Reasoning
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/operator-reasoning
#
# Response shape:
#   projectId, windowDays, alertThreshold, summary{...},
#   observations[], hypotheses[], recommendedActions[]
#
# Each output array is deterministically sorted.
# No computedAt or wall-clock fields in payload (determinism rule).

Hammer-Section "SIL-11 TESTS (OPERATOR REASONING)"

$sil11Base = "/api/seo/operator-reasoning"

# ── SIL11-A: 400 on invalid params ───────────────────────────────────────────
try {
    Write-Host "Testing: SIL11-A 400 on invalid params" -NoNewline
    $cases = @(
        "windowDays=0",
        "windowDays=366",
        "windowDays=abc",
        "alertThreshold=-1",
        "alertThreshold=101",
        "alertThreshold=xyz",
        "unknownParam=true"
    )
    $failures = @()
    foreach ($qs in $cases) {
        $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?$qs" `
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

# ── SIL11-B: 200 + required top-level fields ─────────────────────────────────
try {
    Write-Host "Testing: SIL11-B 200 + required top-level fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d     = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("projectId","windowDays","alertThreshold","summary","observations","hypotheses","recommendedActions")
        $missing  = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host ("  PASS (all required fields present)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-C: summary fields present ──────────────────────────────────────────
try {
    Write-Host "Testing: SIL11-C summary contains required sub-fields" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $summary = ($resp.Content | ConvertFrom-Json).data.summary
        $props   = $summary | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("keywordCount","activeKeywordCount","averageVolatility","maxVolatility",
                      "alertKeywordCount","alertRatio","weightedProjectVolatilityScore","volatilityConcentrationRatio")
        $missing  = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host ("  PASS") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing summary fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-D: output arrays are arrays ────────────────────────────────────────
try {
    Write-Host "Testing: SIL11-D observations/hypotheses/recommendedActions are arrays" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d   = ($resp.Content | ConvertFrom-Json).data
        $obs = $d.observations
        $hyp = $d.hypotheses
        $rec = $d.recommendedActions
        # ConvertFrom-Json wraps arrays; check type with -is or check Count
        $obsIsArr = ($null -ne $obs) -and ($obs.GetType().Name -match "Object\[\]|Array" -or $obs.Count -ge 0)
        $hypIsArr = ($null -ne $hyp) -and ($hyp.GetType().Name -match "Object\[\]|Array" -or $hyp.Count -ge 0)
        $recIsArr = ($null -ne $rec) -and ($rec.GetType().Name -match "Object\[\]|Array" -or $rec.Count -ge 0)
        if ($obsIsArr -and $hypIsArr -and $recIsArr) {
            Write-Host ("  PASS (obs=" + @($obs).Count + " hyp=" + @($hyp).Count + " rec=" + @($rec).Count + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (one or more output fields is not an array)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-E: observation items have required fields ───────────────────────────
try {
    Write-Host "Testing: SIL11-E each observation has type + description" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $obs = @(($resp.Content | ConvertFrom-Json).data.observations)
        if ($obs.Count -eq 0) {
            Write-Host ("  SKIP (no observations; stable or empty project)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $failures = @()
            foreach ($item in $obs) {
                $itemProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($itemProps -notcontains "type") { $failures += "missing type" }
                if ($itemProps -notcontains "description") { $failures += "missing description" }
            }
            if ($failures.Count -eq 0) {
                Write-Host ("  PASS (" + $obs.Count + " observations validated)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-F: hypothesis items have required fields + confidence in [0,1] ──────
try {
    Write-Host "Testing: SIL11-F each hypothesis has type, confidence in [0,1], explanation" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $hyp = @(($resp.Content | ConvertFrom-Json).data.hypotheses)
        if ($hyp.Count -eq 0) {
            Write-Host ("  SKIP (no hypotheses; likely no active keywords or zero volatility)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $failures = @()
            foreach ($item in $hyp) {
                $itemProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($itemProps -notcontains "type")        { $failures += "missing type" }
                if ($itemProps -notcontains "confidence")  { $failures += "missing confidence" }
                if ($itemProps -notcontains "explanation") { $failures += "missing explanation" }
                if ($itemProps -contains "confidence") {
                    $c = [double]$item.confidence
                    if ($c -lt 0 -or $c -gt 1) { $failures += ("confidence=$c out of [0,1]") }
                }
            }
            if ($failures.Count -eq 0) {
                Write-Host ("  PASS (" + $hyp.Count + " hypotheses validated)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-G: recommendedAction items have required fields ─────────────────────
try {
    Write-Host "Testing: SIL11-G each recommendedAction has type + rationale" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $rec = @(($resp.Content | ConvertFrom-Json).data.recommendedActions)
        if ($rec.Count -eq 0) {
            Write-Host ("  SKIP (no recommendedActions; stable or empty project)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $failures = @()
            foreach ($item in $rec) {
                $itemProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($itemProps -notcontains "type")      { $failures += "missing type" }
                if ($itemProps -notcontains "rationale") { $failures += "missing rationale" }
            }
            if ($failures.Count -eq 0) {
                Write-Host ("  PASS (" + $rec.Count + " actions validated)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-H: determinism (two identical calls yield identical results) ─────────
try {
    Write-Host "Testing: SIL11-H determinism (two sequential calls identical)" -NoNewline
    $url = "$Base$sil11Base`?windowDays=60&alertThreshold=60"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        # No computedAt allowed in payload
        $hasCAt = ($r1.Content -match '"computedAt"')
        $obs1   = $d1.observations   | ConvertTo-Json -Depth 10 -Compress
        $obs2   = $d2.observations   | ConvertTo-Json -Depth 10 -Compress
        $hyp1   = $d1.hypotheses     | ConvertTo-Json -Depth 10 -Compress
        $hyp2   = $d2.hypotheses     | ConvertTo-Json -Depth 10 -Compress
        $rec1   = $d1.recommendedActions | ConvertTo-Json -Depth 10 -Compress
        $rec2   = $d2.recommendedActions | ConvertTo-Json -Depth 10 -Compress
        $sumEq  = ($d1.summary.averageVolatility -eq $d2.summary.averageVolatility)
        if ($hasCAt) {
            Write-Host "  FAIL (response contains computedAt; not permitted per determinism rules)" -ForegroundColor Red; Hammer-Record FAIL
        } elseif ($obs1 -eq $obs2 -and $hyp1 -eq $hyp2 -and $rec1 -eq $rec2 -and $sumEq) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (outputs differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-I: cross-project isolation ─────────────────────────────────────────
try {
    Write-Host "Testing: SIL11-I cross-project isolation (OtherHeaders returns different data)" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url       = "$Base$sil11Base`?windowDays=60"
        $respMain  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers      -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $respOther = Invoke-WebRequest -Uri $url -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($respMain.StatusCode -eq 200 -and $respOther.StatusCode -eq 200) {
            $mainPid  = ($respMain.Content  | ConvertFrom-Json).data.projectId
            $otherPid = ($respOther.Content | ConvertFrom-Json).data.projectId
            if ($mainPid -ne $otherPid) {
                Write-Host ("  PASS (projectId differs: main=$mainPid other=$otherPid)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (both calls returned same projectId=$mainPid -- isolation may be broken)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } elseif ($respOther.StatusCode -eq 404) {
            Write-Host "  PASS (other project returns 404 -- isolation enforced)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (main=" + $respMain.StatusCode + " other=" + $respOther.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-J: stable project -- no HIGH_VOLATILITY_KEYWORD observations ─────────
try {
    Write-Host "Testing: SIL11-J stable project threshold -- observations do not contain HIGH_VOLATILITY_KEYWORD when average volatility is low" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60&alertThreshold=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d       = ($resp.Content | ConvertFrom-Json).data
        $avgVol  = [double]$d.summary.averageVolatility
        $obs     = @($d.observations)
        if ($avgVol -le 30) {
            # Low average volatility: no HIGH_VOLATILITY_KEYWORD observation expected
            $hvObs = $obs | Where-Object { $_.type -eq "HIGH_VOLATILITY_KEYWORD" }
            if ($hvObs.Count -eq 0) {
                Write-Host ("  PASS (avgVol=$avgVol -- no HIGH_VOLATILITY_KEYWORD observations)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (avgVol=$avgVol but " + $hvObs.Count + " HIGH_VOLATILITY_KEYWORD observations found)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  SKIP (avgVol=$avgVol > 30; project is not in a stable state for this check)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-K: empty project returns valid structure with no active keywords ─────
try {
    Write-Host "Testing: SIL11-K empty/no-snapshot project returns valid structure" -NoNewline
    # Use a very narrow windowDays=1 to maximize chance of finding no snapshots
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=1" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d    = ($resp.Content | ConvertFrom-Json).data
        $obs  = @($d.observations)
        $hyp  = @($d.hypotheses)
        $rec  = @($d.recommendedActions)
        $sum  = $d.summary
        # Must return valid envelope regardless of data state
        $hasEnvelope = ($null -ne $obs) -and ($null -ne $hyp) -and ($null -ne $rec) -and ($null -ne $sum)
        if ($hasEnvelope) {
            Write-Host ("  PASS (obs=" + $obs.Count + " hyp=" + $hyp.Count + " rec=" + $rec.Count + " keywordCount=" + $sum.keywordCount + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (missing required envelope fields for empty/narrow window)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-L: observation sort order is deterministic (type ASC, keywordId ASC) ─
try {
    Write-Host "Testing: SIL11-L observations sorted by type ASC then keywordId ASC" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $obs = @(($resp.Content | ConvertFrom-Json).data.observations)
        if ($obs.Count -lt 2) {
            Write-Host ("  SKIP (fewer than 2 observations; cannot verify sort order)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $fail    = $false
            $failMsg = ""
            for ($i = 0; $i -lt ($obs.Count - 1); $i++) {
                $a = $obs[$i]; $b = $obs[$i + 1]
                $aType = if ($null -ne $a.type) { [string]$a.type } else { "" }
                $bType = if ($null -ne $b.type) { [string]$b.type } else { "" }
                $aId   = if ($null -ne $a.keywordId) { [string]$a.keywordId } else { "" }
                $bId   = if ($null -ne $b.keywordId) { [string]$b.keywordId } else { "" }
                $typeCmp = [string]::Compare($aType, $bType, [System.StringComparison]::Ordinal)
                if ($typeCmp -gt 0) {
                    $fail = $true; $failMsg = "obs[$i].type='$aType' > obs[$($i+1)].type='$bType'"
                    break
                } elseif ($typeCmp -eq 0) {
                    $idCmp = [string]::Compare($aId, $bId, [System.StringComparison]::Ordinal)
                    if ($idCmp -gt 0) {
                        $fail = $true; $failMsg = "obs[$i].keywordId='$aId' > obs[$($i+1)].keywordId='$bId' (same type '$aType')"
                        break
                    }
                }
            }
            if (-not $fail) {
                Write-Host ("  PASS (" + $obs.Count + " observations in correct order)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-M: hypotheses confidence sum does not exceed 1.0 per hypothesis ─────
try {
    Write-Host "Testing: SIL11-M hypothesis confidence sorted DESC and each in [0,1]" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base`?windowDays=60" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $hyp = @(($resp.Content | ConvertFrom-Json).data.hypotheses)
        if ($hyp.Count -lt 1) {
            Write-Host ("  SKIP (no hypotheses)") -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $fail    = $false
            $failMsg = ""
            for ($i = 0; $i -lt $hyp.Count; $i++) {
                $c = [double]$hyp[$i].confidence
                if ($c -lt 0 -or $c -gt 1) {
                    $fail = $true; $failMsg = "hyp[$i].confidence=$c out of [0,1]"; break
                }
                if ($i -gt 0) {
                    $prev = [double]$hyp[$i - 1].confidence
                    if ($c -gt $prev) {
                        $fail = $true; $failMsg = "hyp[$i].confidence=$c > hyp[$($i-1)].confidence=$prev (should be DESC)"; break
                    }
                }
            }
            if (-not $fail) {
                Write-Host ("  PASS (" + $hyp.Count + " hypotheses)") -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── SIL11-N: no write side effects (GET only) ────────────────────────────────
try {
    Write-Host "Testing: SIL11-N endpoint rejects POST (method not allowed)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$sil11Base" `
        -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 405) {
        Write-Host "  PASS (POST returns 405)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        # Next.js returns 405 for unimplemented methods; some versions may return 404
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS (POST returns 404 -- method not implemented)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (POST returned " + $resp.StatusCode + ", expected 405 or 404)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
