#!/bin/bash
# Shared .env loader for repo-root scripts.
# Hub image tags are hardcoded only in compose.yml (git pull updates them).

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

# Parse Hub tags from compose.yml (sole authoritative source). Exports:
#   IMAGE_TAG, OPENSEARCH_VERSION, AV_IMAGE_REVISION
load_image_tag_from_compose() {
  local compose_file="${REPO_ROOT}/compose.yml"
  local os_tag db_tag
  os_tag="$(grep -oE 'anomalousvectors/opensearch:[^[:space:]]+' "$compose_file" | head -1 | cut -d: -f2 | tr -d '\r' || true)"
  db_tag="$(grep -oE 'anomalousvectors/opensearch-dashboards:[^[:space:]]+' "$compose_file" | head -1 | cut -d: -f2 | tr -d '\r' || true)"
  if [ -z "$os_tag" ]; then
    echo "Could not parse anomalousvectors/opensearch:<tag> from compose.yml" >&2
    exit 1
  fi
  if [ -z "$db_tag" ]; then
    echo "Could not parse anomalousvectors/opensearch-dashboards:<tag> from compose.yml" >&2
    exit 1
  fi
  if [ "$os_tag" != "$db_tag" ]; then
    echo "compose.yml image tags differ (opensearch=${os_tag}, opensearch-dashboards=${db_tag}); keep them equal." >&2
    exit 1
  fi
  case "$os_tag" in
    *-av.*)
      export IMAGE_TAG="$os_tag"
      export OPENSEARCH_VERSION="${os_tag%-av.*}"
      export AV_IMAGE_REVISION="${os_tag##*-av.}"
      ;;
    *)
      echo "Tag must look like <opensearch_version>-av.<revision> (got: ${os_tag})" >&2
      exit 1
      ;;
  esac
  if [ -z "$OPENSEARCH_VERSION" ] || [ -z "$AV_IMAGE_REVISION" ]; then
    echo "Failed to split OPENSEARCH_VERSION/AV_IMAGE_REVISION from tag: ${os_tag}" >&2
    exit 1
  fi
}

compose_stack() {
  docker compose --project-directory "${REPO_ROOT}" -f "${REPO_ROOT}/compose.yml" "$@"
}

compose_stack_build() {
  load_image_tag_from_compose
  docker compose --project-directory "${REPO_ROOT}" \
    -f "${REPO_ROOT}/compose.yml" \
    -f "${REPO_ROOT}/compose.build.yml" \
    "$@"
}
