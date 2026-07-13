#!/bin/bash
# Shared .env loader for repo-root scripts.
# Hub image tags are hardcoded in compose.yml (git pull updates them).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_repo_env() {
  local env_file="${1:-${REPO_ROOT}/.env}"
  if [ ! -f "$env_file" ]; then
    echo "Missing ${env_file}. Copy .env.example to .env and edit DATA_VOLUME_ROOT." >&2
    exit 1
  fi
  if [ -z "$BASH_VERSION" ]; then
    echo "These scripts expect Bash on Linux/macOS. On Windows use scripts/start.ps1." >&2
    exit 1
  fi
  while IFS='=' read -r key value || [ -n "$key" ]; do
    key="$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    value="$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    export "$key=$value"
  done < "$env_file"
}

# Host-side health checks use loopback; opensearch.url is a Docker network alias.
host_opensearch_url() {
  echo "https://127.0.0.1:${OPENSEARCH_PORT:-9200}"
}

compose_stack() {
  docker compose --project-directory "${REPO_ROOT}" -f "${REPO_ROOT}/compose.yml" "$@"
}

compose_stack_build() {
  docker compose --project-directory "${REPO_ROOT}" \
    -f "${REPO_ROOT}/compose.yml" \
    -f "${REPO_ROOT}/compose.build.yml" \
    "$@"
}
