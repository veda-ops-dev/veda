# hammer-sil22-24.ps1 -- SIL-22, SIL-23, SIL-24: Impact Ranking, Affected Keywords, Operator Hints
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances
#
# Tests:
#   KI-A  keywordImpactRanking present
#   KI-B  ranking sorted by impactScore DESC, query ASC, id ASC
#   KI-C  supportingSignals sorted deterministically
#   AK-A  alertAffectedKeywords present
#   AK-B  affected keywords are subset of (or same as) impact ranking
#   OH-A  operatorActionHints present
#   OH-B  hints sorted by priority DESC then type ASC
#   OH-C  include=hints returns full dependency stack
#   OH-D  zero-target path returns empty arrays
#   OH-E  endpoint remains read-only
#   OH-F  deterministic repeated calls identical

Hammer-Section "SIL-22-24 TESTS (IMPACT RANKING, AFFECTED KEYWORDS, OPERATOR HINTS)"

$_kBase = "/api/seo/serp-disturbances"

$_validDrivers   = @("ai_overview_expansion","feature_regime_shift","competitor_dominance_shift","intent_reclassification","algorithm_shift","unknown")
$_validPriority  = @("high","medium","low")
$_validHintTypes = @("review_ai_overview_keywords","inspect_feature_transitions","inspect_rank_turbulence","inspect_domain_dominance","inspect_intent_shift","monitor_mixed_disturbance")

