# hammer-feature-volatility.ps1 -- Feature Volatility Diagnostics
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/feature-volatility
#
# Self-contained setup: creates one KeywordTarget + 4 snapshots with the
# following feature progression (spec example):
#   snap0: featured_snippet
#   snap1: featured_snippet + people_also_ask  (entered: people_also_ask)
#   snap2: people_also_ask                     (exited:  featured_snippet)
#   snap3: video                               (entered: video, exited: people_also_ask)
#
# Expected transitions (3 total):
#   snap0->snap1: entered=[people_also_ask], exited=[]
#   snap1->snap2: entered=[],                exited=[featured_snippet]
#   snap2->snap3: entered=[video],           exited=[people_also_ask]
#
# mostVolatileFeatures expected:
#   featured_snippet:  1 change (exited once)
#   people_also_ask:   2 changes (entered once, exited once)
#   video:             1 change (entered once)
#   Sort: changes DESC, family ASC ->
#     people_also_ask (2), featured_snippet (1), video (1)
#
# All regex strings use single-quoted strings to avoid quoting issues.

Hammer-Section "FEATURE VOLATILITY TESTS"

$_fvBase   = "/api/seo/keyword-targets"
$_fvRunId  = (Get-Date).Ticks
$_fvQuery  = "fv-test-$_fvRunId"
$_fvKtId   = $null
$_fvSetupOk = $false

# =============================================================================
# Setup: create KeywordTarget + 4 snapshots
# =============================================================================

try {
    $rKw = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
        -Body (@{keywords=@($_fvQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing

    if ($rKw.StatusCode -eq 201) {
        $_fvKtId = (($rKw.Content | ConvertFrom-Json).data.targets |
            Where-Object { $_.query -eq $_fvQuery } | Select-Object -First 1).id
    }
} catch {}

if ($_fvKtId) {
    $t0 = (Get-Date).AddMinutes(-10).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t1 = (Get-Date).AddMinutes(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t2 = (Get-Date).AddMinutes(-4).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $t3 = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')

    $snapDefs = @(
        @{
            capturedAt = $t0
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="featured_snippet"; url="https://ex.com/fs1"; rank_absolute=1}
                    @{type="organic";          url="https://ex.com/o1"; rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t1
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="featured_snippet"; url="https://ex.com/fs1"; rank_absolute=1}
                    @{type="people_also_ask";  url="https://ex.com/paa"; rank_absolute=2}
                    @{type="organic";          url="https://ex.com/o1"; rank_absolute=3}
                )
            }
        }
        @{
            capturedAt = $t2
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="people_also_ask"; url="https://ex.com/paa"; rank_absolute=1}
                    @{type="organic";         url="https://ex.com/o1"; rank_absolute=2}
                )
            }
        }
        @{
            capturedAt = $t3
            aiStatus   = "absent"
            rawPayload = @{
                items = @(
                    @{type="video";   url="https://ex.com/vid"; rank_absolute=1}
                    @{type="organic"; url="https://ex.com/o1"; rank_absolute=2}
                )
            }
        }
    )

    $allCreated = $true
    foreach ($def in $snapDefs) {
        $body = @{
            query=$_fvQuery; locale="en-US"; device="desktop"
            capturedAt=$def.capturedAt; source="dataforseo"
            aiOverviewStatus=$def.aiStatus
            rawPayload=$def.rawPayload
        }
        try {
            $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($r.StatusCode -notin @(200,201)) { $allCreated = $false }
        } catch { $allCreated = $false }
    }
    $_fvSetupOk = $allCreated
}

