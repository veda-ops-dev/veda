# hammer-project-bootstrap.ps1 — Project CRUD and project-context tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   POST /api/projects — create, validation, duplicate slug, auto-slug, strict mode
#   GET  /api/projects/:id — retrieve, 404, invalid UUID
#   GET  /api/projects — list includes new project
#   Mutation strict-mode: endpoints require explicit project context (no silent default-project fallback)
#   Read endpoints: first-run fallback still allowed
#
# Blueprint tests (PB-9 through PB-22, PB-24) were removed.
# Blueprint workflow was intentionally removed from VEDA in Wave 2D.
# Ownership belongs to Project V. Do not reintroduce here.

Hammer-Section "PROJECT BOOTSTRAP"

$testSlug = "hammer-bp-$(Get-Date -Format 'yyyyMMddHHmmss')"
$testProjectId = $null

# ── Project creation ──────────────────────────────────────────────────────────

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

# ── Project retrieval ─────────────────────────────────────────────────────────

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

# PB-9 through PB-22, PB-24: blueprint tests removed.
# Blueprint workflow was intentionally removed from VEDA in Wave 2D.
# Do not reintroduce. Ownership belongs to Project V.

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
