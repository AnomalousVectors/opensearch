#Requires -Version 5.1
$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "lib-env.ps1")
Import-RepoEnv

$port = if ($env:OPENSEARCH_PORT) { $env:OPENSEARCH_PORT } else { "9200" }
$dbPort = if ($env:OPENSEARCH_DASHBOARDS_PORT) { $env:OPENSEARCH_DASHBOARDS_PORT } else { "5601" }

$osCode = Get-HttpStatusCode -Uri "https://127.0.0.1:${port}/_cluster/health" -TimeoutSec 10
if ($osCode -ne 200 -and $osCode -ne 401) {
  Write-Error "OpenSearch health check failed (HTTP $osCode)."
  exit 1
}
Write-Host "OpenSearch reachable (HTTP $osCode)."

$dbCode = Get-HttpStatusCode -Uri "https://127.0.0.1:${dbPort}" -TimeoutSec 10
if ($dbCode -ne 200 -and $dbCode -ne 302 -and $dbCode -ne 401) {
  Write-Error "Dashboards check failed (HTTP $dbCode)."
  Write-Host "Tip: if Dashboards is still starting, retry in a few seconds."
  exit 1
}
Write-Host "Dashboards reachable (HTTP $dbCode)."