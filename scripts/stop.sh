#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-env.sh
source "${SCRIPT_DIR}/lib-env.sh"
load_repo_env
compose_stack stop
