#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-env.sh
source "${SCRIPT_DIR}/lib-env.sh"
load_repo_env

# Ensure persistent dirs exist
CERTS_DIR="${DATA_VOLUME_ROOT}/certs"
DATA_DIR="${DATA_VOLUME_ROOT}/data"
mkdir -p "$CERTS_DIR"
mkdir -p "$DATA_DIR"

# First start = OpenSearch data dir has not been initialized yet.
FIRST_START=false
if [ ! -d "${DATA_DIR}/nodes" ]; then
  FIRST_START=true
fi

YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

print_prompt() {
  echo -e "${YELLOW}$1${RESET}"
}

print_error() {
  echo -e "${RED}$1${RESET}"
}

read_password_with_asterisks() {
  local pw=""
  local char=""
  while true; do
    IFS= read -r -s -n 1 char || true
    case "$char" in
      $'\n'|$'\r'|'')
        echo ""
        PASSWORD_INPUT="$pw"
        return 0
        ;;
      $'\177'|$'\b')
        if [ -n "$pw" ]; then
          pw="${pw%?}"
          echo -ne "\b \b"
        fi
        ;;
      *)
        pw+="$char"
        echo -n "*"
        ;;
    esac
  done
}

wait_opensearch_reachable() {
  local max_wait=90
  local interval=1
  local elapsed=0
  local code=""
  local url
  url="$(host_opensearch_url)/_cluster/health"
  while [ $elapsed -lt $max_wait ]; do
    code="$(curl -sk --connect-timeout 2 --max-time 4 -o /dev/null -w '%{http_code}' "$url" || true)"
    if [ "$code" = "200" ] || [ "$code" = "401" ]; then
      return 0
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  return 1
}

prompt_password() {
  local prompt_msg="$1"
  while true; do
    print_prompt "$prompt_msg"
    read_password_with_asterisks
    if [ -n "$PASSWORD_INPUT" ]; then
      return 0
    fi
    print_error "Password cannot be empty. Try again."
  done
}

prompt_initial_password_with_confirmation() {
  local first_prompt="First run detected. Enter initial OpenSearch admin password (save this for future runs):"
  local repeat_prompt="Repeat initial OpenSearch admin password:"
  while true; do
    prompt_password "$first_prompt"
    local pw1="$PASSWORD_INPUT"
    prompt_password "$repeat_prompt"
    local pw2="$PASSWORD_INPUT"
    if [ "$pw1" = "$pw2" ]; then
      PASSWORD_INPUT="$pw1"
      return 0
    fi
    print_error "Passwords do not match. Try again."
  done
}

validate_admin_password() {
  local pw="$1"
  local code
  code=$(curl -sk -u "admin:${pw}" -o /dev/null -w '%{http_code}' "$(host_opensearch_url)/_cluster/health")
  [ "$code" = "200" ]
}

cleanup_runtime_passwords() {
  unset OPENSEARCH_INITIAL_ADMIN_PASSWORD
  unset OPENSEARCH_DASHBOARDS_PASSWORD
}

# Host-side private-key modes (Linux/macOS bind mounts). Windows uses start.ps1 ACLs instead.
protect_cert_private_keys() {
  local dir="$CERTS_DIR"
  [ -d "$dir" ] || return 0
  chmod 700 "$dir" 2>/dev/null || true
  local key
  for key in "$dir"/*-key.pem; do
    if [ -f "$key" ]; then
      chmod 600 "$key" 2>/dev/null || true
    fi
  done
}

trap cleanup_runtime_passwords EXIT

print_prompt "Pulling Hub images from compose.yml, then starting the stack."
UP_PULL_POLICY="always"
if ! compose_stack pull; then
  print_prompt "Hub pull failed; using local images if present (build with compose.build.yml or wait for publish)."
  UP_PULL_POLICY="never"
fi

if [ "$FIRST_START" = true ]; then
  prompt_initial_password_with_confirmation
  export OPENSEARCH_INITIAL_ADMIN_PASSWORD="$PASSWORD_INPUT"
  export OPENSEARCH_DASHBOARDS_PASSWORD="$PASSWORD_INPUT"
  print_prompt "OpenSearch stores only the hash. Save this password for Dashboards and API login as admin."
  print_prompt "Change password docs: https://docs.opensearch.org/latest/api-reference/security/authentication/change-password/"

  compose_stack up -d --pull "$UP_PULL_POLICY" --wait --wait-timeout 180 opensearch

  print_prompt "Waiting for OpenSearch to become reachable..."
  if ! wait_opensearch_reachable; then
    print_error "OpenSearch did not become reachable in time."
    exit 1
  fi
  protect_cert_private_keys

  if ! validate_admin_password "$OPENSEARCH_INITIAL_ADMIN_PASSWORD"; then
    print_error "Initial password validation failed after bootstrap. Aborting start."
    exit 1
  fi

  compose_stack up -d --pull "$UP_PULL_POLICY" --wait --wait-timeout 180 opensearch-dashboards
else
  compose_stack up -d --pull "$UP_PULL_POLICY" --wait --wait-timeout 180 opensearch

  print_prompt "Waiting for OpenSearch to become reachable..."
  if ! wait_opensearch_reachable; then
    print_error "OpenSearch did not become reachable in time."
    exit 1
  fi
  protect_cert_private_keys

  MAX_PASSWORD_ATTEMPTS="${MAX_PASSWORD_ATTEMPTS:-3}"
  ATTEMPT=1
  while [ "$ATTEMPT" -le "$MAX_PASSWORD_ATTEMPTS" ]; do
    prompt_password "Enter OpenSearch admin password for this run:"
    if validate_admin_password "$PASSWORD_INPUT"; then
      export OPENSEARCH_DASHBOARDS_PASSWORD="$PASSWORD_INPUT"
      break
    fi
    if [ "$ATTEMPT" -lt "$MAX_PASSWORD_ATTEMPTS" ]; then
      print_error "Invalid password. Please try again. (${ATTEMPT}/${MAX_PASSWORD_ATTEMPTS})"
    else
      print_error "Invalid password. Reached max attempts (${MAX_PASSWORD_ATTEMPTS}). Aborting start."
      exit 1
    fi
    ATTEMPT=$((ATTEMPT + 1))
  done

  compose_stack up -d --pull "$UP_PULL_POLICY" --wait --wait-timeout 180 opensearch-dashboards
fi

protect_cert_private_keys
print_prompt "Stack is up. OpenSearch and Dashboards are healthy."
print_prompt "Next: https://github.com/AnomalousVectors/opensearch/wiki/OpenSearch"
