#!/bin/bash
# Build local images using Hub tags from compose.yml (sole tag authority).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-env.sh
source "${SCRIPT_DIR}/lib-env.sh"
load_repo_env
load_image_tag_from_compose
echo "Building anomalousvectors/opensearch:${IMAGE_TAG} and anomalousvectors/opensearch-dashboards:${IMAGE_TAG}"
compose_stack_build build "$@"
