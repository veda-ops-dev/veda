# impact-and-affected.ps1
# Focused hammer module for SIL-22 and SIL-23.

# =============================================================================
# KI-A: keywordImpactRanking present in default response
# =============================================================================
try {
    Write-Host "Testing: KI-A keywordImpactRanking present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = Get-SerpDisturbanceNoteProps $d
        $failures = @()

        if ($dProps -notcontains "meta") {
            $failures += "meta missing"
        }
        if ($dProps -notcontains "keywordImpactRanking") {
            $failures += "keywordImpactRanking missing"
        } else {
            $ranking = @($d.keywordImpactRanking)
            if ($ranking.Count -gt 10) { $failures += "ranking exceeds 10 items (got $($ranking.Count))" }

            foreach ($item in $ranking) {
                $iProps = Get-SerpDisturbanceNoteProps $item
                if ($iProps -notcontains "keywordTargetId") { $failures += "item missing keywordTargetId" }
                if ($iProps -notcontains "query")           { $failures += "item missing query" }
                if ($iProps -notcontains "impactScore")     { $failures += "item missing impactScore" }
                if ($iProps -notcontains "primaryDriver")   { $failures += "item missing primaryDriver" }
                if ($iProps -notcontains "supportingSignals") { $failures += "item missing supportingSignals" }
                if ($item.primaryDriver -and $script:SerpDisturbanceValidDrivers -notcontains $item.primaryDriver) {
                    $failures += "invalid primaryDriver: $($item.primaryDriver)"
                }
                if ($item.impactScore -lt 0 -or $item.impactScore -gt 100) {
                    $failures += "impactScore out of range: $($item.impactScore)"
                }
            }
        }

        if ($failures.Count -eq 0) {
            $cnt = @($d.keywordImpactRanking).Count
            Write-Host "  PASS (count=$cnt)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# =============================================================================
# KI-B: ranking sorted by impactScore DESC, query ASC, id ASC
# =============================================================================
try {
    Write-Host "Testing: KI-B ranking sorted impactScore DESC, query ASC, id ASC" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $ranking = @(($r.Content | ConvertFrom-Json).data.keywordImpactRanking)
        $failures = @()

        if ($ranking.Count -ge 2) {
            for ($i = 0; $i -lt ($ranking.Count - 1); $i++) {
                $a = $ranking[$i]; $b = $ranking[$i + 1]
                if ($a.impactScore -lt $b.impactScore) {
                    $failures += "score sort violation: $($a.impactScore) before $($b.impactScore)"
                } elseif ($a.impactScore -eq $b.impactScore) {
                    $qcmp = [string]::Compare($a.query, $b.query, $true)
                    if ($qcmp -gt 0) {
                        $failures += "query sort violation: $($a.query) before $($b.query)"
                    } elseif ($qcmp -eq 0) {
                        if ([string]::Compare($a.keywordTargetId, $b.keywordTargetId, $true) -gt 0) {
                            $failures += "id sort violation: $($a.keywordTargetId) before $($b.keywordTargetId)"
                        }
                    }
                }
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# =============================================================================
# KI-C: supportingSignals sorted alphabetically within each keyword
# =============================================================================
try {
    Write-Host "Testing: KI-C supportingSignals sorted deterministically in impact ranking" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $ranking = @(($r.Content | ConvertFrom-Json).data.keywordImpactRanking)
        $failures = @()

        foreach ($item in $ranking) {
            $signals = @($item.supportingSignals)
            for ($i = 0; $i -lt ($signals.Count - 1); $i++) {
                if ([string]::Compare($signals[$i], $signals[$i + 1], $true) -gt 0) {
                    $failures += "signal sort violation in '$($item.query)': $($signals[$i]) before $($signals[$i + 1])"
                }
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# =============================================================================
# AK-A: alertAffectedKeywords present
# =============================================================================
try {
    Write-Host "Testing: AK-A alertAffectedKeywords present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = Get-SerpDisturbanceNoteProps $d
        $failures = @()

        if ($dProps -notcontains "alertAffectedKeywords") {
            $failures += "alertAffectedKeywords missing"
        } else {
            $affected = @($d.alertAffectedKeywords)
            if ($affected.Count -gt 5) { $failures += "affected keywords exceed 5 (got $($affected.Count))" }

            foreach ($item in $affected) {
                $iProps = Get-SerpDisturbanceNoteProps $item
                if ($iProps -notcontains "keywordTargetId") { $failures += "affected item missing keywordTargetId" }
                if ($iProps -notcontains "query")           { $failures += "affected item missing query" }
                if ($iProps -notcontains "impactScore")     { $failures += "affected item missing impactScore" }
                if ($iProps -notcontains "reason")          { $failures += "affected item missing reason" }
                if ($item.reason -and $item.reason.Length -eq 0) { $failures += "affected item reason is empty" }
            }
        }

        if ($failures.Count -eq 0) {
            $cnt = @($d.alertAffectedKeywords).Count
            Write-Host "  PASS (count=$cnt)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# =============================================================================
# AK-B: affected keywords are a subset of impact ranking
# =============================================================================
try {
    Write-Host "Testing: AK-B affected keywords are subset of impact ranking" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $rankingIds = @($d.keywordImpactRanking | ForEach-Object { $_.keywordTargetId })
        $affectedIds = @($d.alertAffectedKeywords | ForEach-Object { $_.keywordTargetId })
        $failures = @()

        foreach ($id in $affectedIds) {
            if ($rankingIds -notcontains $id) {
                $failures += "affected keyword id '$id' not found in impact ranking"
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}
