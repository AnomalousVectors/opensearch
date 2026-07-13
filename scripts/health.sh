#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-env.sh
source "${SCRIPT_DIR}/lib-env.sh"
load_repo_env

OS_CODE="$(curl -sk -o /dev/null -w '%{http_code}' "$(host_opensearch_url)/_cluster/health" || true)"
if [ "$OS_CODE" != "200" ] && [ "$OS_CODE" != "401" ]; then
  echo "OpenSearch health check failed (HTTP ${OS_CODE:-000})."
  exit 1
fi
echo "OpenSearch reachable (HTTP ${OS_CODE})."

DB_CODE="$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1:${OPENSEARCH_DASHBOARDS_PORT:-5601}" || true)"
if [ "$DB_CODE" != "200" ] && [ "$DB_CODE" != "302" ] && [ "$DB_CODE" != "401" ]; then
  echo "Dashboards check failed (HTTP ${DB_CODE:-000})."
  echo "Tip: if Dashboards is still starting, retry in a few seconds."
  exit 1
fi
echo "Dashboards reachable (HTTP ${DB_CODE})."
