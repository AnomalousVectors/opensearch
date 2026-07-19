#!/bin/bash
set -e
CONF_SRC="${OPENSEARCH_PATH_CONF:-/usr/share/opensearch/config}"
CERT_DIR="$CONF_SRC/certs"

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

cd /usr/share/opensearch
exec ./opensearch-docker-entrypoint.sh "$@"
