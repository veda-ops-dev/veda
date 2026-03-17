# hammer-sil8-a3.ps1 -- SIL-8 A3 (Feature Transition Matrix)
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Endpoint: GET /api/seo/keyword-targets/:id/feature-transitions
#
# Response shape (spec-canonical):
#   keywordTargetId, query, locale, device, windowDays,
#   sampleSize, totalTransitions, distinctTransitionCount,
#   transitions: [ { fromFeatureSet: string[], toFeatureSet: string[], count: number } ],
#   computedAt
#
# Sum-check invariant: SUM(count) == sampleSize (every pair classified exactly once).
#
# Fixture dependency:
#   $s3KtId      -- SIL-3 KeywordTarget with >= 21 snapshots
#   $s7ZeroKtId  -- KeywordTarget with 0 snapshots (set in hammer-sil7.ps1)
#   $OtherHeaders -- second project headers (set in coordinator)
#
# Tests (A3-A through A3-M):
#   A3-A: 200 + required top-level fields present
#   A3-B: transitions is an array
#   A3-C: sampleSize >= 1 for snapshot-rich fixture
#   A3-D: sum-check -- SUM(count) == sampleSize
#   A3-E: totalTransitions == sampleSize (echoed field)
#   A3-F: determinism (two calls identical excluding computedAt)
#   A3-G: sort order -- count DESC, then fromKey ASC, then toKey ASC
#   A3-H: per-transition required fields (fromFeatureSet array, toFeatureSet array, count)
#   A3-I: fromFeatureSet and toFeatureSet are sorted ascending lexicographically
#   A3-J: windowDays=1 sampleSize <= no-window sampleSize
#   A3-K: invalid UUID -> 400
#   A3-L: windowDays out of range (0, 366) -> 400
#   A3-M: cross-project -> 404
#   A3-N: zero-snapshot fixture -> sampleSize=0, transitions=[]

Hammer-Section "SIL-8 A3 TESTS (FEATURE TRANSITION MATRIX)"

$a3Base = "/api/seo/keyword-targets"

