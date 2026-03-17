# hammer-core.ps1 — smoke, graph, W2, audits, draft lifecycle, ordering, promotion
# Dot-sourced by api-hammer.ps1. Inherits all symbols from hammer-lib.ps1 + coordinator.

Hammer-Section "SMOKE TESTS (GET)"

Test-Endpoint "GET" "$Base/api/projects" 200 "GET /api/projects" @{}
Test-Endpoint "GET" "$Base/api/entities" 200 "GET /api/entities" $Headers

Hammer-Section "GRAPH TESTS"

if (-not $entityId) {
    Write-Host "Skipping graph tests: no entities found" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    Test-Endpoint "GET" "$Base/api/entities/$entityId/graph"          200 "GET graph depth=1"    $Headers
    Test-Endpoint "GET" "$Base/api/entities/$entityId/graph?depth=2"  200 "GET graph depth=2"    $Headers
    Test-Endpoint "GET" "$Base/api/entities/$entityId/graph?depth=3"  400 "Invalid depth=3"      $Headers
    if ($OtherHeaders.Count -gt 0) {
        Test-Endpoint "GET" "$Base/api/entities/$entityId/graph"      404 "Cross-project graph fetch" $OtherHeaders
    }
}

Hammer-Section "VERIFY FRESHNESS TESTS (W2)"