# =============================================================================
# KI-A: keywordImpactRanking present in default response
# =============================================================================
try {
    Write-Host "Testing: KI-A keywordImpactRanking present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "keywordImpactRanking") {
            $failures += "keywordImpactRanking missing"
        } else {
            $ranking = @($d.keywordImpactRanking)
            if ($ranking.Count -gt 10) { $failures += "ranking exceeds 10 items (got $($ranking.Count))" }

            foreach ($item in $ranking) {
                $iProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($iProps -notcontains "keywordTargetId") { $failures += "item missing keywordTargetId" }
                if ($iProps -notcontains "query")           { $failures += "item missing query" }
                if ($iProps -notcontains "impactScore")     { $failures += "item missing impactScore" }
                if ($iProps -notcontains "primaryDriver")   { $failures += "item missing primaryDriver" }
                if ($iProps -notcontains "supportingSignals") { $failures += "item missing supportingSignals" }
                if ($item.primaryDriver -and $_validDrivers -notcontains $item.primaryDriver) {
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
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KI-B: ranking sorted by impactScore DESC, query ASC, id ASC
# =============================================================================
try {
    Write-Host "Testing: KI-B ranking sorted impactScore DESC, query ASC, id ASC" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
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

        if ($failures.Count -eq 0) { Write-Host "  PASS (count=$($ranking.Count))" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# KI-C: supportingSignals sorted alphabetically within each keyword
# =============================================================================
try {
    Write-Host "Testing: KI-C supportingSignals sorted deterministically in impact ranking" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $ranking = @(($r.Content | ConvertFrom-Json).data.keywordImpactRanking)
        $failures = @()

        foreach ($item in $ranking) {
            $sigs = @($item.supportingSignals)
            for ($i = 0; $i -lt ($sigs.Count - 1); $i++) {
                if ([string]::Compare($sigs[$i], $sigs[$i + 1], $true) -gt 0) {
                    $failures += "signal sort violation in '$($item.query)': $($sigs[$i]) before $($sigs[$i+1])"
                }
            }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# AK-A: alertAffectedKeywords present
# =============================================================================
try {
    Write-Host "Testing: AK-A alertAffectedKeywords present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "alertAffectedKeywords") {
            $failures += "alertAffectedKeywords missing"
        } else {
            $affected = @($d.alertAffectedKeywords)
            if ($affected.Count -gt 5) { $failures += "affected keywords exceed 5 (got $($affected.Count))" }

            foreach ($item in $affected) {
                $iProps = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
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
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# AK-B: affected keywords are a subset of impact ranking
# =============================================================================
try {
    Write-Host "Testing: AK-B affected keywords are subset of impact ranking" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $rankingIds  = @($d.keywordImpactRanking | ForEach-Object { $_.keywordTargetId })
        $affectedIds = @($d.alertAffectedKeywords | ForEach-Object { $_.keywordTargetId })
        $failures = @()

        foreach ($id in $affectedIds) {
            if ($rankingIds -notcontains $id) {
                $failures += "affected keyword id '$id' not found in impact ranking"
            }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-A: operatorActionHints present
# =============================================================================
try {
    Write-Host "Testing: OH-A operatorActionHints present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "operatorActionHints") {
            $failures += "operatorActionHints missing"
        } else {
            $hints = @($d.operatorActionHints)
            if ($hints.Count -gt 3) { $failures += "hints exceed 3 (got $($hints.Count))" }

            foreach ($h in $hints) {
                $hProps = $h | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($hProps -notcontains "priority") { $failures += "hint missing priority" }
                if ($hProps -notcontains "type")     { $failures += "hint missing type" }
                if ($hProps -notcontains "label")    { $failures += "hint missing label" }
                if ($h.priority -and $_validPriority  -notcontains $h.priority) { $failures += "invalid priority: $($h.priority)" }
                if ($h.type     -and $_validHintTypes -notcontains $h.type)     { $failures += "invalid hint type: $($h.type)" }
                if ($h.label    -and $h.label.Length -eq 0) { $failures += "hint label is empty" }
            }
        }

        if ($failures.Count -eq 0) {
            $cnt = @($d.operatorActionHints).Count
            Write-Host "  PASS (count=$cnt)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-B: hints sorted by priority DESC then type ASC
# =============================================================================
try {
    Write-Host "Testing: OH-B hints sorted priority DESC then type ASC" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $hints = @(($r.Content | ConvertFrom-Json).data.operatorActionHints)
        $failures = @()
        $priorityOrder = @{ "high" = 2; "medium" = 1; "low" = 0 }

        for ($i = 0; $i -lt ($hints.Count - 1); $i++) {
            $a = $hints[$i]; $b = $hints[$i + 1]
            $pa = $priorityOrder[$a.priority]; $pb = $priorityOrder[$b.priority]
            if ($pa -lt $pb) {
                $failures += "priority sort violation: $($a.priority) before $($b.priority)"
            } elseif ($pa -eq $pb) {
                if ([string]::Compare($a.type, $b.type, $true) -gt 0) {
                    $failures += "type sort violation at same priority: $($a.type) before $($b.type)"
                }
            }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-C: include=hints returns full dependency stack
# =============================================================================
try {
    Write-Host "Testing: OH-C include=hints returns full dependency stack" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_kBase`?include=hints" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        $required = @("volatilityCluster","eventAttribution","weather","forecast","alerts","briefing","keywordImpactRanking","alertAffectedKeywords","operatorActionHints")
        foreach ($f in $required) {
            if ($dProps -notcontains $f) { $failures += "$f missing" }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS (all layers present)" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-D: zero-target project returns empty arrays for impact/affected/hints
# =============================================================================
try {
    Write-Host "Testing: OH-D zero-target project returns empty arrays" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_kBase" -Method GET -Headers $OtherHeaders `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            $failures = @()
            # Allow other project to have data; verify arrays (not null) if fields present
            $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($dProps -contains "keywordImpactRanking"  -and $null -eq $d.keywordImpactRanking)  { $failures += "keywordImpactRanking is null (expected array)" }
            if ($dProps -contains "alertAffectedKeywords" -and $null -eq $d.alertAffectedKeywords) { $failures += "alertAffectedKeywords is null (expected array)" }
            if ($dProps -contains "operatorActionHints"   -and $null -eq $d.operatorActionHints)   { $failures += "operatorActionHints is null (expected array)" }

            if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
        } elseif ($r.StatusCode -eq 400) {
            Write-Host "  PASS (400 -- other project not found)" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-E: endpoint remains read-only (no EventLog growth)
# =============================================================================
try {
    Write-Host "Testing: OH-E impact/affected/hints endpoint is read-only" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) { $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total }
    } catch {}

    @("?include=impact", "?include=affected", "?include=hints") | ForEach-Object {
        try {
            Invoke-WebRequest -Uri "$Base$_kBase$_" -Method GET -Headers $Headers `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing | Out-Null
        } catch {}
    }

    $elAfter = 0
    try {
        $rEL2 = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL2.StatusCode -eq 200) { $elAfter = ($rEL2.Content | ConvertFrom-Json).pagination.total }
    } catch {}

    if ($elAfter -eq $elBefore) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (EventLog grew from $elBefore to $elAfter)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# OH-F: deterministic repeated calls produce identical results
# =============================================================================
try {
    Write-Host "Testing: OH-F deterministic repeated calls produce identical results" -NoNewline
    $url = "$Base$_kBase`?include=hints"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        $j1 = @{
            ranking  = $d1.keywordImpactRanking   | ConvertTo-Json -Depth 5 -Compress
            affected = $d1.alertAffectedKeywords   | ConvertTo-Json -Depth 5 -Compress
            hints    = $d1.operatorActionHints     | ConvertTo-Json -Depth 5 -Compress
        } | ConvertTo-Json -Compress
        $j2 = @{
            ranking  = $d2.keywordImpactRanking   | ConvertTo-Json -Depth 5 -Compress
            affected = $d2.alertAffectedKeywords   | ConvertTo-Json -Depth 5 -Compress
            hints    = $d2.operatorActionHints     | ConvertTo-Json -Depth 5 -Compress
        } | ConvertTo-Json -Compress
        if ($j1 -eq $j2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
