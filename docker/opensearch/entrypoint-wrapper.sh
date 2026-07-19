#!/bin/bash
set -e
CONF_SRC="${OPENSEARCH_PATH_CONF:-/usr/share/opensearch/config}"
CERT_DIR="$CONF_SRC/certs"
AV_SECURITY_DIR="/usr/share/opensearch/config/av-security"
OPENSEARCH_HOME="${OPENSEARCH_HOME:-/usr/share/opensearch}"

# Generate certs if missing (OpenSearch and/or Dashboards leaf certs)
if [ ! -f "$CERT_DIR/opensearch.pem" ] || [ ! -f "$CERT_DIR/opensearch-key.pem" ] || \
   [ ! -f "$CERT_DIR/dashboards.pem" ] || [ ! -f "$CERT_DIR/dashboards-key.pem" ]; then
  echo "Certs missing in $CERT_DIR; generating..."
  /usr/share/opensearch/scripts/generate-certs.sh "$CERT_DIR"
fi

# Tighten private-key modes on every start (Linux bind mounts; no-op if FS ignores mode bits)
if [ -d "$CERT_DIR" ]; then
  chmod 700 "$CERT_DIR" 2>/dev/null || true
  for key in "$CERT_DIR"/*-key.pem; do
    if [ -f "$key" ]; then
      chmod 600 "$key" 2>/dev/null || true
    fi
  done
fi

# Substitute env vars in opensearch.yml (OPENSEARCH_BIND_ADDRESS, OPENSEARCH_PORT, etc.) so .env is single source of truth
RESOLVED_CONF="/tmp/opensearch-config"
mkdir -p "$RESOLVED_CONF"

# Keep the full config tree so security bootstrap files are available
cp -a "$CONF_SRC/." "$RESOLVED_CONF/"

# Render opensearch.yml from env vars into the resolved config
envsubst < "$CONF_SRC/opensearch.yml" > "$RESOLVED_CONF/opensearch.yml"

# Ensure mounted certs are used from source config path
[ -d "$CONF_SRC/certs" ] && ln -sfn "$CONF_SRC/certs" "$RESOLVED_CONF/certs"
export OPENSEARCH_PATH_CONF="$RESOLVED_CONF"

# OPENSEARCH_INITIAL_ADMIN_PASSWORD is applied by install_demo_configuration.sh only.
# Run it once when the start script supplies that env, then restore AV security overlays
# (demo install overwrites config.yml / roles_mapping.yml).
if [ -n "${OPENSEARCH_INITIAL_ADMIN_PASSWORD:-}" ] && [ "${DISABLE_SECURITY_PLUGIN:-}" != "true" ]; then
  DEMO_INSTALLER="$OPENSEARCH_HOME/plugins/opensearch-security/tools/install_demo_configuration.sh"
  if [ -x "$DEMO_INSTALLER" ]; then
    echo "Applying initial admin password via Security demo install (overlays re-applied after)."
    bash "$DEMO_INSTALLER" -y -i -s
  fi
  # Demo may rewrite opensearch.yml; restore ours and certs link.
  envsubst < "$CONF_SRC/opensearch.yml" > "$RESOLVED_CONF/opensearch.yml"
  [ -d "$CONF_SRC/certs" ] && ln -sfn "$CONF_SRC/certs" "$RESOLVED_CONF/certs"
fi

# Always apply AV clientcert + kibana_server overlays for this run's config tree.
if [ -f "$AV_SECURITY_DIR/config.yml" ] && [ -f "$AV_SECURITY_DIR/roles_mapping.yml" ]; then
  mkdir -p "$RESOLVED_CONF/opensearch-security"
  cp "$AV_SECURITY_DIR/config.yml" "$RESOLVED_CONF/opensearch-security/config.yml"
  cp "$AV_SECURITY_DIR/roles_mapping.yml" "$RESOLVED_CONF/opensearch-security/roles_mapping.yml"
fi

# Skip a second demo run inside opensearch-docker-entrypoint.sh.
export DISABLE_INSTALL_DEMO_CONFIG=true

cd "$OPENSEARCH_HOME"
exec ./opensearch-docker-entrypoint.sh "$@"
