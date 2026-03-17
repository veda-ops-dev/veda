# hammer-sil20.ps1 -- SIL-20 SERP Weather Alerts
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances (alerts field + include=alerts)
#
# Tests:
#   SA-A  alerts field returned in default response
#   SA-B  weather deterioration alert emitted when worsening + shifting/turbulent
#   SA-C  weather instability alert emitted when state = unstable
#   SA-D  AI overview surge alert emitted when AI climate + accelerating momentum
#   SA-E  alerts sorted deterministically by severity then type
#   SA-F  include=alerts returns full dependency stack
#   SA-G  endpoint remains read-only
#   SA-H  deterministic repeated calls produce identical alerts

Hammer-Section "SIL-20 TESTS (SERP WEATHER ALERTS)"

$_sa20Base = "/api/seo/serp-disturbances"

# Valid alert levels and types
$_validLevels = @("info","warning","critical")
$_validTypes  = @(
    "weather_deterioration","weather_instability","ai_overview_surge",
    "feature_regime_shift","competitor_dominance_shift","intent_reclassification",
    "algorithm_shift","mixed_disturbance"
)
$_validDrivers = @(
    "ai_overview_expansion","feature_regime_shift","competitor_dominance_shift",
    "intent_reclassification","algorithm_shift","unknown"
)

