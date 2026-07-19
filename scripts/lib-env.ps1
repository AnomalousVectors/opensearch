#Requires -Version 5.1
# Shared helpers for PowerShell stack scripts (repo root).

$script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:InsecureSslConfigured = $false

function Import-RepoEnv {
  param([string]$EnvFile = (Join-Path $script:RepoRoot ".env"))
  if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Copy .env.example to .env and edit DATA_VOLUME_ROOT."
  }
  Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) { return }
    $parts = $line.Split("=", 2)
    if ($parts.Count -lt 2) { return }
    Set-Item -Path "Env:$($parts[0].Trim())" -Value $parts[1].Trim()
  }
}

function Enable-InsecureSslForWindowsPowerShell {
  if ($script:InsecureSslConfigured) { return }
  if ($PSVersionTable.PSVersion.Major -ge 6) { return }
  if (-not ("TrustAllCertsPolicy" -as [type])) {
    Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
  public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
    return true;
  }
}
"@
  }
  [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
  $script:InsecureSslConfigured = $true
}

function Get-HttpStatusCode {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [string]$UserName,
    [string]$Password,
    [int]$TimeoutSec = 4
  )
  Enable-InsecureSslForWindowsPowerShell
  $headers = @{}
  if ($PSBoundParameters.ContainsKey("UserName")) {
    $token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${UserName}:${Password}"))
    $headers["Authorization"] = "Basic $token"
  }
  $params = @{
    Uri                = $Uri
    UseBasicParsing    = $true
    TimeoutSec         = $TimeoutSec
    MaximumRedirection = 0
    ErrorAction        = "Stop"
  }
  if ($headers.Count -gt 0) { $params.Headers = $headers }
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $params.SkipCertificateCheck = $true
  }
  try {
    $response = Invoke-WebRequest @params
    return [int]$response.StatusCode
  } catch {
    $response = $_.Exception.Response
    if ($null -ne $response -and $null -ne $response.StatusCode) {
      return [int]$response.StatusCode
    }
    return 0
  }
}

function Get-ImageTagFromCompose {
  $composeFile = Join-Path $script:RepoRoot "compose.yml"
  $text = Get-Content -LiteralPath $composeFile -Raw
  $osMatch = [regex]::Match($text, 'anomalousvectors/opensearch:([^\s]+)')
  $dbMatch = [regex]::Match($text, 'anomalousvectors/opensearch-dashboards:([^\s]+)')
  if (-not $osMatch.Success) {
    throw "Could not parse anomalousvectors/opensearch:<tag> from compose.yml"
  }
  if (-not $dbMatch.Success) {
    throw "Could not parse anomalousvectors/opensearch-dashboards:<tag> from compose.yml"
  }
  $osTag = $osMatch.Groups[1].Value.Trim()
  $dbTag = $dbMatch.Groups[1].Value.Trim()
  if ($osTag -ne $dbTag) {
    throw "compose.yml image tags differ (opensearch=$osTag, opensearch-dashboards=$dbTag); keep them equal."
  }
  if ($osTag -notmatch '^(?<ver>.+)-av\.(?<rev>.+)$') {
    throw "Tag must look like <opensearch_version>-av.<revision> (got: $osTag)"
  }
  $env:IMAGE_TAG = $osTag
  $env:OPENSEARCH_VERSION = $Matches['ver']
  $env:AV_IMAGE_REVISION = $Matches['rev']
}

function Invoke-Compose {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ComposeArgs)
  & docker compose --project-directory $script:RepoRoot -f (Join-Path $script:RepoRoot "compose.yml") @ComposeArgs
  if ($LASTEXITCODE -ne 0) { throw "docker compose failed with exit code $LASTEXITCODE" }
}

function Invoke-ComposeBuild {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ComposeArgs)
  Get-ImageTagFromCompose
  & docker compose --project-directory $script:RepoRoot `
    -f (Join-Path $script:RepoRoot "compose.yml") `
    -f (Join-Path $script:RepoRoot "compose.build.yml") `
    @ComposeArgs
  if ($LASTEXITCODE -ne 0) { throw "docker compose build failed with exit code $LASTEXITCODE" }
}