# ── A3-A: 200 + required top-level fields ─────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions 200 + required top-level fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d     = ($resp.Content | ConvertFrom-Json).data
            $props = $d | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            $required = @("keywordTargetId","windowDays","sampleSize","totalTransitions",
                          "distinctTransitionCount","transitions","computedAt")
            $missing = $required | Where-Object { $props -notcontains $_ }
            if ($missing.Count -eq 0) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-B: transitions is an array ────────────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions transitions field is an array" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $val = ($resp.Content | ConvertFrom-Json).data.transitions
            $isArr = ($val -is [System.Array]) -or ($null -eq $val)
            if ($isArr) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (transitions is not an array)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-C: sampleSize >= 1 for snapshot-rich fixture ──────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions sampleSize >= 1 for snapshot-rich fixture" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $ss = [int]($resp.Content | ConvertFrom-Json).data.sampleSize
            if ($ss -ge 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $ss + ", expected >= 1 for s3KtId fixture)") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-D: sum-check SUM(count) == sampleSize ─────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions sum(count) == sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d        = ($resp.Content | ConvertFrom-Json).data
            $ss       = [int]$d.sampleSize
            $items    = @($d.transitions)
            $countSum = 0
            foreach ($item in $items) { $countSum += [int]$item.count }
            if ($countSum -eq $ss) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sum(count)=" + $countSum + " != sampleSize=" + $ss + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-E: totalTransitions == sampleSize ─────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions totalTransitions == sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d  = ($resp.Content | ConvertFrom-Json).data
            $ss = [int]$d.sampleSize
            $tt = [int]$d.totalTransitions
            if ($tt -eq $ss) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (totalTransitions=" + $tt + " != sampleSize=" + $ss + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-F: determinism ─────────────────────────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions deterministic (two calls identical, excluding computedAt)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $url = "$Base$a3Base/$s3KtId/feature-transitions"
        $r1  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2  = Invoke-WebRequest -Uri $url -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $d1 = ($r1.Content | ConvertFrom-Json).data
            $d2 = ($r2.Content | ConvertFrom-Json).data
            $ssMatch = ($d1.sampleSize -eq $d2.sampleSize)
            $t1 = ($d1.transitions | ConvertTo-Json -Depth 8 -Compress)
            $t2 = ($d2.transitions | ConvertTo-Json -Depth 8 -Compress)
            $tMatch = ($t1 -eq $t2)
            if ($ssMatch -and $tMatch) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host "  FAIL (transitions differ between two calls)" -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-G: sort order (count DESC, fromKey ASC, toKey ASC) ────────────────────
# fromKey = fromFeatureSet joined by comma; toKey = toFeatureSet joined by comma.
try {
    Write-Host "Testing: A3 /feature-transitions sort order (count DESC, fromKey ASC, toKey ASC)" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = @(($resp.Content | ConvertFrom-Json).data.transitions)
            if ($items.Count -lt 2) {
                Write-Host "  PASS (fewer than 2 transitions, sort trivially satisfied)" -ForegroundColor Green; Hammer-Record PASS
            } else {
                $sortOk = $true
                for ($i = 0; $i -lt $items.Count - 1; $i++) {
                    $cur  = $items[$i]
                    $nxt  = $items[$i + 1]
                    $cCur = [int]$cur.count
                    $cNxt = [int]$nxt.count
                    if ($cNxt -gt $cCur) { $sortOk = $false; break }
                    if ($cNxt -eq $cCur) {
                        # Derive fromKey / toKey by joining the feature-set arrays
                        $fkCur = if ($null -eq $cur.fromFeatureSet)  { "" } else { ($cur.fromFeatureSet  -join ",") }
                        $fkNxt = if ($null -eq $nxt.fromFeatureSet)  { "" } else { ($nxt.fromFeatureSet  -join ",") }
                        $cmpFk = [string]::Compare($fkCur, $fkNxt, [System.StringComparison]::Ordinal)
                        if ($cmpFk -gt 0) { $sortOk = $false; break }
                        if ($cmpFk -eq 0) {
                            $tkCur = if ($null -eq $cur.toFeatureSet) { "" } else { ($cur.toFeatureSet -join ",") }
                            $tkNxt = if ($null -eq $nxt.toFeatureSet) { "" } else { ($nxt.toFeatureSet -join ",") }
                            $cmpTk = [string]::Compare($tkCur, $tkNxt, [System.StringComparison]::Ordinal)
                            if ($cmpTk -gt 0) { $sortOk = $false; break }
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

# ── A3-H: per-transition required fields ─────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions per-transition required fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = @(($resp.Content | ConvertFrom-Json).data.transitions)
            if ($items.Count -eq 0) {
                Write-Host "  SKIP (no transitions, cannot check item shape)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $item    = $items[0]
                $iProps  = $item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $required = @("fromFeatureSet","toFeatureSet","count")
                $missing = $required | Where-Object { $iProps -notcontains $_ }
                if ($missing.Count -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host ("  FAIL (missing: " + ($missing -join ", ") + ")") -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-I: fromFeatureSet and toFeatureSet are sorted ascending ────────────────
try {
    Write-Host "Testing: A3 /feature-transitions fromFeatureSet and toFeatureSet sorted ascending" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $items = @(($resp.Content | ConvertFrom-Json).data.transitions)
            if ($items.Count -eq 0) {
                Write-Host "  SKIP (no transitions)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $sortOk = $true
                foreach ($item in $items) {
                    # Check fromFeatureSet sorted
                    $ffs = @($item.fromFeatureSet)
                    if ($ffs.Count -ge 2) {
                        $sorted = ($ffs | Sort-Object)
                        for ($j = 0; $j -lt $ffs.Count; $j++) {
                            if ($ffs[$j] -ne $sorted[$j]) { $sortOk = $false; break }
                        }
                    }
                    if (-not $sortOk) { break }
                    # Check toFeatureSet sorted
                    $tfs = @($item.toFeatureSet)
                    if ($tfs.Count -ge 2) {
                        $sorted = ($tfs | Sort-Object)
                        for ($j = 0; $j -lt $tfs.Count; $j++) {
                            if ($tfs[$j] -ne $sorted[$j]) { $sortOk = $false; break }
                        }
                    }
                    if (-not $sortOk) { break }
                }
                if ($sortOk) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else {
                    Write-Host "  FAIL (feature set not sorted ascending)" -ForegroundColor Red; Hammer-Record FAIL
                }
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-J: windowDays=1 sampleSize <= no-window sampleSize ────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions windowDays=1 sampleSize <= no-window sampleSize" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $rAll = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $rW1  = Invoke-WebRequest -Uri ($Base + $a3Base + "/" + $s3KtId + "/feature-transitions?windowDays=1") `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rAll.StatusCode -eq 200 -and $rW1.StatusCode -eq 200) {
            $ssAll = [int]($rAll.Content | ConvertFrom-Json).data.sampleSize
            $ssW1  = [int]($rW1.Content  | ConvertFrom-Json).data.sampleSize
            if ($ssW1 -le $ssAll) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (windowDays=1 sampleSize=" + $ssW1 + " > full sampleSize=" + $ssAll + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (status=" + $rAll.StatusCode + "/" + $rW1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-K: invalid UUID -> 400 ────────────────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions 400 on invalid UUID" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base$a3Base/not-a-uuid/feature-transitions" `
        -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-L: windowDays out of range -> 400 ─────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions 400 on windowDays=0" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri ($Base + $a3Base + "/" + $s3KtId + "/feature-transitions?windowDays=0") `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

try {
    Write-Host "Testing: A3 /feature-transitions 400 on windowDays=366" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId)) {
        Write-Host "  SKIP (s3KtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri ($Base + $a3Base + "/" + $s3KtId + "/feature-transitions?windowDays=366") `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-M: cross-project -> 404 ───────────────────────────────────────────────
try {
    Write-Host "Testing: A3 /feature-transitions 404 on cross-project access" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s3KtId) -or $OtherHeaders.Count -eq 0) {
        Write-Host "  SKIP (s3KtId or OtherHeaders not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s3KtId/feature-transitions" `
            -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── A3-N: zero-snapshot fixture -> sampleSize=0, transitions=[] ──────────────
try {
    Write-Host "Testing: A3 /feature-transitions zero-snapshot fixture -> sampleSize=0, transitions=[]" -NoNewline
    if ([string]::IsNullOrWhiteSpace($s7ZeroKtId)) {
        Write-Host "  SKIP (s7ZeroKtId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $resp = Invoke-WebRequest -Uri "$Base$a3Base/$s7ZeroKtId/feature-transitions" `
            -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $d    = ($resp.Content | ConvertFrom-Json).data
            $ssOk = ([int]$d.sampleSize -eq 0)
            $trOk = ($null -eq $d.transitions -or @($d.transitions).Count -eq 0)
            if ($ssOk -and $trOk) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else {
                Write-Host ("  FAIL (sampleSize=" + $d.sampleSize + " transitions.Count=" + @($d.transitions).Count + ")") -ForegroundColor Red; Hammer-Record FAIL
            }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
