# hammer-veda-brain-proposals.ps1 — Phase C1 Proposal Surface hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   - GET /api/veda-brain/proposals returns 200
#   - Response envelope: data.projectId, data.proposals, data.summary
#   - archetypeProposals and schemaProposals are arrays
#   - summary counts are consistent with returned arrays
#   - No deferred categories present (topic/entity/authoritysupport)
#   - Determinism: two calls return identical JSON
#   - ProposalId stability across calls
#   - ProposalId prefix format (archetype: / schema:)
#   - No invalid archetype proposals (excluded mismatchReasons)
#   - No schema proposals with empty missingSchemaTypes
#   - No schema proposals with null pageId
#   - suggestedAction values are within defined enum sets
#   - archetypeProposals ordered by query asc, existingPageId asc
#   - schemaProposals ordered by query asc, pageId asc
#   - POST rejected (405)
#   - Project isolation (cross-project non-disclosure)
#   - Empty state returns valid envelope (200, not error)

Hammer-Section "VEDA BRAIN — PHASE C1 PROPOSALS"

$ARCHETYPE_SUGGESTED_ACTIONS = @("review_archetype_alignment", "consider_archetype_aligned_page")
$SCHEMA_SUGGESTED_ACTIONS    = @("review_schema_gap")
$EXCLUDED_MISMATCH_REASONS   = @("no_mapped_page", "no_serp_archetype_signal")

