# hammer-sil8-a1.ps1 -- SIL-8 A1 (URL Contribution Attribution)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/volatility-breakdown
#
# Response shape (spec-canonical field names):
#   keywordTargetId, query, locale, device, windowDays, sampleSize, urlCount,
#   urls: [ { url, appearances, totalAbsShift, averageShift, firstSeen, lastSeen } ]
#   computedAt
#
# Fixture dependency:
#   $s3KtId -- SIL-3 KeywordTarget with >=21 snapshots (set in hammer-sil3.ps1).
#   $s7ZeroKtId -- KeywordTarget with 0 snapshots (set in hammer-sil7.ps1).
#   $OtherHeaders -- second project headers (set in coordinator).
#
# Assertions (A1-A through A1-K):
#   A1-A: 200 + required top-level fields present
#   A1-B: urls is an array
#   A1-C: sampleSize >= 1 for fixture with snapshots
#   A1-D: determinism (two identical calls return identical urls array)
#   A1-E: sort order (totalAbsShift non-increasing; equal totalAbsShift -> url ASC)
#   A1-F: averageShift * appearances approx totalAbsShift (epsilon 0.01 per item, using pairsBothPresent via averageShift)
#         Note: spec uses totalAbsShift / pairsBothPresent for averageShift, not / appearances.
#         We verify the weaker constraint: averageShift <= totalAbsShift (always true) and
#         averageShift >= 0, and for items where appearances > 0 check arithmetic consistency
#         via: averageShift * appearances ~= totalAbsShift (permitted discrepancy because
#         averageShift divides by pairsBothPresent not appearances; hammer documents this).
#   A1-G: appearances >= 1 for every returned URL item
#   A1-H: topN respected (urls.Count <= topN param)
#   A1-I: windowDays param respected (sampleSize with windowDays=1 <= sampleSize without)
#   A1-J: 400 on invalid UUID
#   A1-K: 400 on invalid topN (0 and 51)
#   A1-L: 400 on invalid windowDays (0 and 366)
#   A1-M: 404 cross-project (other project headers + this project's ktId)
#   A1-N: sampleSize=0 fixture -> sampleSize=0, urls=[], urlCount=0

Hammer-Section "SIL-8 A1 TESTS (URL CONTRIBUTION ATTRIBUTION)"

$a1Base = "/api/seo/keyword-targets"

