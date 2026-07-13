#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")
. (Join-Path $ScriptDir "lib-env.ps1")
Import-RepoEnv
Invoke-Compose stop