# VBP-1: GET returns 200
$vbpData = $null
try {
    Write-Host "Testing: VBP-1 GET /veda-brain/proposals returns 200" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $vbpData = ($resp.Content | ConvertFrom-Json).data } catch {}
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 200) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-2: Response has data.projectId
try {
    Write-Host "Testing: VBP-2 Response contains projectId" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (-not [string]::IsNullOrWhiteSpace($vbpData.projectId)) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (projectId missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-3: Response has data.proposals object
try {
    Write-Host "Testing: VBP-3 Response contains proposals object" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($null -ne $vbpData.proposals) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (proposals missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-4: Response has data.summary object
try {
    Write-Host "Testing: VBP-4 Response contains summary object" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif (
        $null -ne $vbpData.summary -and
        $null -ne $vbpData.summary.archetypeProposalCount -and
        $null -ne $vbpData.summary.schemaProposalCount -and
        $null -ne $vbpData.summary.totalProposals
    ) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (summary or summary fields missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-5: archetypeProposals is an array
try {
    Write-Host "Testing: VBP-5 proposals.archetypeProposals is an array" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($null -ne $vbpData.proposals.archetypeProposals) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (archetypeProposals missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-6: schemaProposals is an array
try {
    Write-Host "Testing: VBP-6 proposals.schemaProposals is an array" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } elseif ($null -ne $vbpData.proposals.schemaProposals) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host "  FAIL (schemaProposals missing)" -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-7: summary counts match arrays
try {
    Write-Host "Testing: VBP-7 summary counts match array lengths" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        $sp = @($vbpData.proposals.schemaProposals)
        $expectedArchetype = [int]$vbpData.summary.archetypeProposalCount
        $expectedSchema    = [int]$vbpData.summary.schemaProposalCount
        $expectedTotal     = [int]$vbpData.summary.totalProposals
        $actualArchetype   = $ap.Count
        $actualSchema      = $sp.Count
        $actualTotal       = $actualArchetype + $actualSchema
        if ($actualArchetype -eq $expectedArchetype -and $actualSchema -eq $expectedSchema -and $actualTotal -eq $expectedTotal) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (archetype=" + $actualArchetype + "/" + $expectedArchetype + " schema=" + $actualSchema + "/" + $expectedSchema + " total=" + $actualTotal + "/" + $expectedTotal + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-8: No deferred proposal categories present
try {
    Write-Host "Testing: VBP-8 No deferred categories (topic/entity/authoritysupport) in response" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $hasDeferred = (
            $null -ne $vbpData.proposals.topicProposals -or
            $null -ne $vbpData.proposals.entityProposals -or
            $null -ne $vbpData.proposals.authoritySupportProposals
        )
        if (-not $hasDeferred) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (deferred proposal category present in response)" -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-9: Determinism — two calls return identical JSON
try {
    Write-Host "Testing: VBP-9 GET proposals is deterministic (two calls)" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $j1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 20 -Compress
        $j2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 20 -Compress
        if ($j1 -eq $j2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-10: ProposalId stability across calls
try {
    Write-Host "Testing: VBP-10 proposalIds are stable across repeated calls" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $ids1 = @(($r1.Content | ConvertFrom-Json).data.proposals.archetypeProposals + ($r1.Content | ConvertFrom-Json).data.proposals.schemaProposals) | ForEach-Object { $_.proposalId } | Sort-Object
        $ids2 = @(($r2.Content | ConvertFrom-Json).data.proposals.archetypeProposals + ($r2.Content | ConvertFrom-Json).data.proposals.schemaProposals) | ForEach-Object { $_.proposalId } | Sort-Object
        $ids1Str = $ids1 -join ","
        $ids2Str = $ids2 -join ","
        if ($ids1Str -eq $ids2Str) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (proposalIds differ between calls)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-11: archetypeProposal proposalIds start with "archetype:"
try {
    Write-Host "Testing: VBP-11 archetypeProposal proposalIds have 'archetype:' prefix" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        if ($ap.Count -eq 0) {
            Write-Host "  PASS (no archetype proposals to check)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $ap) {
                if (-not $p.proposalId.StartsWith("archetype:")) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (proposalId missing archetype: prefix)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-12: schemaProposal proposalIds start with "schema:"
try {
    Write-Host "Testing: VBP-12 schemaProposal proposalIds have 'schema:' prefix" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -eq 0) {
            Write-Host "  PASS (no schema proposals to check)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $sp) {
                if (-not $p.proposalId.StartsWith("schema:")) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (proposalId missing schema: prefix)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-13: No archetype proposals with excluded mismatchReasons
try {
    Write-Host "Testing: VBP-13 No archetype proposals with excluded mismatchReasons" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        if ($ap.Count -eq 0) {
            Write-Host "  PASS (no archetype proposals)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $badReasons = $false
            foreach ($p in $ap) {
                if ($EXCLUDED_MISMATCH_REASONS -contains $p.evidence.mismatchReason) { $badReasons = $true; break }
            }
            if (-not $badReasons) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (archetype proposal with excluded mismatchReason found)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-14: No schema proposals with empty missingSchemaTypes
try {
    Write-Host "Testing: VBP-14 No schema proposals with empty missingSchemaTypes" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -eq 0) {
            Write-Host "  PASS (no schema proposals)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $anyEmpty = $false
            foreach ($p in $sp) {
                if ($null -eq $p.missingSchemaTypes -or @($p.missingSchemaTypes).Count -eq 0) { $anyEmpty = $true; break }
            }
            if (-not $anyEmpty) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (schema proposal with empty missingSchemaTypes)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-15: No schema proposals with null pageId
try {
    Write-Host "Testing: VBP-15 No schema proposals with null pageId" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -eq 0) {
            Write-Host "  PASS (no schema proposals)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $anyNull = $false
            foreach ($p in $sp) {
                if ([string]::IsNullOrWhiteSpace($p.pageId)) { $anyNull = $true; break }
            }
            if (-not $anyNull) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (schema proposal with null/empty pageId)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-16: archetypeProposal suggestedAction values within enum
try {
    Write-Host "Testing: VBP-16 archetypeProposal suggestedAction values within enum" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        if ($ap.Count -eq 0) {
            Write-Host "  PASS (no archetype proposals)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $ap) {
                if ($ARCHETYPE_SUGGESTED_ACTIONS -notcontains $p.suggestedAction) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (unexpected suggestedAction in archetype proposal)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-17: schemaProposal suggestedAction values within enum
try {
    Write-Host "Testing: VBP-17 schemaProposal suggestedAction values within enum" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -eq 0) {
            Write-Host "  PASS (no schema proposals)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $sp) {
                if ($SCHEMA_SUGGESTED_ACTIONS -notcontains $p.suggestedAction) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (unexpected suggestedAction in schema proposal)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-18: archetypeProposals ordered query asc, existingPageId asc
try {
    Write-Host "Testing: VBP-18 archetypeProposals ordered by query asc, existingPageId asc" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        if ($ap.Count -le 1) {
            Write-Host "  PASS (0 or 1 proposals, ordering trivially correct)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $sorted = $ap | Sort-Object { $_.query }, { $_.existingPageId }
            $orig   = $ap | ForEach-Object { $_.proposalId } | ConvertTo-Json -Compress
            $sort   = $sorted | ForEach-Object { $_.proposalId } | ConvertTo-Json -Compress
            if ($orig -eq $sort) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (archetypeProposals not in correct order)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-19: schemaProposals ordered query asc, pageId asc
try {
    Write-Host "Testing: VBP-19 schemaProposals ordered by query asc, pageId asc" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -le 1) {
            Write-Host "  PASS (0 or 1 proposals, ordering trivially correct)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $sorted = $sp | Sort-Object { $_.query }, { $_.pageId }
            $orig   = $sp | ForEach-Object { $_.proposalId } | ConvertTo-Json -Compress
            $sort   = $sorted | ForEach-Object { $_.proposalId } | ConvertTo-Json -Compress
            if ($orig -eq $sort) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (schemaProposals not in correct order)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-20: POST rejected (405)
try {
    Write-Host "Testing: VBP-20 POST /veda-brain/proposals returns 405" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method POST -Headers $Headers -Body "{}" -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 405) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 405)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-21: Cross-project isolation
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: VBP-21 Proposals are project-scoped (cross-project isolation)" -NoNewline
        $r1 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        $r2 = Invoke-WebRequest -Uri "$Base/api/veda-brain/proposals" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 60 -UseBasicParsing
        if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
            $p1 = ($r1.Content | ConvertFrom-Json).data.projectId
            $p2 = ($r2.Content | ConvertFrom-Json).data.projectId
            if ($p1 -ne $p2) { Write-Host "  PASS (different projectIds)" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (same projectId for both header sets)" -ForegroundColor Red; Hammer-Record FAIL }
        } elseif ($r1.StatusCode -eq 200 -and ($r2.StatusCode -eq 400 -or $r2.StatusCode -eq 404)) {
            Write-Host "  PASS (cross-project returns non-200 as expected)" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (unexpected status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: VBP-21 Cross-project isolation  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# VBP-22: archetypeProposal required fields shape
try {
    Write-Host "Testing: VBP-22 archetypeProposal entries have required fields" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $ap = @($vbpData.proposals.archetypeProposals)
        if ($ap.Count -eq 0) {
            Write-Host "  PASS (no entries to validate)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $ap) {
                if (
                    [string]::IsNullOrWhiteSpace($p.proposalId) -or
                    $p.proposalType -ne "archetype" -or
                    [string]::IsNullOrWhiteSpace($p.query) -or
                    [string]::IsNullOrWhiteSpace($p.existingPageId) -or
                    [string]::IsNullOrWhiteSpace($p.existingPageUrl) -or
                    [string]::IsNullOrWhiteSpace($p.serpDominantArchetype) -or
                    $p.readinessCategory -ne "archetype_misaligned" -or
                    $null -eq $p.evidence -or
                    [string]::IsNullOrWhiteSpace($p.suggestedAction)
                ) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (archetype proposal missing required field)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# VBP-23: schemaProposal required fields shape
try {
    Write-Host "Testing: VBP-23 schemaProposal entries have required fields" -NoNewline
    if ($null -eq $vbpData) {
        Write-Host "  SKIP (no response)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $sp = @($vbpData.proposals.schemaProposals)
        if ($sp.Count -eq 0) {
            Write-Host "  PASS (no entries to validate)" -ForegroundColor Green; Hammer-Record PASS
        } else {
            $allValid = $true
            foreach ($p in $sp) {
                if (
                    [string]::IsNullOrWhiteSpace($p.proposalId) -or
                    $p.proposalType -ne "schema" -or
                    [string]::IsNullOrWhiteSpace($p.query) -or
                    [string]::IsNullOrWhiteSpace($p.pageId) -or
                    [string]::IsNullOrWhiteSpace($p.pageUrl) -or
                    $null -eq $p.missingSchemaTypes -or
                    $null -eq $p.existingSchemaTypes -or
                    $p.readinessCategory -ne "schema_underpowered" -or
                    $null -eq $p.evidence -or
                    $p.suggestedAction -ne "review_schema_gap"
                ) { $allValid = $false; break }
            }
            if ($allValid) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (schema proposal missing required field)" -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