if (-not $entityId) {
    Write-Host "Skipping verify-freshness tests: no entityId" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    try {
        Write-Host "Testing: POST /api/entities/:id/verify-freshness (valid, no body) -> 200" -NoNewline
        $vfResp = Invoke-WebRequest -Uri "$Base/api/entities/$entityId/verify-freshness" -Method POST -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($vfResp.StatusCode -eq 200) {
            $vfParsed = $vfResp.Content | ConvertFrom-Json
            if ($vfParsed.data -ne $null -and $null -ne $vfParsed.data.lastVerifiedAt) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS }
            else { Write-Host "  FAIL (missing data or lastVerifiedAt not populated)" -ForegroundColor Red; Hammer-Record FAIL }
        } else { Write-Host ("  FAIL (got " + $vfResp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

    Test-PostEmpty "$Base/api/entities/not-a-uuid/verify-freshness"                      400 "POST verify-freshness invalid UUID -> 400"       $Headers
    Test-PostEmpty "$Base/api/entities/00000000-0000-4000-a000-000000000099/verify-freshness" 404 "POST verify-freshness not found -> 404"      $Headers
    if ($OtherHeaders.Count -gt 0) {
        Test-PostEmpty "$Base/api/entities/$entityId/verify-freshness" 404 "POST verify-freshness cross-project -> 404" $OtherHeaders
    }
}

Hammer-Section "AUDITS TESTS (S0 RUN)"

if (-not $entityId) {
    Write-Host "Skipping audits/run tests: no entities found" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    $runBody   = @{ entityId = $entityId }
    $runResult = Test-PostJsonCapture "$Base/api/audits/run" 201 "POST /api/audits/run (valid)" $Headers $runBody

    Test-PostJson "$Base/api/audits/run" 400 "POST /api/audits/run rejects unknown field"  $Headers @{ entityId = $entityId; nope = "x" }
    Test-PostJson "$Base/api/audits/run" 400 "POST /api/audits/run rejects invalid uuid"   $Headers @{ entityId = "not-a-uuid" }
    if ($OtherHeaders.Count -gt 0) {
        Test-PostJson "$Base/api/audits/run" 404 "POST /api/audits/run cross-project non-disclosure" $OtherHeaders $runBody
    }

    Test-Endpoint "GET" "$Base/api/audits?limit=5"           200 "GET /api/audits (list)"            $Headers
    Test-Endpoint "GET" "$Base/api/audits?status=archived"   200 "GET /api/audits status=archived"   $Headers
    Test-Endpoint "GET" "$Base/api/audits?includeExpired=true" 200 "GET /api/audits includeExpired=true" $Headers
    Test-Endpoint "GET" "$Base/api/audits?status=invalid"    400 "GET /api/audits invalid status"    $Headers
    Test-Endpoint "GET" "$Base/api/audits?includeExpired=maybe" 400 "GET /api/audits invalid includeExpired" $Headers

    $auditId = $null
    if ($runResult -and $runResult.data -and $runResult.data.id) {
        $auditId = ($runResult.data.id).ToString().Trim()
    } else {
        $auditList = Try-GetJson -Url "$Base/api/audits?limit=1" -RequestHeaders $Headers
        if ($auditList -and $auditList.data -and $auditList.data.Count -gt 0) { $auditId = ($auditList.data[0].id).ToString().Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($auditId) -or $auditId -notmatch '^[0-9a-fA-F-]{36}$') { $auditId = $null }

    if ($auditId) {
        Test-Endpoint "GET" "$Base/api/audits/$auditId"                       200 "GET /api/audits/:id (valid)"                  $Headers
        Test-Endpoint "GET" (Build-Url "/api/audits/$auditId" @{ status="draft"; includeExplain="true" }) 200 "GET /api/audits/:id includeExplain=true" $Headers
        Test-Endpoint "GET" "$Base/api/audits/$auditId?includeExplain=maybe"  400 "GET /api/audits/:id includeExplain invalid"   $Headers
        Test-Endpoint "GET" "$Base/api/audits/$auditId?includePromotion=maybe" 400 "GET /api/audits/:id includePromotion invalid" $Headers
        if ($OtherHeaders.Count -gt 0) {
            Test-Endpoint "GET" "$Base/api/audits/$auditId" 404 "GET /api/audits/:id cross-project non-disclosure" $OtherHeaders
        }
    } else {
        Write-Host "Skipping audits/:id tests: no audit id available" -ForegroundColor DarkYellow; Hammer-Record SKIP
    }

    Test-Endpoint "GET" "$Base/api/audits/not-a-uuid"                        400 "GET /api/audits/:id invalid uuid" $Headers
    Test-Endpoint "GET" "$Base/api/audits/00000000-0000-4000-a000-000000000009" 404 "GET /api/audits/:id not found" $Headers
}

Hammer-Section "DRAFT-ARTIFACTS TESTS (BYDA-S S0)"

$draftId = $null

if (-not $entityId) {
    Write-Host "Skipping draft-artifacts tests: no entities found" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    $create1 = Create-DraftArtifact -EntityId $entityId -RequestHeaders $Headers -DescriptionPrefix "POST /api/draft-artifacts (valid, capture id for lifecycle)"
    if ($create1.ok) { $draftId = ($create1.id).ToString().Trim() }
    if ([string]::IsNullOrWhiteSpace($draftId) -or $draftId -notmatch '^[0-9a-fA-F-]{36}$') { $draftId = $null }

    Test-Endpoint "GET" "$Base/api/draft-artifacts?limit=5" 200 "GET /api/draft-artifacts (list)" $Headers

    $unknownBody = $create1.body.Clone(); $unknownBody["nope"] = "x"
    Test-PostJson "$Base/api/draft-artifacts" 400 "POST draft-artifacts rejects unknown body field"   $Headers $unknownBody
    Test-PostJson "$Base/api/draft-artifacts" 400 "POST draft-artifacts rejects mismatched entityId" $Headers @{
        kind = "byda_s_audit"; entityId = $entityId
        content = @{ schemaVersion = "byda.s0.v1"; entityId = "00000000-0000-4000-a000-000000000002"; scores = @{ citability=50; extractability=50; factualDensity=50 }; createdAt=(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
    }
    $badScore = $create1.body.Clone(); $badScore.content = $create1.body.content.Clone(); $badScore.content.scores = $create1.body.content.scores.Clone(); $badScore.content.scores.citability = 101
    Test-PostJson "$Base/api/draft-artifacts" 400 "POST draft-artifacts rejects score out of range" $Headers $badScore
    if ($OtherHeaders.Count -gt 0) {
        Test-PostJson "$Base/api/draft-artifacts" 404 "POST draft-artifacts cross-project non-disclosure" $OtherHeaders $create1.body
    }
}

Hammer-Section "DRAFT LIFECYCLE TESTS (ARCHIVE)"

if (-not $draftId) {
    Write-Host "Skipping archive tests: no draftId captured" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    Test-Patch "$Base/api/draft-artifacts/$draftId/archive"          200 "PATCH archive (draft -> archived)"         $Headers
    Test-Patch "$Base/api/draft-artifacts/$draftId/archive"          400 "PATCH archive (already archived)"          $Headers
    if ($OtherHeaders.Count -gt 0) {
        Test-Patch "$Base/api/draft-artifacts/$draftId/archive"      404 "PATCH archive cross-project non-disclosure" $OtherHeaders
    }
    Test-Patch "$Base/api/draft-artifacts/not-a-uuid/archive"        400 "PATCH archive invalid uuid"                $Headers
}

Hammer-Section "DRAFT LIFECYCLE TESTS (EXPIRE)"

Test-PostEmpty "$Base/api/draft-artifacts/expire" 200 "POST /api/draft-artifacts/expire (ttl enforcement)" $Headers

Hammer-Section "DETERMINISTIC ORDERING TEST"

$_list1 = Try-GetJson -Url "$Base/api/entities?limit=10" -RequestHeaders $Headers
$_list2 = Try-GetJson -Url "$Base/api/entities?limit=10" -RequestHeaders $Headers
if ($_list1 -and $_list2 -and $_list1.data -and $_list2.data) {
    $ids1 = $_list1.data | ForEach-Object { $_.id }
    $ids2 = $_list2.data | ForEach-Object { $_.id }
    $orderMatch = ($ids1.Count -eq $ids2.Count)
    if ($orderMatch) { for ($i=0; $i -lt $ids1.Count; $i++) { if ($ids1[$i] -ne $ids2[$i]) { $orderMatch=$false; break } } }
    Write-Host "Testing: Entities list ordering deterministic" -NoNewline
    if ($orderMatch) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL" -ForegroundColor Red; Hammer-Record FAIL }
} else { Write-Host "Skipping ordering test: unable to fetch entity lists" -ForegroundColor DarkYellow; Hammer-Record SKIP }

Hammer-Section "DRAFT PROMOTION TESTS (PROMOTE)"

if (-not $entityId) {
    Write-Host "Skipping promote tests: no entityId" -ForegroundColor DarkYellow; Hammer-Record SKIP
} else {
    $draftIdForPromote = $null
    $runPromoteResult = Test-PostJsonCapture "$Base/api/audits/run" 201 "POST /api/audits/run (create audit for promote)" $Headers @{ entityId = $entityId }
    if ($runPromoteResult.ok -and $runPromoteResult.data -and $runPromoteResult.data.id) {
        $draftIdForPromote = ($runPromoteResult.data.id).ToString().Trim()
    }
    if ([string]::IsNullOrWhiteSpace($draftIdForPromote) -or $draftIdForPromote -notmatch '^[0-9a-fA-F-]{36}$') { $draftIdForPromote = $null }

    if ($draftIdForPromote) {
        Test-PostEmpty "$Base/api/draft-artifacts/$draftIdForPromote/promote" 200 "POST promote (draft -> metric snapshots + archive)" $Headers

        try {
            Write-Host "Testing: GET /api/audits/:id includePromotion=true (promoted)" -NoNewline
            $promResp = Invoke-WebRequest -Uri "$Base/api/audits/$draftIdForPromote`?includePromotion=true" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($promResp.StatusCode -eq 200) {
                $promParsed = $promResp.Content | ConvertFrom-Json
                if ($promParsed.data -ne $null) {
                    $promProps = $promParsed.data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    if ($promProps -contains "promotion") { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (promotion field missing)" -ForegroundColor Red; Hammer-Record FAIL }
                } else { Write-Host "  FAIL (missing data envelope)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $promResp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

        try {
            Write-Host "Testing: GET /api/audits/:id includeExplain=true (promoted)" -NoNewline
            $explainResp = Invoke-WebRequest -Uri "$Base/api/audits/$draftIdForPromote`?includeExplain=true" -Method GET -Headers $Headers -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
            if ($explainResp.StatusCode -eq 200) {
                $explainParsed = $explainResp.Content | ConvertFrom-Json
                if ($explainParsed.data -ne $null) {
                    $explainProps = $explainParsed.data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                    if ($explainProps -contains "explain") { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS } else { Write-Host "  FAIL (explain field missing)" -ForegroundColor Red; Hammer-Record FAIL }
                } else { Write-Host "  FAIL (missing data envelope)" -ForegroundColor Red; Hammer-Record FAIL }
            } else { Write-Host ("  FAIL (got " + $explainResp.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL }
        } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL }

        Test-PostEmpty "$Base/api/draft-artifacts/$draftIdForPromote/promote" 400 "POST promote (already archived)"          $Headers
        if ($OtherHeaders.Count -gt 0) {
            Test-PostEmpty "$Base/api/draft-artifacts/$draftIdForPromote/promote" 404 "POST promote cross-project non-disclosure" $OtherHeaders
        }
    } else {
        Write-Host "Skipping promote tests: no draftIdForPromote captured" -ForegroundColor DarkYellow; Hammer-Record SKIP
    }

    Test-PostEmpty "$Base/api/draft-artifacts/not-a-uuid/promote" 400 "POST promote invalid uuid" $Headers
}
