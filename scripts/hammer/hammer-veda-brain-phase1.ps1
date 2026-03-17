# hammer-veda-brain-phase1.ps1 — VEDA Brain Phase 1 Diagnostics hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   - GET /api/veda-brain/project-diagnostics returns 200
#   - Response envelope: data.projectId + data.diagnostics
#   - All seven diagnostic sections present
#   - Required fields in each section
#   - Deterministic: two calls return identical results
#   - POST rejected (405)
#   - Project isolation (cross-project non-disclosure)
#   - Keyword-page mapping shape
#   - Readiness classification shape

Hammer-Section "VEDA BRAIN PHASE 1 — PROJECT DIAGNOSTICS"

# VB-1: GET returns 200 and valid envelope
$vbDiag = $null
try {
    Write-Host "Testing: VB-1 GET /veda-brain/project-diagnostics returns 200" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $vbDiag = ($resp.Content | ConvertFrom-Json).data } catch {}
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-2: Response has data.projectId
try {
    Write-Host "Testing: VB-2 Response contains projectId" -NoNewline
    if ($null -eq $vbDiag) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (-not [string]::IsNullOrWhiteSpace($vbDiag.projectId)) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (projectId missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-3: Response has data.diagnostics
try {
    Write-Host "Testing: VB-3 Response contains diagnostics object" -NoNewline
    if ($null -eq $vbDiag) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($null -ne $vbDiag.diagnostics) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (diagnostics missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-4: keywordPageMapping section present with required fields
try {
    Write-Host "Testing: VB-4 diagnostics.keywordPageMapping shape" -NoNewline
    $kpm = $vbDiag.diagnostics.keywordPageMapping
    if ($null -eq $kpm) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $kpm.mappings -and
        $null -ne $kpm.unmappedKeywords -and
        $null -ne $kpm.weakMappings -and
        $null -ne $kpm.ambiguousMappings -and
        $null -ne $kpm.summary
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in keywordPageMapping)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-5: keywordPageMapping.summary has required counters
try {
    Write-Host "Testing: VB-5 keywordPageMapping.summary counters" -NoNewline
    $s = $vbDiag.diagnostics.keywordPageMapping.summary
    if ($null -eq $s) {
        Write-Host "  SKIP (summary not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $s.total -and
        $null -ne $s.strong -and
        $null -ne $s.moderate -and
        $null -ne $s.weak -and
        $null -ne $s.unmapped -and
        $null -ne $s.ambiguous
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing counters in summary)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-6: archetypeAlignment section present
try {
    Write-Host "Testing: VB-6 diagnostics.archetypeAlignment shape" -NoNewline
    $aa = $vbDiag.diagnostics.archetypeAlignment
    if ($null -eq $aa) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $aa.entries -and
        $null -ne $aa.alignedCount -and
        $null -ne $aa.misalignedCount -and
        $null -ne $aa.noDataCount
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in archetypeAlignment)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-7: entityGapAnalysis section present
try {
    Write-Host "Testing: VB-7 diagnostics.entityGapAnalysis shape" -NoNewline
    $eg = $vbDiag.diagnostics.entityGapAnalysis
    if ($null -eq $eg) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $eg.entries -and
        $null -ne $eg.totalGaps -and
        $null -ne $eg.keywordsWithGaps -and
        $null -ne $eg.keywordsWithoutMapping
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in entityGapAnalysis)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-8: topicTerritoryGaps section present
try {
    Write-Host "Testing: VB-8 diagnostics.topicTerritoryGaps shape" -NoNewline
    $ttg = $vbDiag.diagnostics.topicTerritoryGaps
    if ($null -eq $ttg) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ttg.topicTerritories -and
        $null -ne $ttg.untrackedTopics -and
        $null -ne $ttg.thinTopics -and
        $null -ne $ttg.uncategorizedKeywords -and
        $null -ne $ttg.summary
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in topicTerritoryGaps)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-9: authorityOpportunity section present
try {
    Write-Host "Testing: VB-9 diagnostics.authorityOpportunity shape" -NoNewline
    $ao = $vbDiag.diagnostics.authorityOpportunity
    if ($null -eq $ao) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ao.opportunities -and
        $null -ne $ao.summary
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in authorityOpportunity)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-10: schemaOpportunity section present
try {
    Write-Host "Testing: VB-10 diagnostics.schemaOpportunity shape" -NoNewline
    $so = $vbDiag.diagnostics.schemaOpportunity
    if ($null -eq $so) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $so.entries -and
        $null -ne $so.pagesWithoutSchema -and
        $null -ne $so.totalMissingSchemaOpportunities -and
        $null -ne $so.serpSchemaFrequency
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in schemaOpportunity)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-11: readinessClassification section present
try {
    Write-Host "Testing: VB-11 diagnostics.readinessClassification shape" -NoNewline
    $rc = $vbDiag.diagnostics.readinessClassification
    if ($null -eq $rc) {
        Write-Host "  SKIP (diagnostics not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $rc.classifications -and
        $null -ne $rc.categoryCounts -and
        $null -ne $rc.fullyAlignedCount -and
        $null -ne $rc.keywordsWithIssues
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing fields in readinessClassification)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-12: Determinism — two calls return identical diagnostics
try {
    Write-Host "Testing: VB-12 GET project-diagnostics is deterministic" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data.diagnostics | ConvertTo-Json -Depth 20 -Compress
        $d2 = ($r2.Content | ConvertFrom-Json).data.diagnostics | ConvertTo-Json -Depth 20 -Compress
        if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-13: POST rejected (method not allowed)
try {
    Write-Host "Testing: VB-13 POST /veda-brain/project-diagnostics returns 405" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method POST -Headers $Headers -Body "{}" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 405) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 405)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-14: Cross-project isolation
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: VB-14 Diagnostics are project-scoped (cross-project isolation)" -NoNewline
        $r1 = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri "$Base/api/veda-brain/project-diagnostics" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $p1 = ($r1.Content | ConvertFrom-Json).data.projectId
            $p2 = ($r2.Content | ConvertFrom-Json).data.projectId
            if ($p1 -ne $p2) { Write-Host "  PASS (different projectIds)" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (same projectId for both header sets)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: VB-14 Cross-project isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# VB-15: readinessClassification.categoryCounts has all expected categories
try {
    Write-Host "Testing: VB-15 categoryCounts has all readiness categories" -NoNewline
    $cc = $vbDiag.diagnostics.readinessClassification.categoryCounts
    if ($null -eq $cc) {
        Write-Host "  SKIP (readinessClassification not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $expected = @("structurally_aligned", "under_covered", "archetype_misaligned", "entity_incomplete", "weak_authority_support", "schema_underpowered", "unmapped")
        $allPresent = $true
        foreach ($cat in $expected) {
            if ($null -eq $cc.$cat) { $allPresent = $false; break }
        }
        if ($allPresent) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (missing category in categoryCounts)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-16: keywordPageMapping.summary.total is non-negative
try {
    Write-Host "Testing: VB-16 keywordPageMapping.summary.total is non-negative" -NoNewline
    $total = $vbDiag.diagnostics.keywordPageMapping.summary.total
    if ($null -eq $total) {
        Write-Host "  SKIP (summary not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ([int]$total -ge 0) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (total is negative)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-17: mapping entries have required fields
try {
    Write-Host "Testing: VB-17 mapping entries have keywordTargetId and query" -NoNewline
    $maps = $vbDiag.diagnostics.keywordPageMapping.mappings
    if ($null -eq $maps) {
        Write-Host "  SKIP (mappings not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($maps.Count -eq 0) {
        Write-Host "  PASS (empty array is valid)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        $allValid = $true
        foreach ($entry in $maps) {
            if ([string]::IsNullOrWhiteSpace($entry.keywordTargetId) -or [string]::IsNullOrWhiteSpace($entry.query)) {
                $allValid = $false; break
            }
        }
        if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (mapping entry missing keywordTargetId or query)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-18: classification entries have required fields
try {
    Write-Host "Testing: VB-18 classification entries have query and categories" -NoNewline
    $cls = $vbDiag.diagnostics.readinessClassification.classifications
    if ($null -eq $cls) {
        Write-Host "  SKIP (classifications not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($cls.Count -eq 0) {
        Write-Host "  PASS (empty array is valid)" -ForegroundColor Green; Hammer-Record PASS
    } else {
        $allValid = $true
        foreach ($entry in $cls) {
            if ([string]::IsNullOrWhiteSpace($entry.query) -or $null -eq $entry.categories) {
                $allValid = $false; break
            }
        }
        if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (classification entry missing query or categories)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-19: authorityOpportunity.summary has all counters
try {
    Write-Host "Testing: VB-19 authorityOpportunity.summary has all counters" -NoNewline
    $as = $vbDiag.diagnostics.authorityOpportunity.summary
    if ($null -eq $as) {
        Write-Host "  SKIP (authorityOpportunity not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $as.isolatedTargets -and
        $null -ne $as.weaklySupported -and
        $null -ne $as.highValueUndersupported -and
        $null -ne $as.wellSupported
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing counters in authorityOpportunity.summary)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VB-20: topicTerritoryGaps.summary has all counters
try {
    Write-Host "Testing: VB-20 topicTerritoryGaps.summary has all counters" -NoNewline
    $ts = $vbDiag.diagnostics.topicTerritoryGaps.summary
    if ($null -eq $ts) {
        Write-Host "  SKIP (topicTerritoryGaps not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $ts.totalTopics -and
        $null -ne $ts.untrackedTopicCount -and
        $null -ne $ts.thinTopicCount -and
        $null -ne $ts.uncategorizedKeywordCount
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (missing counters in topicTerritoryGaps.summary)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
