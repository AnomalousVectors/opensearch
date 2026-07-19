#Requires -Version 5.1
<#
.SYNOPSIS
  Build local images using Hub tags from compose.yml (sole tag authority).
#>
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$BuildArgs
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "lib-env.ps1")
Import-RepoEnv
Get-ImageTagFromCompose
Write-Host "Building anomalousvectors/opensearch:$($env:IMAGE_TAG) and anomalousvectors/opensearch-dashboards:$($env:IMAGE_TAG)"
if ($null -eq $BuildArgs) {
  Invoke-ComposeBuild build
} else {
  Invoke-ComposeBuild build @BuildArgs
}
