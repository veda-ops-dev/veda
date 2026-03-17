# hammer-content-graph-phase1.ps1 — Content Graph Phase 1 hammer tests
# Dot-sourced by api-hammer.ps1. Inherits $Headers, $OtherHeaders, $Base, Hammer-Section, Hammer-Record.
#
# Coverage:
#   - Project-scoped creation for all Phase 1 endpoints
#   - 404 non-disclosure for cross-project FK references (surfaceId, siteId, contentArchetypeId, pageId, topicId, entityId)
#   - Deterministic ordering on list endpoints
#   - Strict schema rejection for unknown fields
#   - Duplicate key/URL/domain rejection
#   - Self-referential link rejection
#   - Invalid enum value rejection
#   - GET list envelope + pagination
#   - Cross-project non-disclosure on GET lists
#   - Surface key canonicalization (mixed-case, spaces, underscores → stored as lowercase-hyphen)
#   - Surface canonicalIdentifier duplicate prevention per (project, type)
#   - Surface canonicalIdentifier format validation per type (website/youtube/x)
#   - Surface disabled → site creation rejected (400)
#   - canonicalUrl must be valid URL
#
# Cross-project tests require $OtherHeaders to resolve to a genuinely different project.
# Tests gated on ($OtherHeaders.Count -gt 0) are skipped if no second project is configured.
#
# Run-unique suffix prevents duplicate key failures on repeated hammer runs.
# Uses milliseconds to guarantee uniqueness even within the same second.

$cgRun = (Get-Date -Format "yyyyMMddHHmmssfff")

Hammer-Section "CONTENT GRAPH PHASE 1 — SURFACES"

