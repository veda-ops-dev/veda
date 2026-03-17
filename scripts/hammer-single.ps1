# hammer-single.ps1 — Run a single hammer module with JSON output
# Used by MCP tools for per-module hammer execution.
#
# Usage: .\hammer-single.ps1 -Module <name> [-Base http://localhost:3000]
#        [-ProjectId <uuid>] [-OtherProjectId <uuid>]
#
# Module name is without the "hammer-" prefix, e.g. "sil16", "core", "seo".
# If ProjectId is omitted, auto-bootstraps a disposable project.

param(
    [Parameter(Mandatory=$true)][string]$Module,
    [string]$Base = "http://localhost:3000",
    [string]$ProjectId,
    [string]$OtherProjectId
)

$ErrorActionPreference = "Continue"
$Base = $Base.TrimEnd('/')

# ── Counters ───────────────────────────────────────────────────────────────────
$script:PassCount = 0
$script:FailCount = 0
$script:SkipCount = 0

# ── Load shared helpers ────────────────────────────────────────────────────────
. "$PSScriptRoot\hammer\hammer-lib.ps1"

# ── Resolve module file ───────────────────────────────────────────────────────
$moduleFile = "$PSScriptRoot\hammer\hammer-$Module.ps1"
if (-not (Test-Path $moduleFile)) {
    $available = Get-ChildItem "$PSScriptRoot\hammer\hammer-*.ps1" |
        Where-Object { $_.Name -ne "hammer-lib.ps1" } |
        ForEach-Object { $_.Name -replace '^hammer-|\.ps1$' } |
        Sort-Object
    @{ error = "Module not found: hammer-$Module.ps1"; available = $available } | ConvertTo-Json -Depth 3 -Compress
    exit 1
}

# ── Parse-check ───────────────────────────────────────────────────────────────
$_tokens = $null; $_parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "$PSScriptRoot\hammer\hammer-lib.ps1", [ref]$_tokens, [ref]$_parseErrors) | Out-Null
if ($_parseErrors -and $_parseErrors.Count -gt 0) {
    @{ error = "Parse error in hammer-lib.ps1"; message = $_parseErrors[0].Message } | ConvertTo-Json -Compress
    exit 1
}
[System.Management.Automation.Language.Parser]::ParseFile(
    $moduleFile, [ref]$_tokens, [ref]$_parseErrors) | Out-Null
if ($_parseErrors -and $_parseErrors.Count -gt 0) {
    @{ error = "Parse error in hammer-$Module.ps1"; message = $_parseErrors[0].Message } | ConvertTo-Json -Compress
    exit 1
}

# ── Bootstrap project if needed ───────────────────────────────────────────────
$Headers = @{}
$OtherHeaders = @{}

if ($ProjectId) {
    $Headers = Get-ProjectHeaders -ProjectIdValue $ProjectId
} else {
    $_slug = "hm-single-$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        $_body = @{ name = "Hammer Single"; slug = $_slug; description = "hammer-single auto" } | ConvertTo-Json
        $_resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $_body -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($_resp.StatusCode -eq 201) {
            $ProjectId = (($_resp.Content | ConvertFrom-Json).data).id
            $Headers = Get-ProjectHeaders -ProjectIdValue $ProjectId
        } else {
            @{ error = "Project bootstrap failed"; status = [int]$_resp.StatusCode } | ConvertTo-Json -Compress
            exit 1
        }
    } catch {
        @{ error = "Project bootstrap exception"; message = $_.Exception.Message } | ConvertTo-Json -Compress
        exit 1
    }
}

if ($OtherProjectId) {
    $OtherHeaders = Get-ProjectHeaders -ProjectIdValue $OtherProjectId
} else {
    $_otherSlug = "hm-other-$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        $_body = @{ name = "Hammer Other"; slug = $_otherSlug; description = "cross-project target" } | ConvertTo-Json
        $_resp = Invoke-WebRequest -Uri "$Base/api/projects" -Method POST `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $_body -SkipHttpErrorCheck -TimeoutSec 30 -UseBasicParsing
        if ($_resp.StatusCode -eq 201) {
            $OtherProjectId = (($_resp.Content | ConvertFrom-Json).data).id
            $OtherHeaders = Get-ProjectHeaders -ProjectIdValue $OtherProjectId
        }
    } catch {
        # Non-fatal: cross-project tests will SKIP
    }
}

# ── Seed entityId (some modules need it) ──────────────────────────────────────
$entityId = $null
try {
    $_seed = Invoke-RestMethod -Uri "$Base/api/entities?limit=1" -Method GET -Headers $Headers -TimeoutSec 30
    if ($_seed -and $_seed.data -and $_seed.data.Count -gt 0) { $entityId = $_seed.data[0].id }
} catch {}

# ── Run module ────────────────────────────────────────────────────────────────
try {
    . $moduleFile
} catch {
    Write-Host ("MODULE EXCEPTION: " + $_.Exception.Message) -ForegroundColor Red
    $script:FailCount++
}

# ── JSON result (last thing written to stdout) ────────────────────────────────
@{
    module         = $Module
    projectId      = $ProjectId
    otherProjectId = $OtherProjectId
    pass           = $script:PassCount
    fail           = $script:FailCount
    skip           = $script:SkipCount
    total          = $script:PassCount + $script:FailCount + $script:SkipCount
    success        = ($script:FailCount -eq 0)
} | ConvertTo-Json -Compress

if ($script:FailCount -eq 0) { exit 0 } else { exit 1 }
