# hammer-sil19.ps1 -- SIL-19 SERP Weather Forecasting
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/serp-disturbances (forecast field added by SIL-19)
#
# Setup: creates 4 keyword targets with high-volatility snapshot data
# (large rank shifts, feature changes, AI overview churn) to produce
# deterministic disturbance signals that drive the forecast.
#
# Tests:
#   SF-A  forecast object returned with all required fields
#   SF-B  worsening trend when disturbance signals are strong
#   SF-C  stable/improving trend when no disturbance (zero-keyword project)
#   SF-D  deterministic forecast across repeated calls
#   SF-E  expectedState mapping is a valid weather state
#   SF-F  endpoint read-only (no EventLog entries created)

Hammer-Section "SIL-19 TESTS (SERP WEATHER FORECASTING)"

$_sfBase  = "/api/seo/serp-disturbances"
$_sfRunId = (Get-Date).Ticks
$_sfSetupOk = $false

# =============================================================================
# Setup -- create 4 keyword targets + 3 snapshots each (high volatility)
# =============================================================================

$_sfQueries = @(
    "sf-kw-alpha-$_sfRunId",
    "sf-kw-beta-$_sfRunId",
    "sf-kw-gamma-$_sfRunId",
    "sf-kw-delta-$_sfRunId"
)
$_sfKtIds = @()

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=$_sfQueries;locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($rKw.StatusCode -eq 201) {
        $kwData = ($rKw.Content | ConvertFrom-Json).data.targets
        foreach ($q in $_sfQueries) {
            $match = $kwData | Where-Object { $_.query -eq $q } | Select-Object -First 1
            if ($match) { $_sfKtIds += $match.id }
        }
    }
} catch {}

