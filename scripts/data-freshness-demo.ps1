[CmdletBinding()]
param(
    [ValidateSet('preflight', 'crawler', 'checker', 'all')]
    [string]$Mode = 'preflight',

    [string]$SupabaseUrl = '',

    [ValidateRange(1, 50)]
    [int]$Limit = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$crawlerRoot = Join-Path $repoRoot 'backend\crawldata'
$pythonPath = Join-Path $crawlerRoot '.demo-venv\Scripts\python.exe'
$frontendRoot = Join-Path $repoRoot 'frontend'

function Resolve-SupabaseUrl {
    $candidate = $SupabaseUrl
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = [Environment]::GetEnvironmentVariable('SUPABASE_URL', 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $null
    }
    return $candidate.TrimEnd('/')
}

function Write-Section([string]$Title) {
    Write-Output "`n=== $Title ==="
}

function Invoke-OptionsProbe([string]$BaseUrl, [string]$FunctionName) {
    $uri = "$BaseUrl/functions/v1/$FunctionName"
    $response = Invoke-WebRequest -Uri $uri -Method Options -UseBasicParsing
    if ($response.StatusCode -ne 200) {
        throw "$FunctionName OPTIONS returned HTTP $($response.StatusCode)."
    }
    Write-Output "$FunctionName OPTIONS $($response.StatusCode)"
}

function Test-CrawlerEnvironment {
    if (-not (Test-Path -LiteralPath $pythonPath)) {
        throw "Missing demo Python environment: $pythonPath. Run the setup commands in docs/data-freshness-demo-runbook.md."
    }

    Push-Location $crawlerRoot
    try {
        & $pythonPath -c "import requests, bs4, lxml, dotenv, supabase; print('crawler dependencies: ok')"
        if ($LASTEXITCODE -ne 0) {
            throw 'Crawler dependency import failed.'
        }

        $help = & $pythonPath crawl_seed_data_fixed_v3.py --help 2>&1
        if ($LASTEXITCODE -ne 0 -or -not ($help -match '--mode') -or -not ($help -match '--upsert')) {
            throw 'Crawler CLI help verification failed.'
        }
        Write-Output 'crawler CLI: ok'
    }
    finally {
        Pop-Location
    }
}

function Invoke-CrawlerDryRun {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outputRoot = Join-Path ([IO.Path]::GetTempPath()) "hello-vietnam-crawler-$stamp"
    New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null

    Push-Location $crawlerRoot
    try {
        & $pythonPath crawl_seed_data_fixed_v3.py `
            --mode local_products `
            --limit $Limit `
            --output-dir $outputRoot
        if ($LASTEXITCODE -ne 0) {
            throw "Crawler dry run failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    $jsonPath = Join-Path $outputRoot 'local_products.json'
    $rowCount = 0
    if (Test-Path -LiteralPath $jsonPath) {
        $raw = Get-Content -Raw -Encoding UTF8 $jsonPath
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $parsed = $raw | ConvertFrom-Json
            if ($parsed -is [array]) {
                $rowCount = $parsed.Count
            }
            elseif ($null -ne $parsed) {
                $rowCount = 1
            }
        }
    }

    Write-Output "crawler output: $outputRoot"
    Write-Output "local_products rows: $rowCount"
    if ($rowCount -eq 0) {
        Write-Warning 'The crawler completed but returned 0 rows. Check source rate limits and use cached activity/culture output as the demo fallback.'
    }
}

function Invoke-FreshnessChecker {
    $baseUrl = Resolve-SupabaseUrl
    if ([string]::IsNullOrWhiteSpace($baseUrl)) {
        throw 'Checker mode requires -SupabaseUrl or the process environment variable SUPABASE_URL.'
    }

    $secret = [Environment]::GetEnvironmentVariable('DATA_FRESHNESS_CHECK_SECRET', 'Process')
    if ([string]::IsNullOrWhiteSpace($secret)) {
        throw 'Checker mode requires DATA_FRESHNESS_CHECK_SECRET in the current process environment. The value is never printed.'
    }

    $headers = @{
        'Content-Type' = 'application/json'
        'x-data-freshness-secret' = $secret
    }
    $body = @{ triggerType = 'admin' } | ConvertTo-Json -Compress
    $result = Invoke-RestMethod `
        -Uri "$baseUrl/functions/v1/data-freshness-check" `
        -Method Post `
        -Headers $headers `
        -Body $body

    foreach ($field in @('runId', 'selectedCount', 'checkedCount', 'failedCount', 'status')) {
        if ($null -eq $result.$field) {
            throw "Checker response is missing '$field'."
        }
    }
    $result | Select-Object runId, selectedCount, checkedCount, failedCount, status
}

Write-Section 'Data freshness demo preflight'
Write-Output "workspace: $repoRoot"
Write-Output "mode: $Mode"

if ($Mode -in @('preflight', 'crawler', 'all')) {
    Test-CrawlerEnvironment
}

$resolvedUrl = Resolve-SupabaseUrl
if (-not [string]::IsNullOrWhiteSpace($resolvedUrl)) {
    Write-Section 'Edge Function reachability'
    Invoke-OptionsProbe $resolvedUrl 'data-freshness'
    Invoke-OptionsProbe $resolvedUrl 'data-freshness-check'
}
elseif ($Mode -in @('preflight', 'all')) {
    Write-Warning 'SUPABASE_URL was not set; skipped remote OPTIONS probes. This is not a secret and can be passed with -SupabaseUrl.'
}

if ($Mode -in @('crawler', 'all')) {
    Write-Section 'Manual crawler dry run'
    Invoke-CrawlerDryRun
}

if ($Mode -in @('checker', 'all')) {
    Write-Section 'Freshness checker trigger'
    try {
        Invoke-FreshnessChecker
    }
    catch {
        if ($_.Exception.Message -match 'requires DATA_FRESHNESS_CHECK_SECRET') {
            Write-Warning "Checker not triggered: $($_.Exception.Message)"
            exit 2
        }
        throw
    }
}

Write-Section 'Next owner-only checks'
Write-Output 'Verify migration, DATA_FRESHNESS_CHECK_SECRET/Vault parity, cron.job, and admin role in local/staging before presenting.'
