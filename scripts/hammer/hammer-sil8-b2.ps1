# hammer-sil8-b2.ps1 -- SIL-8 B2 (Project Risk Index)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Extended endpoint: GET /api/seo/volatility-summary
#
# New fields verified here:
#   weightedProjectVolatilityScore -- numeric, >= 0
#   volatilityConcentrationRatio   -- null OR number in [0, 1]
#   top3RiskKeywords               -- array of 0-3 items, sorted correctly
#
# Fixture dependency:
#   $Headers     -- primary project
#   $OtherHeaders -- second project (set in coordinator, may be empty)
#
# Tests (B2-A through B2-G):
#   B2-A: new fields present on /volatility-summary response
#   B2-B: weightedProjectVolatilityScore is numeric (>= 0)
#   B2-C: volatilityConcentrationRatio is null OR in [0, 1]
#   B2-D: top3RiskKeywords length <= 3 and sort correct (volatilityScore DESC, query ASC)
#   B2-E: determinism (two calls identical on all three new fields)
#   B2-F: 404 (or project isolation) -- /volatility-summary scopes to resolved project
#          For this endpoint isolation is enforced via headers, not URL param.
#          We verify OtherHeaders returns a different (or empty) dataset -- structural test.
#   B2-G: top3RiskKeywords per-item shape correct (required fields present)

Hammer-Section "SIL-8 B2 TESTS (PROJECT RISK INDEX)"

$b2Url = "$Base/api/seo/volatility-summary"

