# hammer-lib.ps1 — shared helpers, Hammer-Record, Hammer-Section
# Dot-sourced by api-hammer.ps1 (coordinator). All symbols land in coordinator scope.

# ── Duplicate-section sentinel registry ───────────────────────────────────────
$script:SeenSections = @{}

function Hammer-Section {
    param([string]$Name)
    if ($script:SeenSections.ContainsKey($Name)) {
        Write-Host ("DUPLICATE SECTION: " + $Name + " -- aborting") -ForegroundColor Red
        $script:FailCount++
        exit 1
    }
    $script:SeenSections[$Name] = $true
    Write-Host ""
    Write-Host ("=== " + $Name + " ===") -ForegroundColor Yellow
}

# ── Centralized counter ────────────────────────────────────────────────────────
function Hammer-Record {
    param([ValidateSet("PASS","FAIL","SKIP")][string]$Result)
    switch ($Result) {
        "PASS" { $script:PassCount++ }
        "FAIL" { $script:FailCount++ }
        "SKIP" { $script:SkipCount++ }
    }
}

# ── URL helpers ───────────────────────────────────────────────────────────────
function Build-QueryString {
    param([hashtable]$Params)
    if (-not $Params -or $Params.Count -eq 0) { return "" }
    $parts = @()
    foreach ($k in ($Params.Keys | Sort-Object)) {
        if ($null -eq $k) { continue }
        $key = ($k.ToString()).Trim()
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        $raw = $Params[$k]
        if ($null -eq $raw) { continue }
        $val = ($raw.ToString()).Trim()
        if ([string]::IsNullOrWhiteSpace($val)) { continue }
        $parts += [System.Uri]::EscapeDataString($key) + "=" + [System.Uri]::EscapeDataString($val)
    }
    return ($parts -join "&")
}

function Build-Url {
    param([Parameter(Mandatory=$true)][string]$Path, [hashtable]$Params)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "Build-Url requires non-empty Path" }
    if (-not $Path.StartsWith('/')) { $Path = '/' + $Path }
    $qs = Build-QueryString -Params $Params
    if ([string]::IsNullOrWhiteSpace($qs)) { return "$Base$Path" }
    return "$Base$Path`?$qs"
}

function Get-ProjectHeaders {
    param([string]$ProjectIdValue, [string]$ProjectSlugValue)
    $headers = @{}
    if ($ProjectIdValue)   { $headers["x-project-id"]   = $ProjectIdValue;   return $headers }
    if ($ProjectSlugValue) { $headers["x-project-slug"] = $ProjectSlugValue; return $headers }
    return $headers
}

# ── HTTP test helpers ─────────────────────────────────────────────────────────
function Test-Endpoint {
    param([string]$Method,[string]$Url,[int]$ExpectedStatus,[string]$Description,[hashtable]$RequestHeaders)
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $response = Invoke-WebRequest -Uri $Url -Method $Method -Headers $RequestHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS; return $true }
        else { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected " + $ExpectedStatus + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
}

function Test-PostJson {
    param([string]$Url,[int]$ExpectedStatus,[string]$Description,[hashtable]$RequestHeaders,[object]$BodyObj)
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $json = $BodyObj | ConvertTo-Json -Depth 10 -Compress
        $response = Invoke-WebRequest -Uri $Url -Method POST -Headers $RequestHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS; return $true }
        else { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected " + $ExpectedStatus + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
}

function Test-PostJsonCapture {
    param([string]$Url,[int]$ExpectedStatus,[string]$Description,[hashtable]$RequestHeaders,[object]$BodyObj)
    $result = @{ ok = $false; data = $null }
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $json = $BodyObj | ConvertTo-Json -Depth 10 -Compress
        $response = Invoke-WebRequest -Uri $Url -Method POST -Headers $RequestHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $parsed = $response.Content | ConvertFrom-Json; $result.ok = $true; $result.data = $parsed.data } catch { $result.ok = $true }
            return $result
        } else { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected " + $ExpectedStatus + ")") -ForegroundColor Red; Hammer-Record FAIL; return $result }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $result }
}

function Test-PostEmpty {
    param([string]$Url,[int]$ExpectedStatus,[string]$Description,[hashtable]$RequestHeaders)
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $response = Invoke-WebRequest -Uri $Url -Method POST -Headers $RequestHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS; return $true }
        else { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected " + $ExpectedStatus + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
}

function Test-Patch {
    param([string]$Url,[int]$ExpectedStatus,[string]$Description,[hashtable]$RequestHeaders)
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $response = Invoke-WebRequest -Uri $Url -Method PATCH -Headers $RequestHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatus) { Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS; return $true }
        else { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected " + $ExpectedStatus + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
}

function Try-GetJson {
    param([string]$Url,[hashtable]$RequestHeaders)
    try { return Invoke-RestMethod -Uri $Url -Method GET -Headers $RequestHeaders -TimeoutSec 30 } catch { return $null }
}

function Test-ResponseEnvelope {
    param([string]$Url,[hashtable]$RequestHeaders,[string]$Description,[bool]$ExpectPagination=$false)
    try {
        Write-Host ("Testing: " + $Description) -NoNewline
        $response = Invoke-WebRequest -Uri $Url -Method GET -Headers $RequestHeaders -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($response.StatusCode -ne 200) { Write-Host ("  FAIL (got " + $response.StatusCode + ", expected 200)") -ForegroundColor Red; Hammer-Record FAIL; return $false }
        $parsed = $response.Content | ConvertFrom-Json
        if (-not $parsed.data) { Write-Host "  FAIL (missing data field)" -ForegroundColor Red; Hammer-Record FAIL; return $false }
        if ($ExpectPagination -and -not $parsed.pagination) { Write-Host "  FAIL (missing pagination field)" -ForegroundColor Red; Hammer-Record FAIL; return $false }
        Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS; return $true
    } catch { Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL; return $false }
}

function Create-DraftArtifact {
    param([string]$EntityId,[hashtable]$RequestHeaders,[string]$DescriptionPrefix)
    $nowIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $body = @{
        kind = "byda_s_audit"; entityId = $EntityId
        content = @{
            schemaVersion = "byda.s0.v1"; entityId = $EntityId
            scores = @{ citability = 50; extractability = 50; factualDensity = 50 }
            notes = "api-hammer"; createdAt = $nowIso
        }
    }
    try {
        Write-Host ("Testing: " + $DescriptionPrefix) -NoNewline
        $json = $body | ConvertTo-Json -Depth 10 -Compress
        $resp = Invoke-WebRequest -Uri "$Base/api/draft-artifacts" -Method POST -Headers $RequestHeaders -Body $json -ContentType "application/json" -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($resp.StatusCode -eq 201) {
            Write-Host "  PASS" -ForegroundColor Green; Hammer-Record PASS
            try { $parsed = $resp.Content | ConvertFrom-Json; return @{ ok = $true; id = $parsed.data.id; body = $body } } catch { return @{ ok = $false; id = $null; body = $body } }
        } else {
            Write-Host ("  FAIL (got " + $resp.StatusCode + ", expected 201)") -ForegroundColor Red; Hammer-Record FAIL
            return @{ ok = $false; id = $null; body = $body }
        }
    } catch {
        Write-Host ("  FAIL (exception: " + $_.Exception.Message + ")") -ForegroundColor Red; Hammer-Record FAIL
        return @{ ok = $false; id = $null; body = $body }
    }
}
