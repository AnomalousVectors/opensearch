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
# Uses icacls: Set-Acl with a replaced DACL requires SeSecurityPrivilege (often missing in a normal shell).
function Protect-CertPrivateKeys([string]$CertsDir) {
  if (-not (Test-Path -LiteralPath $CertsDir)) { return }

  $icacls = Join-Path $env:SystemRoot 'System32\icacls.exe'
  if (-not (Test-Path -LiteralPath $icacls)) {
    Write-ErrPrompt "icacls not found; skipping private-key ACL hardening on the host."
    return
  }

  $userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $adminsSid = 'S-1-5-32-544'
  $broadAccounts = @(
    'Everyone',
    'Users',
    'BUILTIN\Users',
    'Authenticated Users',
    'NT AUTHORITY\Authenticated Users'
  )

  function Invoke-Icacls([string[]]$IcaclsArgs) {
    $output = & $icacls @IcaclsArgs 2>&1
    return @{ ExitCode = $LASTEXITCODE; Output = $output }
  }

  try {
    $null = Invoke-Icacls @($CertsDir, '/inheritance:r')
    foreach ($acct in $broadAccounts) {
      $null = Invoke-Icacls @($CertsDir, '/remove:g', $acct)
    }
    $dirGrant = Invoke-Icacls @(
      $CertsDir,
      '/grant:r',
      "*${userSid}:(OI)(CI)F",
      "*${adminsSid}:(OI)(CI)F"
    )
    if ($dirGrant.ExitCode -ne 0) {
      Write-ErrPrompt "Could not tighten ACLs on certs directory (icacls exit $($dirGrant.ExitCode))."
    }

    Get-ChildItem -LiteralPath $CertsDir -Filter '*-key.pem' -File -ErrorAction SilentlyContinue | ForEach-Object {
      $path = $_.FullName
      $null = Invoke-Icacls @($path, '/inheritance:r')
      foreach ($acct in $broadAccounts) {
        $null = Invoke-Icacls @($path, '/remove:g', $acct)
      }
      $keyGrant = Invoke-Icacls @($path, '/grant:r', "*${userSid}:F", "*${adminsSid}:F")
      if ($keyGrant.ExitCode -ne 0) {
        Write-ErrPrompt "Could not tighten ACLs on $($_.Name) (icacls exit $($keyGrant.ExitCode))."
      }
    }
  } catch {
    Write-ErrPrompt "Could not tighten cert private-key ACLs on the host: $($_.Exception.Message)"
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
  $pullArgs = @("pull")
  $upPullPolicy = "always"
  try {
    Invoke-Compose @pullArgs
  } catch {
    Write-Prompt "Hub pull failed; using local images if present (build with compose.build.yml or wait for publish)."
    $upPullPolicy = "never"
  }

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

    Invoke-Compose up -d --pull $upPullPolicy --wait --wait-timeout 180 opensearch
    Write-Prompt "Waiting for OpenSearch to become reachable..."
    if (-not (Wait-OpenSearchReachable)) {
      throw "OpenSearch did not become reachable in time."
    }
    Protect-CertPrivateKeys $certsDir
    if (-not (Test-AdminPassword $password)) {
      throw "Initial password validation failed after bootstrap. Aborting start."
    }
    Invoke-Compose up -d --pull $upPullPolicy --wait --wait-timeout 180 opensearch-dashboards
  } else {
    Invoke-Compose up -d --pull $upPullPolicy --wait --wait-timeout 180 opensearch
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
    Invoke-Compose up -d --pull $upPullPolicy --wait --wait-timeout 180 opensearch-dashboards
  }

  Protect-CertPrivateKeys $certsDir
  Write-Prompt "Stack is up. OpenSearch and Dashboards are healthy."
  Write-Prompt "Next: https://github.com/AnomalousVectors/opensearch/wiki/OpenSearch"
} finally {
  Clear-RuntimePasswords
}
