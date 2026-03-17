# hammer-sil21.ps1 -- SIL-21 SERP Alert Briefing Packets
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances (briefing field + include=briefing)
#
# Tests:
#   SB-A  briefing field present in default response
#   SB-B  primaryAlert matches first alert in alerts array
#   SB-C  supportingSignals sorted alphabetically (deterministic)
#   SB-D  summary deterministic across repeated calls
#   SB-E  include=briefing returns full dependency stack
#   SB-F  endpoint remains read-only (no EventLog growth)
#   SB-G  deterministic repeated calls produce identical briefing

Hammer-Section "SIL-21 TESTS (SERP ALERT BRIEFING PACKETS)"

$_sb21Base = "/api/seo/serp-disturbances"

$_validWeatherStates  = @("calm","shifting","turbulent","unstable")
$_validForecastTrends = @("improving","stable","worsening","volatile")
$_validMomentum       = @("accelerating","decelerating","sustained","stable")
$_validDrivers        = @(
    "ai_overview_expansion","feature_regime_shift","competitor_dominance_shift",
    "intent_reclassification","algorithm_shift","unknown"
)
$_validSignals = @(
    "ai_overview_activity","ai_overview_expansion","dominance_shift",
    "feature_shift_detected","intent_drift","ranking_turbulence","volatility_cluster"
)

# =============================================================================
# SB-A: briefing field present in default response
# =============================================================================
try {
    Write-Host "Testing: SB-A briefing field present in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sb21Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "briefing") {
            $failures += "briefing field missing"
        } else {
            $b = $d.briefing
            $bProps = $b | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

            $required = @("primaryAlert","weatherState","forecastTrend","momentum","driver","affectedKeywords","supportingSignals","summary")
            $missing = $required | Where-Object { $bProps -notcontains $_ }
            if ($missing.Count -gt 0) { $failures += "briefing missing: $($missing -join ', ')" }

            if ($b.weatherState  -and $_validWeatherStates  -notcontains $b.weatherState)  { $failures += "invalid weatherState: $($b.weatherState)" }
            if ($b.forecastTrend -and $_validForecastTrends -notcontains $b.forecastTrend) { $failures += "invalid forecastTrend: $($b.forecastTrend)" }
            if ($b.momentum      -and $_validMomentum       -notcontains $b.momentum)       { $failures += "invalid momentum: $($b.momentum)" }
            if ($b.driver        -and $_validDrivers        -notcontains $b.driver)         { $failures += "invalid driver: $($b.driver)" }

            if ($b.affectedKeywords -isnot [int] -and $b.affectedKeywords -isnot [long] -and $null -ne $b.affectedKeywords) {
                if (-not ($b.affectedKeywords -match '^\d+$')) { $failures += "affectedKeywords not numeric" }
            }

            if ($b.summary -and $b.summary.Length -eq 0) { $failures += "summary is empty string" }

            # supportingSignals must be array, each token valid
            if ($b.supportingSignals) {
                foreach ($sig in $b.supportingSignals) {
                    if ($_validSignals -notcontains $sig) { $failures += "invalid signal: $sig" }
                }
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS (state=$($d.briefing.weatherState) trend=$($d.briefing.forecastTrend))" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-B: primaryAlert matches first alert in alerts array
# =============================================================================
try {
    Write-Host "Testing: SB-B primaryAlert matches first alert in alerts array" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sb21Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()
        $alerts = @($d.alerts)

        if ($alerts.Count -eq 0) {
            # No alerts: primaryAlert must be null
            if ($null -ne $d.briefing.primaryAlert) {
                $failures += "primaryAlert should be null when alerts is empty"
            }
        } else {
            $first = $alerts[0]
            $pa    = $d.briefing.primaryAlert
            if ($null -eq $pa) {
                $failures += "primaryAlert is null but alerts array is non-empty"
            } else {
                if ($pa.level  -ne $first.level)  { $failures += "primaryAlert.level mismatch ($($pa.level) vs $($first.level))" }
                if ($pa.type   -ne $first.type)   { $failures += "primaryAlert.type mismatch ($($pa.type) vs $($first.type))" }
                if ($pa.driver -ne $first.driver) { $failures += "primaryAlert.driver mismatch" }
            }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-C: supportingSignals sorted alphabetically
# =============================================================================
try {
    Write-Host "Testing: SB-C supportingSignals sorted alphabetically" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sb21Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()
        $sigs = @($d.briefing.supportingSignals)

        if ($sigs.Count -ge 2) {
            for ($i = 0; $i -lt ($sigs.Count - 1); $i++) {
                if ([string]::Compare($sigs[$i], $sigs[$i + 1], $true) -gt 0) {
                    $failures += "sort violation: $($sigs[$i]) before $($sigs[$i+1])"
                }
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS (signals=$($sigs.Count))" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-D: summary deterministic across repeated calls
# =============================================================================
try {
    Write-Host "Testing: SB-D summary deterministic across repeated calls" -NoNewline
    $url = "$Base$_sb21Base`?include=briefing"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $s1 = ($r1.Content | ConvertFrom-Json).data.briefing.summary
        $s2 = ($r2.Content | ConvertFrom-Json).data.briefing.summary
        if ($s1 -eq $s2) { Write-Host "  PASS (summary='$s1')" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (summary differs between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-E: include=briefing returns full dependency stack
# =============================================================================
try {
    Write-Host "Testing: SB-E include=briefing returns full dependency stack" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sb21Base`?include=briefing" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "volatilityCluster") { $failures += "volatilityCluster missing" }
        if ($dProps -notcontains "eventAttribution")  { $failures += "eventAttribution missing" }
        if ($dProps -notcontains "weather")           { $failures += "weather missing" }
        if ($dProps -notcontains "forecast")          { $failures += "forecast missing" }
        if ($dProps -notcontains "alerts")            { $failures += "alerts missing" }
        if ($dProps -notcontains "briefing")          { $failures += "briefing missing" }

        if ($failures.Count -eq 0) { Write-Host "  PASS (all layers present)" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-F: endpoint remains read-only (no EventLog growth)
# =============================================================================
try {
    Write-Host "Testing: SB-F briefing endpoint is read-only (no EventLog entries)" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) {
            $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    @("", "?include=briefing", "?include=alerts,briefing") | ForEach-Object {
        try {
            Invoke-WebRequest -Uri "$Base$_sb21Base$_" -Method GET -Headers $Headers `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing | Out-Null
        } catch {}
    }

    $elAfter = 0
    try {
        $rEL2 = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL2.StatusCode -eq 200) {
            $elAfter = ($rEL2.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    if ($elAfter -eq $elBefore) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (EventLog grew from $elBefore to $elAfter)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SB-G: deterministic repeated calls produce identical briefing
# =============================================================================
try {
    Write-Host "Testing: SB-G deterministic repeated calls produce identical briefing" -NoNewline
    $url = "$Base$_sb21Base`?include=briefing"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $j1 = (($r1.Content | ConvertFrom-Json).data.briefing | ConvertTo-Json -Depth 5 -Compress)
        $j2 = (($r2.Content | ConvertFrom-Json).data.briefing | ConvertTo-Json -Depth 5 -Compress)
        if ($j1 -eq $j2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (briefing differs between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
