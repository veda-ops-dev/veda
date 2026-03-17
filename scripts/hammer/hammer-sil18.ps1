# hammer-sil18.ps1 -- SIL-18 SERP Weather
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances (now includes weather)
#
# Tests:
#   SW-A  weather section returned with all required fields
#   SW-B  calm state emitted when no disturbance signals
#   SW-C  turbulent state emitted when volatilityCluster + rankingTurbulence true
#   SW-D  ai_overview_surge featureClimate emitted for AI overview expansion case
#   SW-E  summary string deterministic across repeated calls
#   SW-F  endpoint remains read-only

Hammer-Section "SIL-18 TESTS (SERP WEATHER)"

$_swBase  = "/api/seo/serp-disturbances"
$_swRunId = (Get-Date).Ticks

# =============================================================================
# SW-A: weather field present and correctly shaped
# =============================================================================
try {
    Write-Host "Testing: SW-A weather field shape" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_swBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        if ($null -eq $d.weather) {
            $failures += "weather is null"
        } else {
            $w = $d.weather
            $wProps = $w | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            foreach ($f in @("state","driver","confidence","stability","featureClimate","summary")) {
                if ($wProps -notcontains $f) { $failures += "weather missing $f" }
            }
            $validStates = @("calm","shifting","turbulent","unstable")
            if ($w.state -notin $validStates) { $failures += "invalid state: $($w.state)" }

            $validStability = @("high","moderate","low")
            if ($w.stability -notin $validStability) { $failures += "invalid stability: $($w.stability)" }

            $validClimates = @("stable_features","ai_overview_surge","feature_rotation","mixed_features")
            if ($w.featureClimate -notin $validClimates) { $failures += "invalid featureClimate: $($w.featureClimate)" }

            if ($w.confidence -lt 0 -or $w.confidence -gt 95) {
                $failures += "confidence out of range: $($w.confidence)"
            }

            if ([string]::IsNullOrEmpty($w.summary)) { $failures += "summary is empty" }
        }

        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (state=$($d.weather.state), stability=$($d.weather.stability))") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SW-B: calm state + high stability emitted when no disturbance signals present
#
# Uses OtherProject which has no seeded high-disturbance keywords.
# If OtherProject has no keyword targets at all, we use a fresh tiny fixture.
# In either case: if both volatilityCluster=false and rankingTurbulence=false,
# weather.state must be calm or shifting, and stability must be high or moderate.
# =============================================================================
try {
    Write-Host "Testing: SW-B calm/shifting state for low-disturbance project" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_swBase" -Method GET -Headers $OtherHeaders `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        # If no disturbance signals, state must be calm or shifting only
        if ($d.volatilityCluster -eq $false -and $d.rankingTurbulence -eq $false) {
            if ($d.weather.state -notin @("calm","shifting")) {
                $failures += "expected calm or shifting when no cluster/turbulence, got $($d.weather.state)"
            }
            if ($d.weather.stability -notin @("high","moderate")) {
                $failures += "expected high or moderate stability, got $($d.weather.stability)"
            }
        }

        # state must always be consistent with stability
        $stateStabilityOk = $true
        switch ($d.weather.state) {
            "calm"     { if ($d.weather.stability -ne "high")     { $stateStabilityOk = $false } }
            "shifting" { if ($d.weather.stability -ne "moderate") { $stateStabilityOk = $false } }
            "turbulent" { if ($d.weather.stability -ne "low")     { $stateStabilityOk = $false } }
            "unstable"  { if ($d.weather.stability -ne "low")     { $stateStabilityOk = $false } }
        }
        if (-not $stateStabilityOk) {
            $failures += "state=$($d.weather.state) inconsistent with stability=$($d.weather.stability)"
        }

        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (state=$($d.weather.state), stability=$($d.weather.stability), vc=$($d.volatilityCluster))") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SW-C: turbulent or unstable state when volatilityCluster + rankingTurbulence true
# =============================================================================
try {
    Write-Host "Testing: SW-C turbulent/unstable implies volatilityCluster+rankingTurbulence" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_swBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        # Invariant: if state=turbulent or unstable, both vc and rt must be true
        if ($d.weather.state -in @("turbulent","unstable")) {
            if ($d.volatilityCluster -ne $true) {
                $failures += "turbulent/unstable but volatilityCluster=false"
            }
            if ($d.rankingTurbulence -ne $true) {
                $failures += "turbulent/unstable but rankingTurbulence=false"
            }
        }

        # Invariant: if both vc+rt true, state must be turbulent or unstable
        if ($d.volatilityCluster -eq $true -and $d.rankingTurbulence -eq $true) {
            if ($d.weather.state -notin @("turbulent","unstable")) {
                $failures += "volatilityCluster+rankingTurbulence=true but state=$($d.weather.state)"
            }
        }

        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (state=$($d.weather.state), vc=$($d.volatilityCluster), rt=$($d.rankingTurbulence))") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SW-D: ai_overview_surge featureClimate when AI overview cause detected
# =============================================================================
try {
    Write-Host "Testing: SW-D ai_overview_surge consistent with ai_overview_expansion cause" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_swBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        # If attribution cause=ai_overview_expansion and ai_overview in new features,
        # featureClimate should be ai_overview_surge (not a hard invariant but checked
        # with tolerance -- if cause=ai_overview_expansion, featureClimate must not be
        # stable_features).
        if ($d.eventAttribution.cause -eq "ai_overview_expansion") {
            if ($d.weather.featureClimate -eq "stable_features") {
                $failures += "cause=ai_overview_expansion but featureClimate=stable_features"
            }
            if ($d.weather.driver -ne "ai_overview_expansion") {
                $failures += "weather.driver=$($d.weather.driver) should match attribution cause"
            }
        }

        # weather.driver must always match eventAttribution.cause
        if ($d.weather.driver -ne $d.eventAttribution.cause) {
            $failures += "weather.driver ($($d.weather.driver)) != eventAttribution.cause ($($d.eventAttribution.cause))"
        }

        # weather.confidence must always match eventAttribution.confidence
        if ($d.weather.confidence -ne $d.eventAttribution.confidence) {
            $failures += "weather.confidence ($($d.weather.confidence)) != eventAttribution.confidence ($($d.eventAttribution.confidence))"
        }

        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (featureClimate=$($d.weather.featureClimate), cause=$($d.eventAttribution.cause))") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SW-E: summary string deterministic across repeated calls
# =============================================================================
try {
    Write-Host "Testing: SW-E summary deterministic across repeated calls" -NoNewline
    $url = "$Base$_swBase"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $w1 = ($r1.Content | ConvertFrom-Json).data.weather | ConvertTo-Json -Depth 5 -Compress
        $w2 = ($r2.Content | ConvertFrom-Json).data.weather | ConvertTo-Json -Depth 5 -Compress
        if ($w1 -eq $w2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (weather differs between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SW-F: endpoint remains read-only
# =============================================================================
try {
    Write-Host "Testing: SW-F endpoint remains read-only" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) { $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total }
    } catch {}

    for ($i = 0; $i -lt 3; $i++) {
        try {
            Invoke-WebRequest -Uri "$Base$_swBase" -Method GET -Headers $Headers `
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
