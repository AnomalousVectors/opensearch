#Requires -Version 5.1
$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "lib-env.ps1")
Import-RepoEnv
Invoke-Compose down --remove-orphans
