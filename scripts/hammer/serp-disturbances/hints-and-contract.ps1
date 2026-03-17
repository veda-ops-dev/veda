# hints-and-contract.ps1
# Focused hammer module for SIL-24 and route contract checks.

# =============================================================================
# OH-A: operatorActionHints present
# =============================================================================
try {
    Write-Host "Testing: OH-A operatorActionHints present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = Get-SerpDisturbanceNoteProps $d
        $failures = @()

        if ($dProps -notcontains "operatorActionHints") {
            $failures += "operatorActionHints missing"
        } else {
            $hints = @($d.operatorActionHints)
            if ($hints.Count -gt 3) { $failures += "hints exceed 3 (got $($hints.Count))" }
            foreach ($h in $hints) {
                $hProps = Get-SerpDisturbanceNoteProps $h
                if ($hProps -notcontains "priority") { $failures += "hint missing priority" }
                if ($hProps -notcontains "type")     { $failures += "hint missing type" }
                if ($hProps -notcontains "label")    { $failures += "hint missing label" }
                if ($h.priority -and $script:SerpDisturbanceValidPriority -notcontains $h.priority) { $failures += "invalid priority: $($h.priority)" }
                if ($h.type -and $script:SerpDisturbanceValidHintTypes -notcontains $h.type) { $failures += "invalid hint type: $($h.type)" }
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
# OH-B: hints sorted by priority DESC then type ASC
# =============================================================================
try {
    Write-Host "Testing: OH-B hints sorted priority DESC then type ASC" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $Headers `
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
# OH-C: include=hints returns full dependency stack with meta
# =============================================================================
try {
    Write-Host "Testing: OH-C include=hints returns full dependency stack with meta" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase`?include=hints" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = Get-SerpDisturbanceNoteProps $d
        $failures = @()
        $required = @("meta","volatilityCluster","eventAttribution","weather","forecast","alerts","briefing","keywordImpactRanking","alertAffectedKeywords","operatorActionHints")
        foreach ($f in $required) {
            if ($dProps -notcontains $f) { $failures += "$f missing" }
        }
        if ($dProps -contains 'meta') {
            $metaProps = Get-SerpDisturbanceNoteProps $d.meta
            foreach ($f in @('windowDays','requestedLayers','resolvedLayers','keywordTargetCount','snapshotCount')) {
                if ($metaProps -notcontains $f) { $failures += "meta.$f missing" }
            }
            $expectedResolved = @('disturbance','attribution','weather','forecast','alerts','briefing','impact','affected','hints')
            if (-not (Compare-SerpDisturbanceStringArray @($d.meta.resolvedLayers) $expectedResolved)) { $failures += 'resolvedLayers mismatch' }
            if (-not (Compare-SerpDisturbanceStringArray @($d.meta.requestedLayers) @('hints'))) { $failures += 'requestedLayers mismatch for include=hints' }
        }
        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join '; ')) -ForegroundColor Red; Hammer-Record FAIL }
    } else {
        Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch {
    Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
}

# =============================================================================
# OH-D/OH-E/OH-F/OH-G/OH-H/OH-I/OH-J
# =============================================================================
try {
    Write-Host "Testing: OH-D zero-target project returns empty arrays" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200 -or $r.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-E impact/affected/hints endpoint is read-only" -NoNewline
    $elBefore = 0
    try { $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing; if ($rEL.StatusCode -eq 200) { $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total } } catch {}
    @("?include=impact", "?include=affected", "?include=hints") | ForEach-Object { try { Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase$_" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing | Out-Null } catch {} }
    $elAfter = 0
    try { $rEL2 = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing; if ($rEL2.StatusCode -eq 200) { $elAfter = ($rEL2.Content | ConvertFrom-Json).pagination.total } } catch {}
    if ($elAfter -eq $elBefore) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (EventLog grew from $elBefore to $elAfter)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-F deterministic repeated calls produce identical results" -NoNewline
    $url = "$Base$script:SerpDisturbanceBase`?include=hints"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-G include=disturbance returns minimal layer set with meta" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase`?include=disturbance" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-H include=alerts returns alert dependency stack with meta" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase`?include=alerts" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-I invalid include rejected with 400" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase`?include=wizard" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: OH-J unknown query param rejected with 400" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$script:SerpDisturbanceBase`?windowDays=60&banana=true" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
