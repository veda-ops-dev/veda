# hammer-sil8.ps1 — SIL-8 (Deep Diagnostics + Operator Decision Tooling)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# B1 — Volatility Regime Classification
#
# Regime boundary mapping (exact, from SIL-8 spec):
#   calm:     0.00 <= score <= 20.00
#   shifting: 20.00 < score <= 50.00
#   unstable: 50.00 < score <= 75.00
#   chaotic:  score > 75.00
#
# Boundary synthesis approach:
#   Direct score synthesis via DB is not done here (would require schema writes).
#   Instead:
#   1. Use the existing SIL-3 fixture (s3KtId, sampleSize >= 20) to assert field
#      presence, enum validity, and determinism.
#   2. Assert that the observed score and regime are consistent with the spec
#      boundary table — i.e. the regime returned is exactly the one the spec
#      mandates for the observed score.
#   3. The sampleSize=0 case is covered: score=0.00 must map to "calm".
#   This gives deterministic boundary verification without new endpoints or fixtures.
#
# Hammer assertions:
#   B1-A: volatilityRegime present on /volatility
#   B1-B: enum validity on /volatility
#   B1-C: score-regime consistency on /volatility (observed score → expected regime)
#   B1-D: score=0.00 → calm (sampleSize=0 keyword fixture)
#   B1-E: determinism on /volatility
#   B1-F: volatilityRegime present on /volatility-alerts item
#   B1-G: enum validity on /volatility-alerts item
#   B1-H: score-regime consistency on /volatility-alerts (first item)
#   B1-I: determinism on /volatility-alerts

Hammer-Section "SIL-8 B1 TESTS (VOLATILITY REGIME CLASSIFICATION)"

# Helper: map a score to the expected regime per spec boundary table.
function Get-ExpectedRegime([double]$score) {
    if ($score -le 20.00) { return "calm" }
    if ($score -le 50.00) { return "shifting" }
    if ($score -le 75.00) { return "unstable" }
    return "chaotic"
}

$b1ValidRegimes = @("calm", "shifting", "unstable", "chaotic")

# ── B1-A: volatilityRegime present on /volatility ─────────────────────────────
try {
    Write-Host "Testing: B1 /volatility has volatilityRegime field" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($props -contains "volatilityRegime") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (volatilityRegime field missing)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-B: enum validity on /volatility ────────────────────────────────────────
try {
    Write-Host "Testing: B1 /volatility volatilityRegime is valid enum value" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $regime = ($resp.Content | ConvertFrom-Json).data.volatilityRegime
            if ($b1ValidRegimes -contains $regime) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (regime='" + $regime + "' not in valid set)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-C: score-regime consistency on /volatility ─────────────────────────────
# The regime returned must be exactly the one the spec mandates for the observed score.
try {
    Write-Host "Testing: B1 /volatility regime consistent with observed volatilityScore" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s3KtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d              = ($resp.Content | ConvertFrom-Json).data
            $score          = [double]$d.volatilityScore
            $actualRegime   = $d.volatilityRegime
            $expectedRegime = Get-ExpectedRegime $score
            if ($actualRegime -eq $expectedRegime) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (score=" + $score + " regime='" + $actualRegime + "' expected='" + $expectedRegime + "')") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-D: score=0.00 → calm (sampleSize=0 keyword from SIL-7 zero fixture) ───
# Reuses $s7ZeroKtId created in hammer-sil7.ps1 (no snapshots → sampleSize=0 → score=0.00).
try {
    Write-Host "Testing: B1 /volatility score=0.00 (sampleSize=0) -> regime=calm" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s7ZeroKtId)) {
        Write-Host "  SKIP (s7ZeroKtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/seo/keyword-targets/$s7ZeroKtId/volatility" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            # score=0.00 is on the calm boundary (0.00 <= 20.00) → calm
            $scoreOk  = ([double]$d.volatilityScore -eq 0.00)
            $regimeOk = ($d.volatilityRegime -eq "calm")
            if ($scoreOk -and $regimeOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (score=" + $d.volatilityScore + " regime='" + $d.volatilityRegime + "', expected 0.00/calm)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-E: determinism on /volatility ──────────────────────────────────────────
try {
    Write-Host "Testing: B1 /volatility volatilityRegime deterministic (two calls match)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base/api/seo/keyword-targets/$s3KtId/volatility"
        $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $reg1 = ($r1.Content | ConvertFrom-Json).data.volatilityRegime
            $reg2 = ($r2.Content | ConvertFrom-Json).data.volatilityRegime
            if ($reg1 -eq $reg2) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (regime1='" + $reg1 + "' regime2='" + $reg2 + "')") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-F: volatilityRegime present on /volatility-alerts items ────────────────
try {
    Write-Host "Testing: B1 /volatility-alerts items have volatilityRegime field" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $d = ($resp.Content | ConvertFrom-Json).data
        if ($d.items -and $d.items.Count -gt 0) {
            $iProps = $d.items[0] | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            if ($iProps -contains "volatilityRegime") {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (volatilityRegime field missing from alert item)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-G: enum validity on /volatility-alerts ─────────────────────────────────
try {
    Write-Host "Testing: B1 /volatility-alerts all items have valid volatilityRegime" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary&limit=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = ($resp.Content | ConvertFrom-Json).data.items
        if ($items -and $items.Count -gt 0) {
            $invalid = $items | Where-Object { $b1ValidRegimes -notcontains $_.volatilityRegime }
            if ($invalid.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (" + $invalid.Count + " items have invalid regime)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-H: score-regime consistency on /volatility-alerts (all returned items) ─
try {
    Write-Host "Testing: B1 /volatility-alerts all items regime consistent with score" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary&limit=50" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        $items = ($resp.Content | ConvertFrom-Json).data.items
        if ($items -and $items.Count -gt 0) {
            $mismatch = $items | Where-Object {
                $expected = Get-ExpectedRegime ([double]$_.volatilityScore)
                $_.volatilityRegime -ne $expected
            }
            if ($mismatch.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                $first = $mismatch[0]
                Write-Host ("  FAIL (" + $mismatch.Count + " mismatches; first: score=" + $first.volatilityScore + " regime='" + $first.volatilityRegime + "' expected='" + (Get-ExpectedRegime ([double]$first.volatilityScore)) + "')") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── B1-I: determinism on /volatility-alerts ───────────────────────────────────
try {
    Write-Host "Testing: B1 /volatility-alerts volatilityRegime deterministic (two calls match)" -NoNewline
    $url = "$Base/api/seo/volatility-alerts?alertThreshold=0&minMaturity=preliminary&limit=1"
    $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data
        $d2 = ($r2.Content | ConvertFrom-Json).data
        if ($d1.items -and $d1.items.Count -gt 0 -and $d2.items -and $d2.items.Count -gt 0) {
            $match = ($d1.items[0].volatilityRegime -eq $d2.items[0].volatilityRegime)
            if ($match) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (regime1='" + $d1.items[0].volatilityRegime + "' regime2='" + $d2.items[0].volatilityRegime + "')") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else {
            Write-Host "  SKIP (no items at threshold=0)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
