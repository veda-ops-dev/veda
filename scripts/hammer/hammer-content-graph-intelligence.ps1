# hammer-content-graph-intelligence.ps1 — Content Graph Phase 2 Intelligence hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   - GET /api/content-graph/project-diagnostics returns 200
#   - Response envelope shape: data.projectId + data.diagnostics
#   - All five diagnostic sections present in response
#   - Required fields present in each section
#   - Deterministic: two sequential calls return identical results
#   - Project isolation: diagnostics scoped to requesting project
#   - POST rejected (method not allowed)
#   - Cross-project non-disclosure (gated on OtherHeaders)

Hammer-Section "CONTENT GRAPH PHASE 2 — PROJECT DIAGNOSTICS"

# CGI-1: GET returns 200 and valid envelope
$cgiDiagnostics = $null
try {
    Write-Host "Testing: CGI-1 GET /content-graph/project-diagnostics returns 200" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgiDiagnostics = ($resp.Content | ConvertFrom-Json).data } catch {}
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-2: Response has data.projectId
try {
    Write-Host "Testing: CGI-2 Response contains projectId" -NoNewline
    if ($null -eq $cgiDiagnostics) {
        Write-Host "  SKIP (no diagnostics response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (-not [string]::IsNullOrWhiteSpace($cgiDiagnostics.projectId)) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (projectId missing or empty)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-3: Response has data.diagnostics
try {
    Write-Host "Testing: CGI-3 Response contains diagnostics object" -NoNewline
    if ($null -eq $cgiDiagnostics) {
        Write-Host "  SKIP (no diagnostics response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($null -ne $cgiDiagnostics.diagnostics) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (diagnostics missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-4: topicCoverage section present with required fields
try {
    Write-Host "Testing: CGI-4 diagnostics.topicCoverage shape" -NoNewline
    $tc = $cgiDiagnostics.diagnostics.topicCoverage
    if ($null -eq $tc) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $tc.topicCount -and
        $null -ne $tc.pagesWithTopics -and
        $null -ne $tc.orphanTopics -and
        $null -ne $tc.topicFrequency
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in topicCoverage)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-5: entityCoverage section present with required fields
try {
    Write-Host "Testing: CGI-5 diagnostics.entityCoverage shape" -NoNewline
    $ec = $cgiDiagnostics.diagnostics.entityCoverage
    if ($null -eq $ec) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ec.entityCount -and
        $null -ne $ec.pagesWithEntities -and
        $null -ne $ec.entityFrequency
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in entityCoverage)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-6: internalAuthority section present with required fields
try {
    Write-Host "Testing: CGI-6 diagnostics.internalAuthority shape" -NoNewline
    $ia = $cgiDiagnostics.diagnostics.internalAuthority
    if ($null -eq $ia) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ia.isolatedPages -and
        $null -ne $ia.weakPages -and
        $null -ne $ia.strongestPages
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in internalAuthority)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-7: schemaCoverage section present with required fields
try {
    Write-Host "Testing: CGI-7 diagnostics.schemaCoverage shape" -NoNewline
    $sc = $cgiDiagnostics.diagnostics.schemaCoverage
    if ($null -eq $sc) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $sc.schemaTypes -and
        $null -ne $sc.pagesWithoutSchema
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in schemaCoverage)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-8: archetypeDistribution section present with required fields
try {
    Write-Host "Testing: CGI-8 diagnostics.archetypeDistribution shape" -NoNewline
    $ad = $cgiDiagnostics.diagnostics.archetypeDistribution
    if ($null -eq $ad) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ad.archetypes -and
        $null -ne $ad.pagesWithoutArchetype
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in archetypeDistribution)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-9: Determinism — two calls return identical diagnostics
try {
    Write-Host "Testing: CGI-9 GET project-diagnostics is deterministic" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data.diagnostics | ConvertTo-Json -Depth 10 -Compress
        $d2 = ($r2.Content | ConvertFrom-Json).data.diagnostics | ConvertTo-Json -Depth 10 -Compress
        if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-10: POST is method-not-allowed
try {
    Write-Host "Testing: CGI-10 POST /content-graph/project-diagnostics returns 405" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method POST -Headers $Headers -Body "{}" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 405) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 405)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-11: topicCoverage.topicCount is a non-negative integer
try {
    Write-Host "Testing: CGI-11 topicCoverage.topicCount is non-negative integer" -NoNewline
    $tc = $cgiDiagnostics.diagnostics.topicCoverage
    if ($null -eq $tc) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($tc.topicCount -is [int] -or $tc.topicCount -is [long] -or ($tc.topicCount -match '^\d+$')) {
        if ([int]$tc.topicCount -ge 0) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (topicCount is negative)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host "  FAIL (topicCount is not a number)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-12: entityCoverage.entityCount is a non-negative integer
try {
    Write-Host "Testing: CGI-12 entityCoverage.entityCount is non-negative integer" -NoNewline
    $ec = $cgiDiagnostics.diagnostics.entityCoverage
    if ($null -eq $ec) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ([int]$ec.entityCount -ge 0) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (entityCount invalid)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-13: archetypeDistribution.pagesWithoutArchetype is a non-negative integer
try {
    Write-Host "Testing: CGI-13 archetypeDistribution.pagesWithoutArchetype is non-negative" -NoNewline
    $ad = $cgiDiagnostics.diagnostics.archetypeDistribution
    if ($null -eq $ad) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ([int]$ad.pagesWithoutArchetype -ge 0) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (pagesWithoutArchetype invalid)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-14: topicFrequency entries have topicId and count fields
try {
    Write-Host "Testing: CGI-14 topicFrequency entries have topicId and count" -NoNewline
    $tf = $cgiDiagnostics.diagnostics.topicCoverage.topicFrequency
    if ($null -eq $tf) {
        Write-Host "  SKIP (topicCoverage not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($tf.Count -eq 0) {
        Write-Host "  PASS (empty array is valid)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        $allValid = $true
        foreach ($entry in $tf) {
            if ([string]::IsNullOrWhiteSpace($entry.topicId) -or $null -eq $entry.count) {
                $allValid = $false; break
            }
        }
        if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (topicFrequency entry missing topicId or count)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-15: strongestPages entries have pageId and inboundLinks fields
try {
    Write-Host "Testing: CGI-15 strongestPages entries have pageId and inboundLinks" -NoNewline
    $sp = $cgiDiagnostics.diagnostics.internalAuthority.strongestPages
    if ($null -eq $sp) {
        Write-Host "  SKIP (internalAuthority not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($sp.Count -eq 0) {
        Write-Host "  PASS (empty array is valid)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        $allValid = $true
        foreach ($entry in $sp) {
            if ([string]::IsNullOrWhiteSpace($entry.pageId) -or $null -eq $entry.inboundLinks) {
                $allValid = $false; break
            }
        }
        if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (strongestPages entry missing pageId or inboundLinks)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-16: schemaTypes entries have type and count fields
try {
    Write-Host "Testing: CGI-16 schemaTypes entries have type and count" -NoNewline
    $st = $cgiDiagnostics.diagnostics.schemaCoverage.schemaTypes
    if ($null -eq $st) {
        Write-Host "  SKIP (schemaCoverage not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($st.Count -eq 0) {
        Write-Host "  PASS (empty array is valid)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        $allValid = $true
        foreach ($entry in $st) {
            if ([string]::IsNullOrWhiteSpace($entry.type) -or $null -eq $entry.count) {
                $allValid = $false; break
            }
        }
        if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (schemaTypes entry missing type or count)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CGI-17: Cross-project isolation — OtherHeaders diagnostics differ from Headers diagnostics
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CGI-17 Diagnostics are project-scoped (cross-project isolation)" -NoNewline
        $r1 = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri "$Base/api/content-graph/project-diagnostics" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $p1 = ($r1.Content | ConvertFrom-Json).data.projectId
            $p2 = ($r2.Content | ConvertFrom-Json).data.projectId
            if ($p1 -ne $p2) { Write-Host "  PASS (different projectIds returned)" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (same projectId returned for both header sets)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CGI-17 Cross-project isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}
