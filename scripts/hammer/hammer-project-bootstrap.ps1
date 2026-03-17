# hammer-project-bootstrap.ps1 — Project Bootstrap & Blueprint hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   POST /api/projects — create, validation, duplicate slug, strict mode
#   GET  /api/projects/:id — retrieve, 404, invalid UUID
#   GET  /api/projects — list includes new project
#   POST /api/projects/:id/blueprint — propose, validation, lifecycle transition
#   GET  /api/projects/:id/blueprint — retrieve active blueprint
#   POST /api/projects/:id/blueprint/apply — apply, idempotent re-apply
#   Lifecycle: created → draft on first proposal
#   Post-apply: blueprint archived, second apply 400
#   Apply response shape: blueprintId, projectId, applied, created (surfaces/sites/archetypes/topics/entities)
#   Apply created counts non-negative
#   GET /blueprint/apply returns 405
#   Apply on non-existent project returns 404

Hammer-Section "PROJECT BOOTSTRAP & BLUEPRINT"

$testSlug = "hammer-bp-$(Get-Date -Format 'yyyyMMddHHmmss')"
$testProjectId = $null

# ── Project creation ─────────────────────────────────────────────────────────

# PB-1: POST /api/projects creates a project
try {
    Write-Host "Testing: PB-1 POST /api/projects creates a project" -NoNewline
    $createBody = @{ name = "Hammer BP Test"; slug = $testSlug; description = "Blueprint hammer test" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $createBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $created = ($resp.Content | ConvertFrom-Json).data
        $testProjectId = $created.id
        if ($created.name -eq "Hammer BP Test" -and $created.slug -eq $testSlug -and $created.lifecycleState -eq "created") {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host "  FAIL (unexpected data: $($resp.Content))" -ForegroundColor Red; Hammer-Record FAIL
        }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-2: Duplicate slug returns 409
try {
    Write-Host "Testing: PB-2 Duplicate slug returns 409" -NoNewline
    $dupeBody = @{ name = "Duplicate"; slug = $testSlug } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $dupeBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 409) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 409)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-3: POST with missing name returns 400
try {
    Write-Host "Testing: PB-3 POST with missing name returns 400" -NoNewline
    $badBody = @{ description = "no name" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $badBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-4: POST with extra fields returns 400 (strict)
try {
    Write-Host "Testing: PB-4 POST with extra fields returns 400" -NoNewline
    $extraBody = @{ name = "Extra"; slug = "extra-strict"; bogus = "field" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $extraBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Project retrieval ────────────────────────────────────────────────────────

# PB-5: GET /api/projects/:id returns project
try {
    Write-Host "Testing: PB-5 GET /api/projects/:id returns project" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $proj = ($resp.Content | ConvertFrom-Json).data
            if ($proj.id -eq $testProjectId -and $proj.slug -eq $testSlug) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host "  FAIL (mismatch)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-6: Non-existent project returns 404
try {
    Write-Host "Testing: PB-6 Non-existent project returns 404" -NoNewline
    $fakeId = "00000000-0000-4000-a000-000000000099"
    $resp = Invoke-WebRequest -Uri "$Base/api/projects/$fakeId" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 404) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-7: Invalid UUID returns 400
try {
    Write-Host "Testing: PB-7 Invalid UUID returns 400" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/projects/not-a-uuid" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-8: GET /api/projects list includes new project
try {
    Write-Host "Testing: PB-8 GET /api/projects list includes new project" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects?limit=100" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $found = ($resp.Content | ConvertFrom-Json).data | Where-Object { $_.id -eq $testProjectId }
            if ($null -ne $found) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host "  FAIL (not in list)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Blueprint: pre-proposal state ────────────────────────────────────────────

# PB-9: GET blueprint with none proposed returns 404
try {
    Write-Host "Testing: PB-9 GET blueprint before proposal returns 404" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Blueprint: proposal ──────────────────────────────────────────────────────

$blueprintContent = @{
    schemaVersion = "blueprint.v1"
    brandIdentity = @{
        projectName = "Hammer BP Test"
        strategicNiche = "AI education"
    }
    surfaceRegistry = @(
        @{ type = "website"; key = "main-site"; label = "Main Website" }
    )
    websiteArchitecture = @{
        domain = "hammertest.example.com"
        framework = "nextjs"
    }
    contentArchetypes = @(
        @{ key = "guide"; label = "Guide" }
        @{ key = "tutorial"; label = "Tutorial" }
    )
    entityClusters = @(
        @{ key = "machine-learning"; label = "Machine Learning" }
        @{ key = "openai"; label = "OpenAI"; entityType = "organization" }
    )
}

# PB-10: POST blueprint proposal succeeds
try {
    Write-Host "Testing: PB-10 POST blueprint proposal succeeds" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $bpBody = @{ content = $blueprintContent } | ConvertTo-Json -Depth 10
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $bpBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            $bpData = ($resp.Content | ConvertFrom-Json).data
            if ($bpData.projectId -eq $testProjectId -and $null -ne $bpData.blueprint.id) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host "  FAIL (shape)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-11: Lifecycle transitioned to "draft"
try {
    Write-Host "Testing: PB-11 Lifecycle is 'draft' after proposal" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        $proj = ($resp.Content | ConvertFrom-Json).data
        if ($proj.lifecycleState -eq "draft") {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got: " + $proj.lifecycleState + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-12: GET blueprint returns proposed blueprint
try {
    Write-Host "Testing: PB-12 GET blueprint returns proposed content" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $bpData = ($resp.Content | ConvertFrom-Json).data
            if ($null -ne $bpData.blueprint -and $null -ne $bpData.blueprint.content) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host "  FAIL (missing)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-13: Invalid blueprint content returns 400
try {
    Write-Host "Testing: PB-13 Invalid blueprint content returns 400" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $badBp = @{ content = @{ schemaVersion = "blueprint.v1"; brandIdentity = @{ projectName = "X" } } } | ConvertTo-Json -Depth 10
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $badBp -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Blueprint: apply ─────────────────────────────────────────────────────────

# PB-14: Re-propose clean blueprint for apply test (previous was overwritten by PB-13 attempt)
try {
    Write-Host "Testing: PB-14 Re-propose blueprint for apply" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $bpBody = @{ content = $blueprintContent } | ConvertTo-Json -Depth 10
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $bpBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-15: POST blueprint apply succeeds
try {
    Write-Host "Testing: PB-15 POST blueprint apply succeeds" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $applyData = ($resp.Content | ConvertFrom-Json).data
            if ($applyData.applied -eq $true -and $applyData.created.surfaces -ge 1 -and $applyData.created.archetypes -ge 1) {
                Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            } else { Write-Host ("  FAIL (result: " + $resp.Content + ")") -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-16: After apply, blueprint is archived (GET returns 404)
try {
    Write-Host "Testing: PB-16 After apply, GET blueprint returns 404" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 404) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-17: Apply with no active blueprint returns 400
try {
    Write-Host "Testing: PB-17 Apply with no blueprint returns 400" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Idempotent re-apply ──────────────────────────────────────────────────────

# PB-18: Re-propose + re-apply creates 0 new records (idempotent)
try {
    Write-Host "Testing: PB-18 Idempotent re-apply creates 0 new records" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $bpBody = @{ content = $blueprintContent } | ConvertTo-Json -Depth 10
        $resp1 = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $bpBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp1.StatusCode -ne 201) {
            Write-Host ("  FAIL (re-propose got " + $resp1.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL
        } else {
            $resp2 = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp2.StatusCode -eq 200) {
                $ad = ($resp2.Content | ConvertFrom-Json).data
                if ($ad.created.surfaces -eq 0 -and $ad.created.archetypes -eq 0 -and $ad.created.topics -eq 0 -and $ad.created.entities -eq 0 -and $ad.created.sites -eq 0) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else { Write-Host ("  FAIL (expected 0s, got: " + $resp2.Content + ")") -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (re-apply got " + $resp2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-19: Apply response includes blueprintId and per-type created counts
try {
    Write-Host "Testing: PB-19 Apply response shape has blueprintId and all created counters" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        # Re-propose + apply for a clean check
        $bpBody = @{ content = $blueprintContent } | ConvertTo-Json -Depth 10
        $rp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $bpBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rp.StatusCode -ne 201) {
            Write-Host "  SKIP (re-propose failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $ra = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($ra.StatusCode -eq 200) {
                $ad = ($ra.Content | ConvertFrom-Json).data
                if (
                    $ad.applied -eq $true -and
                    -not [string]::IsNullOrWhiteSpace($ad.blueprintId) -and
                    -not [string]::IsNullOrWhiteSpace($ad.projectId) -and
                    $null -ne $ad.created.surfaces -and
                    $null -ne $ad.created.sites -and
                    $null -ne $ad.created.archetypes -and
                    $null -ne $ad.created.topics -and
                    $null -ne $ad.created.entities
                ) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else { Write-Host ("  FAIL (shape mismatch: " + $ra.Content + ")") -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $ra.StatusCode + ") body=" + $ra.Content) -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-20: Apply created counts are non-negative (sanity check; not an exact blueprint composition match)
# Note: exact counts depend on prior idempotency state. This test only asserts no negative values.
try {
    Write-Host "Testing: PB-20 Apply created counts are non-negative" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        # Re-propose for a clean state then apply
        $bpBody = @{ content = $blueprintContent } | ConvertTo-Json -Depth 10
        $rp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $bpBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($rp.StatusCode -ne 201) {
            Write-Host "  SKIP (re-propose failed)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $ra = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($ra.StatusCode -eq 200) {
                $ad = ($ra.Content | ConvertFrom-Json).data
                # Verifies all per-type created counters are >= 0 (not negative).
                # Exact values depend on idempotency state from prior tests and are not asserted here.
                $countsNonNegative = (
                    [int]$ad.created.surfaces -ge 0 -and
                    [int]$ad.created.sites    -ge 0 -and
                    [int]$ad.created.archetypes -ge 0 -and
                    [int]$ad.created.topics   -ge 0 -and
                    [int]$ad.created.entities -ge 0
                )
                if ($countsNonNegative) {
                    Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
                } else { Write-Host ("  FAIL (negative count in response: " + $ra.Content + ")") -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $ra.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-21: GET on apply endpoint returns 405
try {
    Write-Host "Testing: PB-21 GET /blueprint/apply returns 405" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $resp = Invoke-WebRequest -Uri "$Base/api/projects/$testProjectId/blueprint/apply" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 405) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 405)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-22: Apply on non-existent project returns 404
try {
    Write-Host "Testing: PB-22 Apply on non-existent project returns 404" -NoNewline
    $fakeId = "00000000-0000-4000-a000-000000000099"
    $resp = Invoke-WebRequest -Uri "$Base/api/projects/$fakeId/blueprint/apply" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body "{}" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 404) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-23: Auto-derived slug works
try {
    Write-Host "Testing: PB-23 POST with auto-derived slug" -NoNewline
    $autoBody = @{ name = "Auto Slug $(Get-Date -Format 'yyyyMMddHHmmss')" } | ConvertTo-Json
    $resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST -Headers @{ "Content-Type" = "application/json" } -Body $autoBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $c = ($resp.Content | ConvertFrom-Json).data
        if (-not [string]::IsNullOrWhiteSpace($c.slug)) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else { Write-Host "  FAIL (empty slug)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-24: Blueprint on non-existent project returns 404
try {
    Write-Host "Testing: PB-24 Blueprint on non-existent project returns 404" -NoNewline
    $fakeId = "00000000-0000-4000-a000-000000000099"
    $resp = Invoke-WebRequest -Uri "$Base/api/projects/$fakeId/blueprint" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 404) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ── Project resolution strict-mode coverage ───────────────────────────────────
# These tests defend the Batch 3 hardening: mutation endpoints must reject
# requests that supply no explicit project context (no header, no cookie).
# Before hardening: such requests silently mutated into DEFAULT_PROJECT_ID.
# After hardening:  such requests return 400 with a clear error message.

# PB-25: POST to mutation endpoint without any project context returns 400
# Uses /api/content-graph/surfaces as the representative mutation endpoint.
try {
    Write-Host "Testing: PB-25 POST mutation without project context returns 400" -NoNewline
    $surfaceBody = @{ type = "website"; key = "test-no-project"; label = "Test" } | ConvertTo-Json
    # Deliberately send NO X-Project-Id or X-Project-Slug header
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST `
        -Headers @{ "Content-Type" = "application/json" } `
        -Body $surfaceBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) {
        $body = $resp.Content | ConvertFrom-Json
        # Verify the error is about missing project context (not some other validation failure)
        $errorMsg = $body.error
        if ($null -eq $errorMsg) { $errorMsg = ($body | ConvertTo-Json) }
        if ($errorMsg -match "Project context required" -or $errorMsg -match "project" -or $errorMsg -match "Project") {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (got 400 but wrong error: " + $errorMsg + ")") -ForegroundColor Red; Hammer-Record FAIL
        }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400 — silent default-project fallback may still be active)") -ForegroundColor Red
        Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-26: POST to mutation endpoint with X-Project-Id succeeds (explicit context respected)
try {
    Write-Host "Testing: PB-26 POST mutation with explicit X-Project-Id succeeds" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP (no testProjectId)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $ts = Get-Date -Format 'yyyyMMddHHmmss'
        $surfaceBody = @{ type = "website"; key = "pb26-surface-$ts"; label = "PB26 Test" } | ConvertTo-Json
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST `
            -Headers @{ "Content-Type" = "application/json"; "X-Project-Id" = $testProjectId } `
            -Body $surfaceBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-27: POST to mutation endpoint with X-Project-Slug succeeds (slug-based context respected)
try {
    Write-Host "Testing: PB-27 POST mutation with explicit X-Project-Slug succeeds" -NoNewline
    if ($null -eq $testProjectId) { Write-Host "  SKIP (no testProjectId)" -ForegroundColor DarkYellow; Hammer-Record SKIP } else {
        $ts = Get-Date -Format 'yyyyMMddHHmmss'
        $surfaceBody = @{ type = "wiki"; key = "pb27-surface-$ts"; label = "PB27 Test" } | ConvertTo-Json
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST `
            -Headers @{ "Content-Type" = "application/json"; "X-Project-Slug" = $testSlug } `
            -Body $surfaceBody -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
        }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# PB-28: GET to read endpoint without project context succeeds (fallback still allowed for reads)
# Verifies that the strict-mode change did NOT break GET endpoints that use resolveProjectId.
try {
    Write-Host "Testing: PB-28 GET read endpoint without project context succeeds (fallback allowed)" -NoNewline
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method GET -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", GET should still succeed without project context)") -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