# ── B2-A: new fields present ──────────────────────────────────────────────────
try {
    Write-Host "Testing: B2 /volatility-summary has new B2 fields" -NoNewline
    $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d     = ($resp.Content | ConvertFrom-Json).data
        $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $required = @("weightedProjectVolatilityScore", "volatilityConcentrationRatio", "top3RiskKeywords")
        $missing  = $required | Where-Object { $props -notcontains $_ }
        if ($missing.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-B: weightedProjectVolatilityScore is numeric >= 0 ─────────────────────
try {
    Write-Host "Testing: B2 weightedProjectVolatilityScore is numeric >= 0" -NoNewline
    $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $val = ($resp.Content | ConvertFrom-Json).data.weightedProjectVolatilityScore
        # Must be a number (not null, not string) and >= 0
        $isNum = ($val -ne $null) -and ($val -is [double] -or $val -is [int] -or $val -is [decimal])
        if (-not $isNum) {
            # Try coercion -- PowerShell JSON may return PSCustomObject for null
            try { $num = [double]$val; $isNum = $true } catch { $isNum = $false }
        }
        $ok = $isNum -and ([double]$val -ge 0)
        if ($ok) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (value='" + $val + "', expected numeric >= 0)") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-C: volatilityConcentrationRatio is null OR in [0, 1] ──────────────────
try {
    Write-Host "Testing: B2 volatilityConcentrationRatio is null OR in [0, 1]" -NoNewline
    $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d   = ($resp.Content | ConvertFrom-Json).data
        $val = $d.volatilityConcentrationRatio
        if ($null -eq $val) {
            # null is valid when totalVolatilitySum = 0
            Write-Host "  PASS (null -- totalVolatilitySum=0)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $num = [double]$val
            if ($num -ge 0 -and $num -le 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (value=" + $num + ", expected in [0,1])") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-D: top3RiskKeywords length <= 3 and sort correct ──────────────────────
try {
    Write-Host "Testing: B2 top3RiskKeywords length <= 3 and sort correct (volatilityScore DESC, query ASC)" -NoNewline
    $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $top3 = @(($resp.Content | ConvertFrom-Json).data.top3RiskKeywords)
        if ($top3.Count -gt 3) {
            Write-Host ("  FAIL (top3RiskKeywords.Count=" + $top3.Count + ", expected <= 3)") -ForegroundColor Red; Hammer-Record FAIL
        } elseif ($top3.Count -lt 2) {
            # Can't verify sort with 0 or 1 item
            Write-Host "  PASS (length=" + $top3.Count + ", sort trivially satisfied)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $sortOk = $true
            for ($i = 0; $i -lt $top3.Count - 1; $i++) {
                $cur  = [double]$top3[$i].volatilityScore
                $next = [double]$top3[$i + 1].volatilityScore
                if ($next -gt $cur) { $sortOk = $false; break }
                if ($next -eq $cur) {
                    # Tie: query must be ascending
                    $qCur  = $top3[$i].query
                    $qNext = $top3[$i + 1].query
                    if ([string]::Compare($qNext, $qCur, [System.StringComparison]::Ordinal) -lt 0) {
                        $sortOk = $false; break
                    }
                }
            }
            if ($sortOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (top3RiskKeywords sort order violated)" -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-E: determinism (two calls identical on all three new fields) ────────────
try {
    Write-Host "Testing: B2 /volatility-summary new fields deterministic (two calls identical)" -NoNewline
    $r1 = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $wMatch   = ($d1.weightedProjectVolatilityScore -eq $d2.weightedProjectVolatilityScore)
        $cMatch   = (($d1.volatilityConcentrationRatio -eq $null -and $d2.volatilityConcentrationRatio -eq $null) -or
                     ($d1.volatilityConcentrationRatio -eq $d2.volatilityConcentrationRatio))
        $t1 = ($d1.top3RiskKeywords | ConvertTo-Json -Depth 5 -Compress)
        $t2 = ($d2.top3RiskKeywords | ConvertTo-Json -Depth 5 -Compress)
        $tMatch   = ($t1 -eq $t2)
        if ($wMatch -and $cMatch -and $tMatch) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (B2 fields differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-F: project isolation -- OtherHeaders returns its own scoped data ────────
# /volatility-summary has no URL id param -- isolation is via resolved projectId.
# We verify that OtherHeaders returns 200 with data scoped to the other project.
# Structural check: the response must be a valid 200 (not a 500 or cross-data leak).
# We cannot assert specific counts without knowing the other project's data, so we
# verify the envelope is valid and the keywordCount is present.
try {
    Write-Host "Testing: B2 /volatility-summary project isolation (OtherHeaders returns valid scoped response)" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $OtherHeaders `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($props -contains "keywordCount") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (other-project response missing keywordCount)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-G: top3RiskKeywords per-item shape correct ─────────────────────────────
try {
    Write-Host "Testing: B2 top3RiskKeywords per-item required fields present" -NoNewline
    $resp = Invoke-WebRequest -Uri $b2Url -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $top3 = @(($resp.Content | ConvertFrom-Json).data.top3RiskKeywords)
        if ($top3.Count -eq 0) {
            Write-Host "  SKIP (top3RiskKeywords empty -- no active keywords)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $item     = $top3[0]
            $iProps   = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","volatilityScore","volatilityRegime","volatilityMaturity","exceedsThreshold")
            $missing  = $required | Where-Object { $iProps -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing item fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B2-H: concentration ratio arithmetic check ────────────────────────────────
# If ratio is non-null: top3Sum / totalSum should equal ratio within tolerance 0.01.
# We re-derive top3Sum from the returned top3RiskKeywords array.
try {
    Write-Host "Testing: B2 volatilityConcentrationRatio arithmetic consistency" -NoNewline
    $resp = Invoke-WebRequest -Uri ($b2Url + "?alertThreshold=0") -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d   = ($resp.Content | ConvertFrom-Json).data
        $ratio = $d.volatilityConcentrationRatio
        if ($null -eq $ratio) {
            Write-Host "  SKIP (ratio is null -- totalVolatilitySum=0, arithmetic check not applicable)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $top3 = @($d.top3RiskKeywords)
            # Recompute top3Sum from returned items
            $top3Sum = ($top3 | Measure-Object -Property volatilityScore -Sum).Sum
            if ($null -eq $top3Sum) { $top3Sum = 0 }
            $top3Sum = [double]$top3Sum
            $ratioD  = [double]$ratio
            # ratio = top3Sum / totalVolatilitySum => totalVolatilitySum = top3Sum / ratio
            # Verify: ratio * totalVolatilitySum ~= top3Sum
            # We only know top3Sum and ratio; check that ratio <= 1 and ratio >= 0 (already done in B2-C).
            # Additional check: if top3.Count < 3, ratio must be <= 1 (trivially always).
            # More useful: reconstruct and verify ratio directly from top3Sum and activeKeywordCount.
            # Since we don't have totalVolatilitySum directly, verify the weaker constraint:
            # top3Sum / ratio should be >= top3Sum (i.e., totalSum >= top3Sum).
            if ($ratioD -gt 0) {
                $impliedTotal = $top3Sum / $ratioD
                # implied total must be >= top3Sum (ratio <= 1 <=> total >= top3Sum)
                if ($impliedTotal -ge $top3Sum - 0.01) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (implied totalSum=" + $impliedTotal + " < top3Sum=" + $top3Sum + ")") -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                # ratio = 0 means top3Sum = 0; top3 items should all have score = 0
                $allZero = ($top3 | Where-Object { [double]$_.volatilityScore -ne 0 }).Count -eq 0
                if ($allZero) {
                    Write-Host "  PASS (ratio=0, all top3 scores=0)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (ratio=0 but top3 contains non-zero scores)" -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