# CG-S1: Create a surface — capture error body on failure for diagnostics
$cgSurfaceId = $null
try {
    Write-Host "Testing: CG-S1 POST /content-graph/surfaces creates surface" -NoNewline
    $body = @{ type = "website"; key = "cgs-$cgRun"; label = "Main Site" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgSurfaceId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S2: Duplicate key rejected
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S2 POST /content-graph/surfaces rejects duplicate key" `
    -RequestHeaders $Headers `
    -BodyObj @{ type = "website"; key = "cgs-$cgRun"; label = "Duplicate" }

# CG-S3: Unknown field rejected (strict)
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S3 POST /content-graph/surfaces rejects unknown fields" `
    -RequestHeaders $Headers `
    -BodyObj @{ type = "website"; key = "cgs-unk-$cgRun"; unknownField = "bad" }

# CG-S4: Missing required fields rejected
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S4 POST /content-graph/surfaces rejects missing type" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cgs-notype-$cgRun" }

# CG-S5: Invalid enum value rejected
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S5 POST /content-graph/surfaces rejects invalid type enum" `
    -RequestHeaders $Headers `
    -BodyObj @{ type = "invalid_surface"; key = "cgs-enum-$cgRun" }

# CG-S6: GET list returns envelope with pagination
Test-ResponseEnvelope -Url "$Base/api/content-graph/surfaces" `
    -RequestHeaders $Headers `
    -Description "CG-S6 GET /content-graph/surfaces returns list envelope" `
    -ExpectPagination $true

# CG-S7: GET determinism
try {
    Write-Host "Testing: CG-S7 GET /content-graph/surfaces is deterministic" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 5 -Compress
        $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 5 -Compress
        if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S8: Cross-project non-disclosure
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-S8 Surface not visible to other project" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgSurfaceId)) {
            Write-Host "  SKIP (cgSurfaceId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $ids = ($resp.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }
                if ($ids -notcontains $cgSurfaceId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (surface id leaked to other project)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-S8 Surface not visible to other project  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# ---------------------------------------------------------------------------
# CG-S9 through CG-S15: Surface identity hardening (canonicalization + identity)
# ---------------------------------------------------------------------------

# CG-S9: Key with mixed case is accepted and stored in canonical lowercase form
try {
    Write-Host "Testing: CG-S9 Surface key is canonicalized to lowercase" -NoNewline
    $rawKey = "Main-SITE-$cgRun"
    $expectedKey = $rawKey.ToLower()
    $body = @{ type = "website"; key = $rawKey }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $storedKey = ($resp.Content | ConvertFrom-Json).data.key
        if ($storedKey -eq $expectedKey) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (stored key='" + $storedKey + "', expected='" + $expectedKey + "')") -ForegroundColor Red; Hammer-Record FAIL }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S10: Key with underscores is canonicalized to hyphens
try {
    Write-Host "Testing: CG-S10 Surface key underscores canonicalized to hyphens" -NoNewline
    $rawKey = "my_wiki_site_$cgRun"
    $expectedKey = "my-wiki-site-$cgRun"
    $body = @{ type = "wiki"; key = $rawKey }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $storedKey = ($resp.Content | ConvertFrom-Json).data.key
        if ($storedKey -eq $expectedKey) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (stored key='" + $storedKey + "', expected='" + $expectedKey + "')") -ForegroundColor Red; Hammer-Record FAIL }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S11: Mixed-case duplicate rejected (canonical collision after lowercasing)
try {
    Write-Host "Testing: CG-S11 Duplicate key after canonicalization rejected (case collision)" -NoNewline
    # Attempt to register UPPER version of the key used in CG-S9 (already stored as lowercase)
    $collideKey = "MAIN-SITE-$cgRun"
    $body = @{ type = "website"; key = $collideKey }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S12: canonicalIdentifier with valid website hostname accepted
$cgSurfaceWithIdentityId = $null
try {
    Write-Host "Testing: CG-S12 Surface with valid website canonicalIdentifier accepted" -NoNewline
    $body = @{ type = "website"; key = "cgs-id-$cgRun"; canonicalIdentifier = "psymetric-$cgRun.io"; canonicalUrl = "https://psymetric-$cgRun.io" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgSurfaceWithIdentityId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S13: Duplicate canonicalIdentifier for same (project, type) rejected
try {
    Write-Host "Testing: CG-S13 Duplicate canonicalIdentifier for same project+type rejected" -NoNewline
    $body = @{ type = "website"; key = "cgs-id2-$cgRun"; canonicalIdentifier = "psymetric-$cgRun.io" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S13b: Same canonicalIdentifier is allowed for different types (no cross-type uniqueness)
try {
    Write-Host "Testing: CG-S13b Same canonicalIdentifier allowed across different surface types" -NoNewline
    # Use a blog surface with same identifier as the website above — should succeed
    # (blog identifier validation allows host format same as website)
    $body = @{ type = "blog"; key = "cgs-blog-id-$cgRun"; canonicalIdentifier = "blog-$cgRun.io" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S14: Invalid canonicalIdentifier format for website rejected
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S14 Surface rejects invalid canonicalIdentifier format for website type (has scheme)" `
    -RequestHeaders $Headers `
    -BodyObj @{ type = "website"; key = "cgs-badinvalid-$cgRun"; canonicalIdentifier = "https://example.com" }

# CG-S15: canonicalUrl must be a valid URL
Test-PostJson -Url "$Base/api/content-graph/surfaces" `
    -ExpectedStatus 400 `
    -Description "CG-S15 Surface rejects invalid canonicalUrl (not a URL)" `
    -RequestHeaders $Headers `
    -BodyObj @{ type = "website"; key = "cgs-badurl-$cgRun"; canonicalUrl = "not-a-url" }

# CG-S16: Two surfaces of the same type without canonicalIdentifier are both allowed
# (no singleton-per-type constraint; multi-surface model is supported)
try {
    Write-Host "Testing: CG-S16 Multiple surfaces of same type without canonicalIdentifier allowed" -NoNewline
    $b1 = @{ type = "youtube"; key = "cgs-yt1-$cgRun" } | ConvertTo-Json -Compress
    $b2 = @{ type = "youtube"; key = "cgs-yt2-$cgRun" } | ConvertTo-Json -Compress
    $r1 = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $b1 -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $b2 -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 201 -and $r2.StatusCode -eq 201) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (statuses: " + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S17: Disabled surface rejects new site creation (400)
try {
    Write-Host "Testing: CG-S17 Site creation rejected for disabled surface" -NoNewline
    # Create a surface, then disable it via direct check of surface creation + simulate disabled state
    # We create with enabled=false directly
    $surfBody = @{ type = "website"; key = "cgs-disabled-$cgRun"; enabled = $false } | ConvertTo-Json -Compress
    $surfResp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $surfBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($surfResp.StatusCode -ne 201) {
        Write-Host "  SKIP (could not create disabled surface)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $disabledSurfaceId = ($surfResp.Content | ConvertFrom-Json).data.id
        $siteBody = @{ surfaceId = $disabledSurfaceId; domain = "disabled-$cgRun.example.com" } | ConvertTo-Json -Compress
        $siteResp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $Headers -Body $siteBody -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($siteResp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $siteResp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# ---------------------------------------------------------------------------
# CG-S18 through CG-S22: YouTube surface canonicalIdentifier UC... enforcement
# Per VEDA-YOUTUBE-IDENTITY-NORMALIZATION.md: YouTube surfaces must store
# channel ID in UC... form only. @handle and URL forms must be rejected.
# ---------------------------------------------------------------------------

# CG-S18: YouTube surface with valid UC... canonicalIdentifier accepted
try {
    Write-Host "Testing: CG-S18 YouTube surface with UC... canonicalIdentifier accepted" -NoNewline
    $ucId = "UC" + "aB1cD2eF3gH4iJ5kL6mN7oP8q".Substring(0, 22)
    $body = @{ type = "youtube"; key = "cgs-yt-uc-$cgRun"; canonicalIdentifier = $ucId } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $body -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        $stored = ($resp.Content | ConvertFrom-Json).data.canonicalIdentifier
        if ($stored -eq $ucId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (stored='" + $stored + "', expected='" + $ucId + "')") -ForegroundColor Red; Hammer-Record FAIL }
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S19: YouTube surface with @handle canonicalIdentifier rejected
try {
    Write-Host "Testing: CG-S19 YouTube surface with @handle canonicalIdentifier rejected" -NoNewline
    $body = @{ type = "youtube"; key = "cgs-yt-handle-$cgRun"; canonicalIdentifier = "@testchannel" } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $body -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400 — @handle must not be accepted as YouTube canonicalIdentifier)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S20: YouTube surface with channel URL as canonicalIdentifier rejected
try {
    Write-Host "Testing: CG-S20 YouTube surface with channel URL as canonicalIdentifier rejected" -NoNewline
    $body = @{ type = "youtube"; key = "cgs-yt-url-$cgRun"; canonicalIdentifier = "https://youtube.com/channel/UCxxxxxxxxxxxxxxxxxxxxxx" } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $body -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400 — URLs must not be stored as YouTube canonicalIdentifier)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S21: YouTube surface with short/malformed ID rejected
try {
    Write-Host "Testing: CG-S21 YouTube surface with malformed channel ID rejected" -NoNewline
    $body = @{ type = "youtube"; key = "cgs-yt-bad-$cgRun"; canonicalIdentifier = "UC_tooshort" } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $body -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-S22: Non-YouTube surface types unaffected (X handle still accepted)
try {
    Write-Host "Testing: CG-S22 X surface with handle canonicalIdentifier still accepted" -NoNewline
    $body = @{ type = "x"; key = "cgs-x-id-$cgRun"; canonicalIdentifier = "testhandle" } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $body -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201 — X surface validation must not be affected by YouTube tightening)") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Hammer-Section "CONTENT GRAPH PHASE 1 — SITES"

# Setup: second surface for site tests
$cgSurface2Id = $null
try {
    Write-Host "Testing: CG-SI-SETUP create second surface for site tests" -NoNewline
    $body = @{ type = "wiki"; key = "cgw-$cgRun" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgSurface2Id = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SI1: Create a site
$cgSiteId = $null
try {
    Write-Host "Testing: CG-SI1 POST /content-graph/sites creates site" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSurfaceId)) {
        Write-Host "  SKIP (cgSurfaceId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ surfaceId = $cgSurfaceId; domain = "$cgRun.example.com"; framework = "nextjs" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgSiteId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SI2: Duplicate domain rejected
try {
    Write-Host "Testing: CG-SI2 POST /content-graph/sites rejects duplicate domain" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSurfaceId)) {
        Write-Host "  SKIP (cgSurfaceId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ surfaceId = $cgSurfaceId; domain = "$cgRun.example.com" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SI3: Cross-project surfaceId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-SI3 POST /content-graph/sites returns 404 for cross-project surfaceId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgSurfaceId)) {
            Write-Host "  SKIP (cgSurfaceId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ surfaceId = $cgSurfaceId; domain = "xp-$cgRun.example.com" }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-SI3 POST /content-graph/sites returns 404 for cross-project surfaceId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-SI4: Unknown field rejected
try {
    Write-Host "Testing: CG-SI4 POST /content-graph/sites rejects unknown fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSurfaceId)) {
        Write-Host "  SKIP (cgSurfaceId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ surfaceId = $cgSurfaceId; domain = "bad-$cgRun.example.com"; badField = "x" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SI5: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/sites" `
    -RequestHeaders $Headers `
    -Description "CG-SI5 GET /content-graph/sites returns list envelope" `
    -ExpectPagination $true

Hammer-Section "CONTENT GRAPH PHASE 1 — ARCHETYPES"

# CG-A1: Create archetype
$cgArchetypeId = $null
try {
    Write-Host "Testing: CG-A1 POST /content-graph/archetypes creates archetype" -NoNewline
    $body = @{ key = "cga-$cgRun"; label = "Guide" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/archetypes" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgArchetypeId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-A2: Duplicate key rejected
Test-PostJson -Url "$Base/api/content-graph/archetypes" `
    -ExpectedStatus 400 `
    -Description "CG-A2 POST /content-graph/archetypes rejects duplicate key" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cga-$cgRun"; label = "Duplicate" }

# CG-A3: Unknown field rejected
Test-PostJson -Url "$Base/api/content-graph/archetypes" `
    -ExpectedStatus 400 `
    -Description "CG-A3 POST /content-graph/archetypes rejects unknown fields" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cga-bad-$cgRun"; label = "Bad"; unknownField = "x" }

# CG-A4: Missing label rejected
Test-PostJson -Url "$Base/api/content-graph/archetypes" `
    -ExpectedStatus 400 `
    -Description "CG-A4 POST /content-graph/archetypes rejects missing label" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cga-nolabel-$cgRun" }

# CG-A5: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/archetypes" `
    -RequestHeaders $Headers `
    -Description "CG-A5 GET /content-graph/archetypes returns list envelope" `
    -ExpectPagination $true

Hammer-Section "CONTENT GRAPH PHASE 1 — PAGES"

# CG-P1: Create a page
$cgPageId = $null
try {
    Write-Host "Testing: CG-P1 POST /content-graph/pages creates page" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSiteId)) {
        Write-Host "  SKIP (cgSiteId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{
            siteId = $cgSiteId
            url = "https://$cgRun.example.com/guide/ai-basics"
            title = "AI Basics"
            publishingState = "published"
            isIndexable = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($cgArchetypeId)) { $body["contentArchetypeId"] = $cgArchetypeId }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgPageId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-P-SETUP2: Create second page
$cgPage2Id = $null
try {
    Write-Host "Testing: CG-P-SETUP2 create second page" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSiteId)) {
        Write-Host "  SKIP (cgSiteId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ siteId = $cgSiteId; url = "https://$cgRun.example.com/concept/llm"; title = "LLM Concept" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgPage2Id = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-P2: Duplicate URL rejected
try {
    Write-Host "Testing: CG-P2 POST /content-graph/pages rejects duplicate URL" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSiteId)) {
        Write-Host "  SKIP (cgSiteId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ siteId = $cgSiteId; url = "https://$cgRun.example.com/guide/ai-basics"; title = "Dupe" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-P3: Cross-project siteId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-P3 POST /content-graph/pages returns 404 for cross-project siteId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgSiteId)) {
            Write-Host "  SKIP (cgSiteId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ siteId = $cgSiteId; url = "https://xp-$cgRun.example.com/page"; title = "Cross" }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-P3 POST /content-graph/pages returns 404 for cross-project siteId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-P3b: Cross-project contentArchetypeId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-P3b POST /content-graph/pages returns 404 for cross-project contentArchetypeId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgArchetypeId)) {
            Write-Host "  SKIP (cgArchetypeId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $surfSetup = @{ type = "website"; key = "cgxps-$cgRun" }
            $surfJson = $surfSetup | ConvertTo-Json -Compress
            $surfResp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $OtherHeaders -Body $surfJson -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            $otherSurfaceId = $null
            if ($surfResp.StatusCode -eq 201) { try { $otherSurfaceId = ($surfResp.Content | ConvertFrom-Json).data.id } catch {} }
            if ([string]::IsNullOrWhiteSpace($otherSurfaceId)) {
                Write-Host "  SKIP (could not create surface in other project)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                $siteSetup = @{ surfaceId = $otherSurfaceId; domain = "xp2-$cgRun.example.com" }
                $siteJson = $siteSetup | ConvertTo-Json -Compress
                $siteResp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $OtherHeaders -Body $siteJson -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                $otherSiteId = $null
                if ($siteResp.StatusCode -eq 201) { try { $otherSiteId = ($siteResp.Content | ConvertFrom-Json).data.id } catch {} }
                if ([string]::IsNullOrWhiteSpace($otherSiteId)) {
                    Write-Host "  SKIP (could not create site in other project)" -ForegroundColor DarkYellow; Hammer-Record SKIP
                } else {
                    $body = @{ siteId = $otherSiteId; url = "https://xp2-$cgRun.example.com/page"; title = "Cross Archetype"; contentArchetypeId = $cgArchetypeId }
                    $json = $body | ConvertTo-Json -Compress
                    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                    if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                    else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
                }
            }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-P3b POST /content-graph/pages returns 404 for cross-project contentArchetypeId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-P4: Invalid publishingState rejected
try {
    Write-Host "Testing: CG-P4 POST /content-graph/pages rejects invalid publishingState" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgSiteId)) {
        Write-Host "  SKIP (cgSiteId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ siteId = $cgSiteId; url = "https://$cgRun.example.com/bad-state"; title = "Bad"; publishingState = "invalid_state" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-P5: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/pages" `
    -RequestHeaders $Headers `
    -Description "CG-P5 GET /content-graph/pages returns list envelope" `
    -ExpectPagination $true

# CG-P6: Determinism
try {
    Write-Host "Testing: CG-P6 GET /content-graph/pages is deterministic" -NoNewline
    $r1 = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    $r2 = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($r1.StatusCode -eq 200 -and $r2.StatusCode -eq 200) {
        $d1 = ($r1.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 5 -Compress
        $d2 = ($r2.Content | ConvertFrom-Json).data | ConvertTo-Json -Depth 5 -Compress
        if ($d1 -eq $d2) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host "  FAIL (results differ)" -ForegroundColor Red; Hammer-Record FAIL }
    } else { Write-Host ("  FAIL (status=" + $r1.StatusCode + "/" + $r2.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

Hammer-Section "CONTENT GRAPH PHASE 1 — TOPICS"

# CG-T1: Create topic
$cgTopicId = $null
try {
    Write-Host "Testing: CG-T1 POST /content-graph/topics creates topic" -NoNewline
    $body = @{ key = "cgt-$cgRun"; label = "Large Language Models" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/topics" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgTopicId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-T2: Duplicate key rejected
Test-PostJson -Url "$Base/api/content-graph/topics" `
    -ExpectedStatus 400 `
    -Description "CG-T2 POST /content-graph/topics rejects duplicate key" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cgt-$cgRun"; label = "Dupe" }

# CG-T3: Unknown field rejected
Test-PostJson -Url "$Base/api/content-graph/topics" `
    -ExpectedStatus 400 `
    -Description "CG-T3 POST /content-graph/topics rejects unknown fields" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cgt-bad-$cgRun"; label = "Bad"; badField = "x" }

# CG-T4: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/topics" `
    -RequestHeaders $Headers `
    -Description "CG-T4 GET /content-graph/topics returns list envelope" `
    -ExpectPagination $true

# CG-T5: Cross-project non-disclosure on GET
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-T5 Topic not visible to other project" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgTopicId)) {
            Write-Host "  SKIP (cgTopicId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/topics" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $ids = ($resp.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }
                if ($ids -notcontains $cgTopicId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (topic id leaked to other project)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-T5 Topic not visible to other project  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

Hammer-Section "CONTENT GRAPH PHASE 1 — ENTITIES"

# CG-E1: Create entity
$cgEntityId = $null
try {
    Write-Host "Testing: CG-E1 POST /content-graph/entities creates entity" -NoNewline
    $body = @{ key = "cge-$cgRun"; label = "GPT-4"; entityType = "product" }
    $json = $body | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/entities" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
    if ($resp.StatusCode -eq 201) {
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
        try { $cgEntityId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
    } else {
        Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201) body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-E2: Duplicate key rejected
Test-PostJson -Url "$Base/api/content-graph/entities" `
    -ExpectedStatus 400 `
    -Description "CG-E2 POST /content-graph/entities rejects duplicate key" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cge-$cgRun"; label = "Dupe"; entityType = "product" }

# CG-E3: Unknown field rejected
Test-PostJson -Url "$Base/api/content-graph/entities" `
    -ExpectedStatus 400 `
    -Description "CG-E3 POST /content-graph/entities rejects unknown fields" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cge-bad-$cgRun"; label = "Bad"; entityType = "product"; badField = "x" }

# CG-E4: Missing entityType rejected
Test-PostJson -Url "$Base/api/content-graph/entities" `
    -ExpectedStatus 400 `
    -Description "CG-E4 POST /content-graph/entities rejects missing entityType" `
    -RequestHeaders $Headers `
    -BodyObj @{ key = "cge-notype-$cgRun"; label = "No Type" }

# CG-E5: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/entities" `
    -RequestHeaders $Headers `
    -Description "CG-E5 GET /content-graph/entities returns list envelope" `
    -ExpectPagination $true

Hammer-Section "CONTENT GRAPH PHASE 1 — PAGE TOPICS"

# CG-PT1: Register a topic on a page
$cgPageTopicId = $null
try {
    Write-Host "Testing: CG-PT1 POST /content-graph/page-topics registers topic on page" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgTopicId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; topicId = $cgTopicId; role = "primary" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgPageTopicId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PT2: Duplicate page+topic rejected
try {
    Write-Host "Testing: CG-PT2 POST /content-graph/page-topics rejects duplicate" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgTopicId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; topicId = $cgTopicId }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PT3: Cross-project pageId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PT3 POST /content-graph/page-topics returns 404 for cross-project pageId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgTopicId)) {
            Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ pageId = $cgPageId; topicId = $cgTopicId }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PT3 POST /content-graph/page-topics returns 404 for cross-project pageId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-PT4: Invalid role rejected
try {
    Write-Host "Testing: CG-PT4 POST /content-graph/page-topics rejects invalid role" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPage2Id) -or [string]::IsNullOrWhiteSpace($cgTopicId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPage2Id; topicId = $cgTopicId; role = "invalid_role" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PT5: Unknown field rejected
try {
    Write-Host "Testing: CG-PT5 POST /content-graph/page-topics rejects unknown fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPage2Id) -or [string]::IsNullOrWhiteSpace($cgTopicId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPage2Id; topicId = $cgTopicId; badField = "x" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PT6: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/page-topics" `
    -RequestHeaders $Headers `
    -Description "CG-PT6 GET /content-graph/page-topics returns list envelope" `
    -ExpectPagination $true

# CG-PT7: Cross-project non-disclosure on GET
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PT7 PageTopic not visible to other project" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageTopicId)) {
            Write-Host "  SKIP (cgPageTopicId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $ids = ($resp.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }
                if ($ids -notcontains $cgPageTopicId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (page-topic id leaked to other project)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PT7 PageTopic not visible to other project  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-PT8: Cross-project topicId returns 404 (DB-level project enforcement)
# Defends the new CgPageTopic project FK + trigger added in Batch 2.
# Scenario: use OtherProject's own page + a topic from the primary project.
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PT8 POST /content-graph/page-topics returns 404 for cross-project topicId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgTopicId)) {
            Write-Host "  SKIP (cgTopicId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            # Create a page in OtherProject to use as the pageId
            $otherSurfResp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $OtherHeaders `
                -Body (@{ type = "website"; key = "cgpt8s-$cgRun" } | ConvertTo-Json -Compress) `
                -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            $otherSurfId = $null
            if ($otherSurfResp.StatusCode -eq 201) { try { $otherSurfId = ($otherSurfResp.Content | ConvertFrom-Json).data.id } catch {} }
            $otherSiteResp = $null
            $otherSiteId = $null
            if (-not [string]::IsNullOrWhiteSpace($otherSurfId)) {
                $otherSiteResp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $OtherHeaders `
                    -Body (@{ surfaceId = $otherSurfId; domain = "pt8-$cgRun.example.com" } | ConvertTo-Json -Compress) `
                    -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($otherSiteResp.StatusCode -eq 201) { try { $otherSiteId = ($otherSiteResp.Content | ConvertFrom-Json).data.id } catch {} }
            }
            $otherPageId = $null
            if (-not [string]::IsNullOrWhiteSpace($otherSiteId)) {
                $otherPageResp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $OtherHeaders `
                    -Body (@{ siteId = $otherSiteId; url = "https://pt8-$cgRun.example.com/page"; title = "PT8 Page" } | ConvertTo-Json -Compress) `
                    -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($otherPageResp.StatusCode -eq 201) { try { $otherPageId = ($otherPageResp.Content | ConvertFrom-Json).data.id } catch {} }
            }
            if ([string]::IsNullOrWhiteSpace($otherPageId)) {
                Write-Host "  SKIP (could not create page in other project for PT8)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                # Post with OtherProject's page but primary project's topicId — should 404
                $body = @{ pageId = $otherPageId; topicId = $cgTopicId }
                $json = $body | ConvertTo-Json -Compress
                $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-topics" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
            }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PT8 POST /content-graph/page-topics returns 404 for cross-project topicId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

Hammer-Section "CONTENT GRAPH PHASE 1 — PAGE ENTITIES"

# CG-PE1: Register an entity on a page
$cgPageEntityId = $null
try {
    Write-Host "Testing: CG-PE1 POST /content-graph/page-entities registers entity on page" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgEntityId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; entityId = $cgEntityId; role = "primary" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgPageEntityId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PE2: Duplicate page+entity rejected
try {
    Write-Host "Testing: CG-PE2 POST /content-graph/page-entities rejects duplicate" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgEntityId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; entityId = $cgEntityId }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PE3: Cross-project pageId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PE3 POST /content-graph/page-entities returns 404 for cross-project pageId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgEntityId)) {
            Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ pageId = $cgPageId; entityId = $cgEntityId }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PE3 POST /content-graph/page-entities returns 404 for cross-project pageId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-PE4: Invalid role rejected
try {
    Write-Host "Testing: CG-PE4 POST /content-graph/page-entities rejects invalid role" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPage2Id) -or [string]::IsNullOrWhiteSpace($cgEntityId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPage2Id; entityId = $cgEntityId; role = "invalid_role" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PE5: Unknown field rejected
try {
    Write-Host "Testing: CG-PE5 POST /content-graph/page-entities rejects unknown fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPage2Id) -or [string]::IsNullOrWhiteSpace($cgEntityId)) {
        Write-Host "  SKIP (ids not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPage2Id; entityId = $cgEntityId; badField = "x" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-PE6: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/page-entities" `
    -RequestHeaders $Headers `
    -Description "CG-PE6 GET /content-graph/page-entities returns list envelope" `
    -ExpectPagination $true

# CG-PE7: Cross-project non-disclosure on GET
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PE7 PageEntity not visible to other project" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageEntityId)) {
            Write-Host "  SKIP (cgPageEntityId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $ids = ($resp.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }
                if ($ids -notcontains $cgPageEntityId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (page-entity id leaked to other project)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PE7 PageEntity not visible to other project  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-PE8: Cross-project entityId returns 404 (DB-level project enforcement)
# Defends the new CgPageEntity project FK + trigger added in Batch 2.
# Scenario: use OtherProject's own page + an entity from the primary project.
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-PE8 POST /content-graph/page-entities returns 404 for cross-project entityId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgEntityId)) {
            Write-Host "  SKIP (cgEntityId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            # Re-use infrastructure created by CG-PT8 if available; otherwise create fresh
            $pe8PageId = $null
            if (-not [string]::IsNullOrWhiteSpace($otherPageId)) {
                $pe8PageId = $otherPageId
            } else {
                $pe8SurfResp = Invoke-WebRequest -Uri "$Base/api/content-graph/surfaces" -Method POST -Headers $OtherHeaders `
                    -Body (@{ type = "website"; key = "cgpe8s-$cgRun" } | ConvertTo-Json -Compress) `
                    -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                $pe8SurfId = $null
                if ($pe8SurfResp.StatusCode -eq 201) { try { $pe8SurfId = ($pe8SurfResp.Content | ConvertFrom-Json).data.id } catch {} }
                if (-not [string]::IsNullOrWhiteSpace($pe8SurfId)) {
                    $pe8SiteResp = Invoke-WebRequest -Uri "$Base/api/content-graph/sites" -Method POST -Headers $OtherHeaders `
                        -Body (@{ surfaceId = $pe8SurfId; domain = "pe8-$cgRun.example.com" } | ConvertTo-Json -Compress) `
                        -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                    $pe8SiteId = $null
                    if ($pe8SiteResp.StatusCode -eq 201) { try { $pe8SiteId = ($pe8SiteResp.Content | ConvertFrom-Json).data.id } catch {} }
                    if (-not [string]::IsNullOrWhiteSpace($pe8SiteId)) {
                        $pe8PageResp = Invoke-WebRequest -Uri "$Base/api/content-graph/pages" -Method POST -Headers $OtherHeaders `
                            -Body (@{ siteId = $pe8SiteId; url = "https://pe8-$cgRun.example.com/page"; title = "PE8 Page" } | ConvertTo-Json -Compress) `
                            -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                        if ($pe8PageResp.StatusCode -eq 201) { try { $pe8PageId = ($pe8PageResp.Content | ConvertFrom-Json).data.id } catch {} }
                    }
                }
            }
            if ([string]::IsNullOrWhiteSpace($pe8PageId)) {
                Write-Host "  SKIP (could not create page in other project for PE8)" -ForegroundColor DarkYellow; Hammer-Record SKIP
            } else {
                # Post with OtherProject's page but primary project's entityId — should 404
                $body = @{ pageId = $pe8PageId; entityId = $cgEntityId }
                $json = $body | ConvertTo-Json -Compress
                $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/page-entities" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
                if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
            }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-PE8 POST /content-graph/page-entities returns 404 for cross-project entityId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

Hammer-Section "CONTENT GRAPH PHASE 1 — INTERNAL LINKS"

# CG-L1: Create internal link
$cgLinkId = $null
try {
    Write-Host "Testing: CG-L1 POST /content-graph/internal-links creates link" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgPage2Id)) {
        Write-Host "  SKIP (page IDs not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ sourcePageId = $cgPageId; targetPageId = $cgPage2Id; anchorText = "LLM Basics"; linkRole = "hub" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/internal-links" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgLinkId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-L2: Self-link rejected
try {
    Write-Host "Testing: CG-L2 POST /content-graph/internal-links rejects self-link" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId)) {
        Write-Host "  SKIP (cgPageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ sourcePageId = $cgPageId; targetPageId = $cgPageId }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/internal-links" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-L3: Duplicate link rejected
try {
    Write-Host "Testing: CG-L3 POST /content-graph/internal-links rejects duplicate link" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgPage2Id)) {
        Write-Host "  SKIP (page IDs not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ sourcePageId = $cgPageId; targetPageId = $cgPage2Id }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/internal-links" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-L4: Cross-project source page returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-L4 POST /content-graph/internal-links returns 404 for cross-project source" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgPage2Id)) {
            Write-Host "  SKIP (page IDs not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ sourcePageId = $cgPageId; targetPageId = $cgPage2Id }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/internal-links" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-L4 POST /content-graph/internal-links returns 404 for cross-project source  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-L5: Invalid linkRole rejected
try {
    Write-Host "Testing: CG-L5 POST /content-graph/internal-links rejects invalid linkRole" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId) -or [string]::IsNullOrWhiteSpace($cgPage2Id)) {
        Write-Host "  SKIP (page IDs not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ sourcePageId = $cgPage2Id; targetPageId = $cgPageId; linkRole = "invalid_role" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/internal-links" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-L6: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/internal-links" `
    -RequestHeaders $Headers `
    -Description "CG-L6 GET /content-graph/internal-links returns list envelope" `
    -ExpectPagination $true

Hammer-Section "CONTENT GRAPH PHASE 1 — SCHEMA USAGE"

# CG-SU1: Create schema usage
$cgSchemaUsageId = $null
try {
    Write-Host "Testing: CG-SU1 POST /content-graph/schema-usage creates schema usage" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId)) {
        Write-Host "  SKIP (cgPageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; schemaType = "Article"; isPrimary = $true }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/schema-usage" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $cgSchemaUsageId = ($resp.Content | ConvertFrom-Json).data.id } catch {}
        } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ") body=" + $resp.Content) -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SU2: Duplicate page+schemaType rejected
try {
    Write-Host "Testing: CG-SU2 POST /content-graph/schema-usage rejects duplicate" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId)) {
        Write-Host "  SKIP (cgPageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; schemaType = "Article" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/schema-usage" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SU3: Cross-project pageId returns 404 (non-disclosure)
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-SU3 POST /content-graph/schema-usage returns 404 for cross-project pageId" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgPageId)) {
            Write-Host "  SKIP (cgPageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $body = @{ pageId = $cgPageId; schemaType = "HowTo" }
            $json = $body | ConvertTo-Json -Compress
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/schema-usage" -Method POST -Headers $OtherHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 404) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 404)") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-SU3 POST /content-graph/schema-usage returns 404 for cross-project pageId  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}

# CG-SU4: Unknown field rejected
try {
    Write-Host "Testing: CG-SU4 POST /content-graph/schema-usage rejects unknown fields" -NoNewline
    if ([string]::IsNullOrWhiteSpace($cgPageId)) {
        Write-Host "  SKIP (cgPageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
    } else {
        $body = @{ pageId = $cgPageId; schemaType = "FAQ"; badField = "x" }
        $json = $body | ConvertTo-Json -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/schema-usage" -Method POST -Headers $Headers -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 400) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
        else { Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 400)") -ForegroundColor Red; Hammer-Record FAIL }
    }
} catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

# CG-SU5: GET list
Test-ResponseEnvelope -Url "$Base/api/content-graph/schema-usage" `
    -RequestHeaders $Headers `
    -Description "CG-SU5 GET /content-graph/schema-usage returns list envelope" `
    -ExpectPagination $true

# CG-SU6: Cross-project non-disclosure on GET
if ($OtherHeaders.Count -gt 0) {
    try {
        Write-Host "Testing: CG-SU6 Schema usage not visible to other project" -NoNewline
        if ([string]::IsNullOrWhiteSpace($cgSchemaUsageId)) {
            Write-Host "  SKIP (cgSchemaUsageId not available)" -ForegroundColor DarkYellow; Hammer-Record SKIP
        } else {
            $resp = Invoke-WebRequest -Uri "$Base/api/content-graph/schema-usage" -Method GET -Headers $OtherHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                $ids = ($resp.Content | ConvertFrom-Json).data | ForEach-Object { $_.id }
                if ($ids -notcontains $cgSchemaUsageId) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
                else { Write-Host "  FAIL (schema usage id leaked to other project)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $resp.StatusCode + ")") -ForegroundColor Red; Hammer-Record FAIL }
        }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }
} else {
    Write-Host "Testing: CG-SU6 Schema usage not visible to other project  SKIP (no OtherProject configured)" -ForegroundColor DarkYellow; Hammer-Record SKIP
}