# =============================================================================
# FV-A: 400 on invalid UUID for :id
# =============================================================================
try {
    Write-Host "Testing: FV-A 400 on invalid UUID for :id" -NoNewline
    $badIds = @("not-a-uuid", "1234", "00000000-0000-0000-0000-00000000000Z")
    $failures = @()
    foreach ($bid in $badIds) {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$bid/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -ne 400) { $failures += "$bid -> $($resp.StatusCode)" }
    }
    if ($failures.Count -eq 0) {
        Write-Host ("  PASS (all " + $badIds.Count + " invalid ids returned 400)") -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-B: 400 on invalid query params
# =============================================================================
try {
    Write-Host "Testing: FV-B 400 on invalid query params" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fvKtId)) {
        Write-Host "  SKIP (setup did not produce a KtId)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $cases = @(
            "windowDays=0",
            "windowDays=366",
            "windowDays=abc",
            "limitTransitions=0",
            "limitTransitions=201",
            "limitTransitions=abc"
        )
        $failures = @()
        foreach ($qs in $cases) {
            $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility?$qs" `
                -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -ne 400) { $failures += "$qs -> $($resp.StatusCode)" }
        }
        if ($failures.Count -eq 0) {
            Write-Host ("  PASS (all " + $cases.Count + " cases returned 400)") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL: " + ($failures -join "; ")) -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-C: 404 cross-project isolation
# =============================================================================
try {
    Write-Host "Testing: FV-C 404 cross-project isolation" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fvKtId)) {
        Write-Host "  SKIP (setup did not produce a KtId)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (OtherHeaders not configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS (cross-project returns 404)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (expected 404, got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-D: 200 + required top-level fields
# =============================================================================
try {
    Write-Host "Testing: FV-D 200 + required top-level fields" -NoNewline
    if (-not $_fvSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","query","locale","device","windowDays",
                          "snapshotCount","transitionCount","transitions","summary")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-E: transitions sorted capturedAt ASC (deterministic ordering)
# =============================================================================
try {
    Write-Host "Testing: FV-E transitions sorted capturedAt ASC" -NoNewline
    if (-not $_fvSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $txs = @(($resp.Content | ConvertFrom-Json).data.transitions)
            if ($txs.Count -lt 2) {
                Write-Host ("  SKIP (fewer than 2 transitions; cannot verify sort)") -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $fail = $false; $failMsg = ""
                for ($i = 0; $i -lt ($txs.Count - 1); $i++) {
                    $ta = $txs[$i].capturedAt
                    $tb = $txs[$i + 1].capturedAt
                    if ([string]$ta -gt [string]$tb) {
                        $fail = $true
                        $failMsg = "transitions[$i].capturedAt=$ta > transitions[$($i+1)].capturedAt=$tb"
                        break
                    }
                }
                if (-not $fail) {
                    Write-Host ("  PASS (" + $txs.Count + " transitions in ASC order)") -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-F: summary.mostVolatileFeatures sorted changes DESC, family ASC
# =============================================================================
try {
    Write-Host "Testing: FV-F summary sorted changes DESC, family ASC" -NoNewline
    if (-not $_fvSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $mvf = @(($resp.Content | ConvertFrom-Json).data.summary.mostVolatileFeatures)
            if ($mvf.Count -lt 2) {
                Write-Host ("  SKIP (fewer than 2 entries; cannot verify sort)") -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $fail = $false; $failMsg = ""
                for ($i = 0; $i -lt ($mvf.Count - 1); $i++) {
                    $ca = [int]$mvf[$i].changes
                    $cb = [int]$mvf[$i + 1].changes
                    if ($ca -lt $cb) {
                        $fail = $true
                        $failMsg = "mvf[$i].changes=$ca < mvf[$($i+1)].changes=$cb (must be DESC)"
                        break
                    }
                    if ($ca -eq $cb -and [string]$mvf[$i].family -gt [string]$mvf[$i+1].family) {
                        $fail = $true
                        $failMsg = "mvf[$i].family=$($mvf[$i].family) > mvf[$($i+1)].family=$($mvf[$($i+1)].family) at equal changes (must be ASC)"
                        break
                    }
                }
                if (-not $fail) {
                    Write-Host ("  PASS (" + $mvf.Count + " entries correctly sorted)") -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL ($failMsg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-G: known transitions detected (spec example progression)
# snap0->snap1: entered=[people_also_ask]
# snap1->snap2: exited=[featured_snippet]
# snap2->snap3: entered=[video], exited=[people_also_ask]
# =============================================================================
try {
    Write-Host "Testing: FV-G known transitions detected correctly" -NoNewline
    if (-not $_fvSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $txs = @(($resp.Content | ConvertFrom-Json).data.transitions)
            if ($txs.Count -ne 3) {
                Write-Host ("  FAIL (expected 3 transitions, got " + $txs.Count + ")") -ForegroundColor Red; Hammer-Record FAIL
            } else {
                $t0entered = @($txs[0].entered)
                $t0exited  = @($txs[0].exited)
                $t1entered = @($txs[1].entered)
                $t1exited  = @($txs[1].exited)
                $t2entered = @($txs[2].entered)
                $t2exited  = @($txs[2].exited)

                $ok = (
                    ($t0entered -contains "people_also_ask") -and ($t0exited.Count -eq 0) -and
                    ($t1entered.Count -eq 0) -and ($t1exited -contains "featured_snippet") -and
                    ($t2entered -contains "video") -and ($t2exited -contains "people_also_ask")
                )
                if ($ok) {
                    Write-Host "  PASS (all 3 transitions match expected)" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    $dbg = "tx0: entered=[$($t0entered -join ',')] exited=[$($t0exited -join ',')] | tx1: entered=[$($t1entered -join ',')] exited=[$($t1exited -join ',')] | tx2: entered=[$($t2entered -join ',')] exited=[$($t2exited -join ',')]"
                    Write-Host ("  FAIL ($dbg)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-H: empty transitions when all snapshots have identical feature sets
# Create a second KT with 3 snapshots all having the same features
# =============================================================================
try {
    Write-Host "Testing: FV-H zero transitions when feature set is stable" -NoNewline
    $_fvStableKtId   = $null
    $_fvStableSetupOk = $false

    $_fvStableQuery = "fv-stable-$_fvRunId"
    try {
        $rKw2 = Invoke-WebRequest -Uri "$Base/api/seo/keyword-research" -Method POST -Headers $Headers `
            -Body (@{keywords=@($_fvStableQuery);locale="en-US";device="desktop";confirm=$true} | ConvertTo-Json -Depth 5 -Compress) `
            -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rKw2.StatusCode -eq 201) {
            $_fvStableKtId = (($rKw2.Content | ConvertFrom-Json).data.targets |
                Where-Object { $_.query -eq $_fvStableQuery } | Select-Object -First 1).id
        }
    } catch {}

    if ($_fvStableKtId) {
        $stableTimes = @(
            (Get-Date).AddMinutes(-6).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            (Get-Date).AddMinutes(-4).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            (Get-Date).AddMinutes(-2).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        )
        $stablePayload = @{
            items = @(
                @{type="featured_snippet"; url="https://stable.com/fs"; rank_absolute=1}
                @{type="organic";          url="https://stable.com/o1"; rank_absolute=2}
            )
        }
        $stableOk = $true
        foreach ($ts in $stableTimes) {
            $body = @{
                query=$_fvStableQuery; locale="en-US"; device="desktop"
                capturedAt=$ts; source="dataforseo"; aiOverviewStatus="absent"
                rawPayload=$stablePayload
            }
            try {
                $r = Invoke-WebRequest -Uri "$Base/api/seo/serp-snapshots" -Method POST -Headers $Headers `
                    -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ContentType "application/json" `
                    -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($r.StatusCode -notin @(200,201)) { $stableOk = $false }
            } catch { $stableOk = $false }
        }
        $_fvStableSetupOk = $stableOk
    }

    if (-not $_fvStableSetupOk) {
        Write-Host "  SKIP (stable KT setup failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvStableKtId/feature-volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $txCount = [int]$d.transitionCount
            $txArr   = @($d.transitions).Count
            $mvfArr  = @($d.summary.mostVolatileFeatures).Count
            if ($txCount -eq 0 -and $txArr -eq 0 -and $mvfArr -eq 0) {
                Write-Host "  PASS (transitionCount=0, transitions=[], mostVolatileFeatures=[])" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (transitionCount=$txCount transitions=$txArr mvf=$mvfArr)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-I: determinism (two sequential calls yield identical response)
# =============================================================================
try {
    Write-Host "Testing: FV-I determinism (two calls identical)" -NoNewline
    if (-not $_fvSetupOk) {
        Write-Host "  SKIP (setup not complete)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base$_fvBase/$_fvKtId/feature-volatility"
        $r1 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 10 -Compress
            if ($d1 -eq $d2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (response bodies differ between calls)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# =============================================================================
# FV-J: POST rejected
# =============================================================================
try {
    Write-Host "Testing: FV-J POST rejected" -NoNewline
    if ([string]::IsNullOrWhiteSpace($_fvKtId)) {
        Write-Host "  SKIP (KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$_fvBase/$_fvKtId/feature-volatility" `
            -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -in @(404, 405)) {
            Write-Host ("  PASS (POST returned " + $resp.StatusCode + ")") -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (POST returned " + $resp.StatusCode + ", expected 404 or 405)") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