# =============================================================================
# SA-A: alerts field returned in default response
# =============================================================================
try {
    Write-Host "Testing: SA-A alerts field returned in default response" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "alerts") {
            $failures += "alerts field missing from response"
        } else {
            # alerts must be an array
            if ($d.alerts -isnot [System.Array] -and $d.alerts -isnot [System.Collections.ArrayList]) {
                # PSObject with count=0 is still ok (empty array)
                if ($null -ne $d.alerts -and $d.alerts.GetType().Name -ne "Object[]") {
                    $failures += "alerts is not an array"
                }
            }
            # Each alert must have required fields with valid values
            foreach ($alert in $d.alerts) {
                $aProps = $alert | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                if ($aProps -notcontains "level")   { $failures += "alert missing level" }
                if ($aProps -notcontains "type")    { $failures += "alert missing type" }
                if ($aProps -notcontains "message") { $failures += "alert missing message" }
                if ($aProps -notcontains "driver")  { $failures += "alert missing driver" }
                if ($alert.level  -and $_validLevels  -notcontains $alert.level)  { $failures += "invalid alert level: $($alert.level)" }
                if ($alert.type   -and $_validTypes   -notcontains $alert.type)   { $failures += "invalid alert type: $($alert.type)" }
                if ($alert.driver -and $_validDrivers -notcontains $alert.driver) { $failures += "invalid alert driver: $($alert.driver)" }
            }
        }

        if ($failures.Count -eq 0) {
            $alertCount = if ($d.alerts) { @($d.alerts).Count } else { 0 }
            Write-Host "  PASS (alerts=$alertCount)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-B: weather_deterioration emitted when worsening + shifting/turbulent
# =============================================================================
try {
    Write-Host "Testing: SA-B weather_deterioration alert structure when conditions match" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        # If conditions match (worsening + shifting/turbulent), alert must be present
        $weatherState = $d.weather.state
        $forecastTrend = $d.forecast.trend
        $conditionsMatch = ($forecastTrend -eq "worsening") -and ($weatherState -in @("shifting","turbulent"))

        if ($conditionsMatch) {
            $hasAlert = $d.alerts | Where-Object { $_.type -eq "weather_deterioration" }
            if (-not $hasAlert) {
                $failures += "weather_deterioration alert missing (state=$weatherState trend=$forecastTrend)"
            } else {
                if ($hasAlert.level -ne "warning") { $failures += "weather_deterioration should be warning level" }
            }
        } else {
            # Conditions don't match; verify alert is absent (not required if absent)
            Write-Host "  PASS (conditions do not trigger: state=$weatherState trend=$forecastTrend)" -ForegroundColor Green
            Hammer-Record PASS
            # early exit via flag
            $failures = @("__skip__")
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS (weather_deterioration alert present)" -ForegroundColor Green; Hammer-Record PASS
        } elseif ($failures[0] -ne "__skip__") {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-C: weather_instability alert emitted when state = unstable
# =============================================================================
try {
    Write-Host "Testing: SA-C weather_instability alert emitted when state = unstable" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()
        $weatherState = $d.weather.state

        if ($weatherState -eq "unstable") {
            $hasAlert = $d.alerts | Where-Object { $_.type -eq "weather_instability" }
            if (-not $hasAlert) {
                $failures += "weather_instability alert missing when state=unstable"
            } else {
                if ($hasAlert.level -ne "critical") { $failures += "weather_instability should be critical" }
            }
            if ($failures.Count -eq 0) {
                Write-Host "  PASS (weather_instability critical alert present)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  PASS (state=$weatherState, instability rule not triggered)" -ForegroundColor Green; Hammer-Record PASS
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-D: ai_overview_surge alert emitted when AI climate + accelerating momentum
# =============================================================================
try {
    Write-Host "Testing: SA-D ai_overview_surge alert emitted when AI surge + accelerating" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()
        $featureClimate = $d.weather.featureClimate
        $momentum = $d.forecast.momentum

        if ($featureClimate -eq "ai_overview_surge" -and $momentum -eq "accelerating") {
            $hasAlert = $d.alerts | Where-Object { $_.type -eq "ai_overview_surge" }
            if (-not $hasAlert) {
                $failures += "ai_overview_surge alert missing (climate=$featureClimate momentum=$momentum)"
            } else {
                if ($hasAlert.level -ne "critical") { $failures += "ai_overview_surge should be critical" }
                if ($hasAlert.driver -ne "ai_overview_expansion") { $failures += "ai_overview_surge driver should be ai_overview_expansion" }
            }
            if ($failures.Count -eq 0) {
                Write-Host "  PASS (ai_overview_surge critical alert present)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  PASS (conditions not met: climate=$featureClimate momentum=$momentum)" -ForegroundColor Green; Hammer-Record PASS
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-E: alerts sorted deterministically by severity DESC then type ASC
# =============================================================================
try {
    Write-Host "Testing: SA-E alerts sorted by severity DESC then type ASC" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()
        $alerts = @($d.alerts)

        if ($alerts.Count -ge 2) {
            $levelPriority = @{ "critical" = 2; "warning" = 1; "info" = 0 }
            for ($i = 0; $i -lt ($alerts.Count - 1); $i++) {
                $a = $alerts[$i]
                $b = $alerts[$i + 1]
                $pa = $levelPriority[$a.level]
                $pb = $levelPriority[$b.level]
                if ($pa -lt $pb) {
                    $failures += "sort violation: $($a.level)/$($a.type) before $($b.level)/$($b.type)"
                } elseif ($pa -eq $pb) {
                    if ([string]::Compare($a.type, $b.type, $true) -gt 0) {
                        $failures += "type sort violation: $($a.type) before $($b.type) at same level"
                    }
                }
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host "  PASS (sort order correct, count=$($alerts.Count))" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-F: include=alerts returns full dependency stack
# =============================================================================
try {
    Write-Host "Testing: SA-F include=alerts returns disturbance+attribution+weather+forecast+alerts" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sa20Base`?include=alerts" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $dProps = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        $failures = @()

        if ($dProps -notcontains "volatilityCluster")  { $failures += "volatilityCluster missing" }
        if ($dProps -notcontains "eventAttribution")   { $failures += "eventAttribution missing" }
        if ($dProps -notcontains "weather")            { $failures += "weather missing" }
        if ($dProps -notcontains "forecast")           { $failures += "forecast missing" }
        if ($dProps -notcontains "alerts")             { $failures += "alerts missing" }

        if ($failures.Count -eq 0) {
            $alertCount = if ($d.alerts) { @($d.alerts).Count } else { 0 }
            Write-Host "  PASS (all layers present, alerts=$alertCount)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SA-G: endpoint remains read-only (no EventLog growth)
# =============================================================================
try {
    Write-Host "Testing: SA-G alerts endpoint is read-only (no EventLog entries)" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) {
            $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    @("", "?include=alerts", "?include=disturbance,alerts") | ForEach-Object {
        try {
            Invoke-WebRequest -Uri "$Base$_sa20Base$_" -Method GET -Headers $Headers `
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
# SA-H: deterministic repeated calls produce identical alerts
# =============================================================================
try {
    Write-Host "Testing: SA-H deterministic repeated calls produce identical alerts" -NoNewline
    $url = "$Base$_sa20Base`?include=alerts"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $j1 = (($r1.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 5 -Compress)
        $j2 = (($r2.Content | ConvertFrom-Json).data.alerts | ConvertTo-Json -Depth 5 -Compress)
        if ($j1 -eq $j2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (alerts differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