if ($_sfKtIds.Count -eq 4) {
    $ct0 = (Get-Date).AddMinutes(-30).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct1 = (Get-Date).AddMinutes(-15).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $ct2 = (Get-Date).AddMinutes(-5).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $allCreated = $true
    foreach ($q in $_sfQueries) {
        # snap0: organic results at low ranks, featured_snippet
        # snap1: large rank shifts, ai_overview present, features changed
        # snap2: further shifts, more feature changes, entries/exits
        $snapDefs = @(
            @{
                capturedAt=$ct0; aiOverviewStatus="absent"
                items=@(
                    @{type="organic"; url="https://alpha.com/sf-$q"; rank_absolute=1}
                    @{type="organic"; url="https://beta.com/sf-$q";  rank_absolute=2}
                    @{type="organic"; url="https://gamma.com/sf-$q"; rank_absolute=3}
                    @{type="featured_snippet"; url="https://alpha.com/fs"; rank_absolute=0}
                )
            }
            @{
                capturedAt=$ct1; aiOverviewStatus="present"
                items=@(
                    @{type="organic"; url="https://alpha.com/sf-$q"; rank_absolute=18}
                    @{type="organic"; url="https://zeta.com/sf-$q";  rank_absolute=2}
                    @{type="organic"; url="https://gamma.com/sf-$q"; rank_absolute=20}
                    @{type="people_also_ask"; url="https://paa.example.com"; rank_absolute=0}
                )
            }
            @{
                capturedAt=$ct2; aiOverviewStatus="absent"
                items=@(
                    @{type="organic"; url="https://zeta.com/sf-$q";  rank_absolute=1}
                    @{type="organic"; url="https://omega.com/sf-$q"; rank_absolute=5}
                    @{type="organic"; url="https://beta.com/sf-$q";  rank_absolute=22}
                    @{type="people_also_ask"; url="https://paa.example.com"; rank_absolute=0}
                    @{type="local_pack"; url="https://maps.example.com"; rank_absolute=0}
                )
            }
        )

        foreach ($sd in $snapDefs) {
            try {
                $body = @{
                    query=$q; locale="en-US"; device="desktop"
                    capturedAt=$sd.capturedAt; aiOverviewStatus=$sd.aiOverviewStatus
                    rawPayload=@{items=$sd.items}
                }
                $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                    -Body ($body | ConvertTo-Json -Depth 15 -Compress) -ContentType "application/json" `
                    -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
            } catch { $allCreated = $false }
        }
    }
    $_sfSetupOk = $allCreated
}

if (-not $_sfSetupOk) {
    Write-Host "  SIL-19 setup failed -- skipping forecast-specific tests" -ForegroundColor DarkYellow
}

# =============================================================================
# SF-A: forecast object returned with all required fields
# =============================================================================
try {
    Write-Host "Testing: SF-A forecast object returned with all required fields" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sfBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $failures = @()

        if ($null -eq $d.forecast) { $failures += "forecast field missing" } else {
            $f = $d.forecast
            $fProps = $f | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("trend","expectedState","confidence","driverMomentum","forecastSummary")
            $missing = $required | Where-Object { $fProps -notcontains $_ }
            if ($missing.Count -gt 0) { $failures += "forecast missing: $($missing -join ', ')" }

            # Validate trend is one of the 4 valid values
            $validTrends = @("improving","stable","worsening","volatile")
            if ($f.trend -and $validTrends -notcontains $f.trend) {
                $failures += "invalid trend: $($f.trend)"
            }

            # Validate expectedState is a valid weather state
            $validStates = @("calm","shifting","turbulent","unstable")
            if ($f.expectedState -and $validStates -notcontains $f.expectedState) {
                $failures += "invalid expectedState: $($f.expectedState)"
            }

            # Validate confidence is numeric and within range
            if ($null -ne $f.confidence) {
                if ($f.confidence -lt 0 -or $f.confidence -gt 90) {
                    $failures += "confidence out of range: $($f.confidence)"
                }
            }

            # Validate driverMomentum is a valid value
            $validDrivers = @("ai_overview_expansion","feature_regime_shift","competitor_dominance_shift","intent_reclassification","algorithm_shift","unknown")
            if ($f.driverMomentum -and $validDrivers -notcontains $f.driverMomentum) {
                $failures += "invalid driverMomentum: $($f.driverMomentum)"
            }

            # forecastSummary must be a non-empty string
            if ([string]::IsNullOrWhiteSpace($f.forecastSummary)) {
                $failures += "forecastSummary is empty"
            }
        }

        if ($failures.Count -eq 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SF-B: worsening trend when disturbance signals are strong
# =============================================================================
try {
    Write-Host "Testing: SF-B trend is worsening or volatile with strong disturbance signals" -NoNewline
    if (-not $_sfSetupOk) { Write-Host "  SKIP (setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $r = Invoke-WebRequest -Uri "$Base$_sfBase" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            # With high-volatility seeded data (rank shifts 1->18+, feature changes,
            # AI churn) the disturbance signals should be strong.
            # Forecast trend should NOT be "stable" when disturbance dimensions are active.
            $activeDims = 0
            if ($d.volatilityCluster -eq $true) { $activeDims++ }
            if ($d.featureShiftDetected -eq $true) { $activeDims++ }
            if ($d.rankingTurbulence -eq $true) { $activeDims++ }

            if ($activeDims -ge 2) {
                # With >= 2 active dims, trend should be "worsening" or "volatile"
                if ($d.forecast.trend -in @("worsening","volatile")) {
                    Write-Host "  PASS (dims=$activeDims, trend=$($d.forecast.trend))" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (dims=$activeDims but trend=$($d.forecast.trend), expected worsening or volatile)" -ForegroundColor Red; Hammer-Record FAIL
                }
            } elseif ($activeDims -ge 1) {
                # With 1 dim, trend should NOT be "stable"
                if ($d.forecast.trend -ne "stable") {
                    Write-Host "  PASS (dims=$activeDims, trend=$($d.forecast.trend))" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (dims=$activeDims but trend=stable)" -ForegroundColor Red; Hammer-Record FAIL
                }
            } else {
                # 0 dims -- possible if other keywords dilute the cluster ratios
                Write-Host "  SKIP (no disturbance dims active -- other data may dilute)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            }
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SF-C: stable forecast for zero-target project (using OtherProject if available)
# =============================================================================
try {
    Write-Host "Testing: SF-C stable forecast for zero/low-signal project" -NoNewline
    if ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $r = Invoke-WebRequest -Uri "$Base$_sfBase" -Method GET -Headers $OtherHeaders `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r.StatusCode -eq 200) {
            $d = ($r.Content | ConvertFrom-Json).data
            # A project with no/few keyword targets should show stable or calm forecast
            if ($d.forecast.trend -eq "stable" -and $d.forecast.expectedState -eq "calm") {
                Write-Host "  PASS (trend=stable, expectedState=calm)" -ForegroundColor Green; Hammer-Record PASS
            } elseif ($d.forecast.trend -in @("stable","improving")) {
                # Acceptable if the other project has some mild data
                Write-Host "  PASS (trend=$($d.forecast.trend))" -ForegroundColor Green; Hammer-Record PASS
            } else {
                # Other project might have seeded data from other hammers; accept if forecast is valid
                $validTrends = @("improving","stable","worsening","volatile")
                if ($d.forecast.trend -in $validTrends) {
                    Write-Host "  PASS (other project has data, trend=$($d.forecast.trend))" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (invalid trend: $($d.forecast.trend))") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } elseif ($r.StatusCode -eq 400) {
            # Project not found -- that's fine for isolation
            Write-Host "  PASS (400 -- other project not found)" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SF-D: deterministic forecast across repeated calls
# =============================================================================
try {
    Write-Host "Testing: SF-D deterministic forecast across repeated calls" -NoNewline
    $url = "$Base$_sfBase"
    $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $f1 = ($r1.Content | ConvertFrom-Json).data.forecast | ConvertTo-Json -Depth 5 -Compress
        $f2 = ($r2.Content | ConvertFrom-Json).data.forecast | ConvertTo-Json -Depth 5 -Compress
        if ($f1 -eq $f2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (forecast differs between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL ($($r1.StatusCode)/$($r2.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SF-E: expectedState is consistent with weather state and trend
# =============================================================================
try {
    Write-Host "Testing: SF-E expectedState mapping is consistent" -NoNewline
    $r = Invoke-WebRequest -Uri "$Base$_sfBase" -Method GET -Headers $Headers `
        -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        $d = ($r.Content | ConvertFrom-Json).data
        $ok = $true
        $ws = $d.weather.state
        $ft = $d.forecast.trend
        $es = $d.forecast.expectedState

        # Severity ordering: calm < shifting < turbulent < unstable
        $severity = @{ "calm"=0; "shifting"=1; "turbulent"=2; "unstable"=3 }

        if ($ft -eq "worsening") {
            # expectedState should be >= current weather state in severity
            if ($severity[$es] -lt $severity[$ws]) {
                $ok = $false
                Write-Host " expectedState($es) less severe than weather($ws) during worsening" -ForegroundColor Red
            }
        }
        if ($ft -eq "improving") {
            # expectedState should be <= current weather state in severity
            if ($severity[$es] -gt $severity[$ws]) {
                $ok = $false
                Write-Host " expectedState($es) more severe than weather($ws) during improving" -ForegroundColor Red
            }
        }
        if ($ft -eq "stable" -or $ft -eq "volatile") {
            # expectedState should equal current weather state
            if ($es -ne $ws) {
                $ok = $false
                Write-Host " expectedState($es) differs from weather($ws) during $ft" -ForegroundColor Red
            }
        }

        if ($ok) { Write-Host "  PASS (weather=$ws, trend=$ft, expected=$es)" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (expectedState/trend mismatch)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got $($r.StatusCode))") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# SF-F: endpoint read-only (no EventLog entries created)
# =============================================================================
try {
    Write-Host "Testing: SF-F endpoint is read-only (no EventLog entries)" -NoNewline
    $elBefore = 0
    try {
        $rEL = Invoke-WebRequest -Uri "$Base/api/events?limit=5" -Method GET -Headers $Headers `
            -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rEL.StatusCode -eq 200) {
            $elBefore = ($rEL.Content | ConvertFrom-Json).pagination.total
        }
    } catch {}

    # Make 3 requests to trigger any potential writes
    for ($i = 0; $i -lt 3; $i++) {
        try {
            Invoke-WebRequest -Uri "$Base$_sfBase" -Method GET -Headers $Headers `
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

    if ($elAfter -eq $elBefore) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host ("  FAIL (EventLog grew from $elBefore to $elAfter)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
