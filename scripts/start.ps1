#Requires -Version 5.1
<#
.SYNOPSIS
  Start Anomalous Vectors OpenSearch + Dashboards (Hub images).
  Interactive admin password prompt; does not store the password in .env.
#>
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib-env.ps1")

function Write-Prompt([string]$Message) {
  Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrPrompt([string]$Message) {
  Write-Host $Message -ForegroundColor Red
}

function Get-HostOpenSearchUrl {
  $port = if ($env:OPENSEARCH_PORT) { $env:OPENSEARCH_PORT } else { "9200" }
  return "https://127.0.0.1:${port}"
}

function Read-PasswordMasked([string]$Prompt) {
  Write-Prompt $Prompt
  $secure = Read-Host -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null
  }
}

function Read-NonEmptyPassword([string]$Prompt) {
  while ($true) {
    $pw = Read-PasswordMasked $Prompt
    if (-not [string]::IsNullOrEmpty($pw)) { return $pw }
    Write-ErrPrompt "Password cannot be empty. Try again."
  }
}

function Wait-OpenSearchReachable {
  $url = "$(Get-HostOpenSearchUrl)/_cluster/health"
  $maxWait = 90
  $elapsed = 0
  while ($elapsed -lt $maxWait) {
    $code = Get-HttpStatusCode -Uri $url -TimeoutSec 4
    if ($code -eq 200 -or $code -eq 401) { return $true }
    Start-Sleep -Seconds 1
    $elapsed++
  }
  return $false
}

function Test-AdminPassword([string]$Password) {
  $url = "$(Get-HostOpenSearchUrl)/_cluster/health"
  $code = Get-HttpStatusCode -Uri $url -UserName "admin" -Password $Password -TimeoutSec 10
  return ($code -eq 200)
}

function Clear-RuntimePasswords {
  Remove-Item Env:OPENSEARCH_INITIAL_ADMIN_PASSWORD -ErrorAction SilentlyContinue
  Remove-Item Env:OPENSEARCH_DASHBOARDS_PASSWORD -ErrorAction SilentlyContinue
}

# Restrict certs dir and *-key.pem to the current user and Administrators (not all Users).
function Protect-CertPrivateKeys([string]$CertsDir) {
  if (-not (Test-Path -LiteralPath $CertsDir)) { return }

  $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
  $admins = New-Object System.Security.Principal.SecurityIdentifier(
    [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)

  $inherit = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor `
    [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
  $propagate = [System.Security.AccessControl.PropagationFlags]::None

  $dirAcl = New-Object System.Security.AccessControl.DirectorySecurity
  $dirAcl.SetAccessRuleProtection($true, $false)
  $dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    $currentUser, 'FullControl', $inherit, $propagate, 'Allow')))
  $dirAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    $admins, 'FullControl', $inherit, $propagate, 'Allow')))
  Set-Acl -LiteralPath $CertsDir -AclObject $dirAcl

  Get-ChildItem -LiteralPath $CertsDir -Filter '*-key.pem' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $fileAcl = New-Object System.Security.AccessControl.FileSecurity
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
      $currentUser, 'FullControl', 'Allow')))
    $fileAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
      $admins, 'FullControl', 'Allow')))
    Set-Acl -LiteralPath $_.FullName -AclObject $fileAcl
  }
}

try {
  Import-RepoEnv

  $certsDir = Join-Path $env:DATA_VOLUME_ROOT "certs"
  $dataDir = Join-Path $env:DATA_VOLUME_ROOT "data"
  New-Item -ItemType Directory -Force -Path $certsDir | Out-Null
  New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
  Protect-CertPrivateKeys $certsDir

  $firstStart = -not (Test-Path (Join-Path $dataDir "nodes"))

  Write-Prompt "Pulling Hub images from compose.yml, then starting the stack."
  Invoke-Compose pull

  if ($firstStart) {
    while ($true) {
      $pw1 = Read-NonEmptyPassword "First run detected. Enter initial OpenSearch admin password (save this for future runs):"
      $pw2 = Read-NonEmptyPassword "Repeat initial OpenSearch admin password:"
      if ($pw1 -eq $pw2) {
        $password = $pw1
        break
      }
      Write-ErrPrompt "Passwords do not match. Try again."
    }
    $env:OPENSEARCH_INITIAL_ADMIN_PASSWORD = $password
    $env:OPENSEARCH_DASHBOARDS_PASSWORD = $password
    Write-Prompt "OpenSearch stores only the hash. Save this password for Dashboards and API login as admin."
    Write-Prompt "Change password docs: https://docs.opensearch.org/latest/api-reference/security/authentication/change-password/"

    Invoke-Compose up -d --wait --wait-timeout 180 opensearch
    Write-Prompt "Waiting for OpenSearch to become reachable..."
    if (-not (Wait-OpenSearchReachable)) {
      throw "OpenSearch did not become reachable in time."
    }
    Protect-CertPrivateKeys $certsDir
    if (-not (Test-AdminPassword $password)) {
      throw "Initial password validation failed after bootstrap. Aborting start."
    }
    Invoke-Compose up -d --wait --wait-timeout 180 opensearch-dashboards
  } else {
    Invoke-Compose up -d --wait --wait-timeout 180 opensearch
    Write-Prompt "Waiting for OpenSearch to become reachable..."
    if (-not (Wait-OpenSearchReachable)) {
      throw "OpenSearch did not become reachable in time."
    }
    Protect-CertPrivateKeys $certsDir

    $maxAttempts = if ($env:MAX_PASSWORD_ATTEMPTS) { [int]$env:MAX_PASSWORD_ATTEMPTS } else { 3 }
    $ok = $false
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      $password = Read-NonEmptyPassword "Enter OpenSearch admin password for this run:"
      if (Test-AdminPassword $password) {
        $env:OPENSEARCH_DASHBOARDS_PASSWORD = $password
        $ok = $true
        break
      }
      if ($attempt -lt $maxAttempts) {
        Write-ErrPrompt "Invalid password. Please try again. ($attempt/$maxAttempts)"
      } else {
        throw "Invalid password. Reached max attempts ($maxAttempts). Aborting start."
      }
    }
    if (-not $ok) { throw "Password validation failed." }
    Invoke-Compose up -d --wait --wait-timeout 180 opensearch-dashboards
  }

  Protect-CertPrivateKeys $certsDir
  Write-Prompt "Stack is up. OpenSearch and Dashboards should report healthy shortly."
} finally {
  Clear-RuntimePasswords
}