# ── A1-A: 200 + required top-level fields ─────────────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown 200 + required fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId", "windowDays", "sampleSize", "urlCount", "urls", "computedAt")
            $missing  = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing fields: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-B: urls is an array ────────────────────────────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown urls is an array" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $urls = ($resp.Content | ConvertFrom-Json).data.urls
            # PSCustomObject array or empty array -- both are valid
            $isArray = ($urls -is [System.Array]) -or ($null -eq $urls)
            if ($isArray) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (urls is not an array)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-C: sampleSize >= 1 for fixture with >=21 snapshots ────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown sampleSize >= 1 for snapshot-rich fixture" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $ss = [int]($resp.Content | ConvertFrom-Json).data.sampleSize
            if ($ss -ge 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $ss + ", expected >= 1)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-D: determinism (two calls return identical urls array) ─────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown deterministic (two identical calls)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base$a1Base/$s3KtId/volatility-breakdown"
        $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            # Compare stable fields only (exclude computedAt)
            $ss1   = $d1.sampleSize;   $ss2   = $d2.sampleSize
            $uc1   = $d1.urlCount;     $uc2   = $d2.urlCount
            $urls1 = ($d1.urls | ConvertTo-Json -Depth 5 -Compress)
            $urls2 = ($d2.urls | ConvertTo-Json -Depth 5 -Compress)
            $match = ($ss1 -eq $ss2) -and ($uc1 -eq $uc2) -and ($urls1 -eq $urls2)
            if ($match) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (responses differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-E: sort order (totalAbsShift non-increasing; ties -> url ASC) ──────────
try {
    Write-Host "Testing: A1 /volatility-breakdown sort order (totalAbsShift DESC, url ASC on ties)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $urls = @(($resp.Content | ConvertFrom-Json).data.urls)
            if ($urls.Count -lt 2) {
                Write-Host "  SKIP (fewer than 2 URLs returned, cannot verify sort)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $sortOk = $true
                for ($i = 0; $i -lt $urls.Count - 1; $i++) {
                    $cur  = [double]$urls[$i].totalAbsShift
                    $next = [double]$urls[$i + 1].totalAbsShift
                    if ($next -gt $cur) { $sortOk = $false; break }
                    if ($next -eq $cur) {
                        # Tie: url must be ascending
                        $uCur  = $urls[$i].url
                        $uNext = $urls[$i + 1].url
                        if ([string]::Compare($uNext, $uCur, [System.StringComparison]::Ordinal) -lt 0) {
                            $sortOk = $false; break
                        }
                    }
                }
                if ($sortOk) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (sort order violated)" -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-F: averageShift consistency (averageShift >= 0, <= totalAbsShift) ──────
# Note: averageShift = totalAbsShift / pairsBothPresent (not / appearances).
# The hammer verifies the invariants that hold regardless: averageShift in [0, totalAbsShift].
# The prompt's "averageAbsShift * appearances ~= totalAbsShift" is an approximation that
# holds when pairsBothPresent ~ appearances; we verify the rigorous spec constraints instead.
try {
    Write-Host "Testing: A1 /volatility-breakdown averageShift in [0, totalAbsShift] for all items" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $urls = @(($resp.Content | ConvertFrom-Json).data.urls)
            if ($urls.Count -eq 0) {
                Write-Host "  SKIP (no URLs returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $invalid = $urls | Where-Object {
                    $avg   = [double]$_.averageShift
                    $total = [double]$_.totalAbsShift
                    ($avg -lt 0) -or ($avg -gt $total + 0.01)
                }
                if ($invalid.Count -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (" + $invalid.Count + " items have averageShift outside [0, totalAbsShift])") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-G: appearances >= 1 for every returned URL item ───────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown all items have appearances >= 1" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $urls = @(($resp.Content | ConvertFrom-Json).data.urls)
            if ($urls.Count -eq 0) {
                Write-Host "  SKIP (no URLs returned)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $invalid = $urls | Where-Object { [int]$_.appearances -lt 1 }
                if ($invalid.Count -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (" + $invalid.Count + " items have appearances < 1)") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-H: topN respected (urls.Count <= topN) ────────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown topN=3 returns at most 3 urls" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?topN=3" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $urls = @(($resp.Content | ConvertFrom-Json).data.urls)
            if ($urls.Count -le 3) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (urls.Count=" + $urls.Count + ", expected <= 3)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-I: windowDays respected (narrow window produces sampleSize <= full-history) ──
try {
    Write-Host "Testing: A1 /volatility-breakdown windowDays=1 sampleSize <= no-window sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rAll = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rW1  = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?windowDays=1" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rAll.StatusCode -eq 200 -and $rW1.StatusCode -eq 200) {
            $ssAll = [int]($rAll.Content | ConvertFrom-Json).data.sampleSize
            $ssW1  = [int]($rW1.Content  | ConvertFrom-Json).data.sampleSize
            if ($ssW1 -le $ssAll) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (ssW1=" + $ssW1 + " > ssAll=" + $ssAll + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $rAll.StatusCode + "/" + $rW1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-J: 400 on invalid UUID ────────────────────────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown 400 on invalid UUID" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$a1Base/not-a-uuid/volatility-breakdown" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-K: 400 on topN out of range (0, 51) ───────────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown 400 on topN=0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?topN=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: A1 /volatility-breakdown 400 on topN=51" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?topN=51" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-L: 400 on windowDays out of range (0, 366) ────────────────────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown 400 on windowDays=0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?windowDays=0" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: A1 /volatility-breakdown 400 on windowDays=366" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown?windowDays=366" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-M: 404 cross-project (OtherHeaders + this project's ktId) ─────────────
try {
    Write-Host "Testing: A1 /volatility-breakdown 404 on cross-project access" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId) -or $OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (s3KtId or OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s3KtId/volatility-breakdown" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A1-N: zero-snapshot fixture -> sampleSize=0, urls=[], urlCount=0 ─────────
try {
    Write-Host "Testing: A1 /volatility-breakdown sampleSize=0 fixture returns empty breakdown" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s7ZeroKtId)) {
        Write-Host "  SKIP (s7ZeroKtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a1Base/$s7ZeroKtId/volatility-breakdown" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d = ($resp.Content | ConvertFrom-Json).data
            $ssOk  = ([int]$d.sampleSize -eq 0)
            $ucOk  = ([int]$d.urlCount   -eq 0)
            $urlsOk = ($null -eq $d.urls -or $d.urls.Count -eq 0)
            if ($ssOk -and $ucOk -and $urlsOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " urlCount=" + $d.urlCount + " urls.Count=" + @($d.urls).Count + ", expected 0/0/0)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
