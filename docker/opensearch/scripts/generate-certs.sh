#!/bin/sh
# Generate self-signed CA and server certs for OpenSearch and OpenSearch Dashboards.
# Usage: generate-certs.sh [output_dir]
# Output in output_dir:
#   root-ca.pem, root-ca-key.pem
#   node.pem, node-key.pem (OpenSearch; CN=opensearch)
#   dashboards.pem, dashboards-key.pem (Dashboards; CN=opensearch-dashboards)
# If CA already exists, only missing certs are created (e.g. dashboards only).

set -e
OUT_DIR="${1:-/usr/share/opensearch/config/certs}"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# CA (skip if already present)
if [ ! -f root-ca.pem ] || [ ! -f root-ca-key.pem ]; then
  openssl genrsa -out root-ca-key.pem 2048
  openssl req -new -x509 -sha256 -key root-ca-key.pem -out root-ca.pem -days 3650 \
    -subj "/C=US/ST=State/L=City/O=AnomalousVectors/OU=Dev/CN=OpenSearch-Root-CA"
fi

# OpenSearch node cert: CN=opensearch; SANs: localhost, opensearch, opensearch.url
if [ ! -f node.pem ] || [ ! -f node-key.pem ]; then
  openssl genrsa -out node-key.pem 2048
  openssl req -new -key node-key.pem -out node.csr \
    -subj "/C=US/ST=State/L=City/O=AnomalousVectors/OU=Dev/CN=opensearch"
  cat > node.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName=DNS:localhost,DNS:opensearch,DNS:opensearch.url,IP:127.0.0.1
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
EOF
  openssl x509 -req -in node.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -out node.pem -days 3650 -sha256 -extfile node.ext
  rm -f node.csr node.ext
fi

# Dashboards cert: CN=opensearch-dashboards; SANs: localhost, opensearch-dashboards.url
if [ ! -f dashboards.pem ] || [ ! -f dashboards-key.pem ]; then
  openssl genrsa -out dashboards-key.pem 2048
  openssl req -new -key dashboards-key.pem -out dashboards.csr \
    -subj "/C=US/ST=State/L=City/O=AnomalousVectors/OU=Dev/CN=opensearch-dashboards"
  cat > dashboards.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName=DNS:localhost,DNS:opensearch-dashboards.url,IP:127.0.0.1
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
EOF
  openssl x509 -req -in dashboards.csr -CA root-ca.pem -CAkey root-ca-key.pem \
    -out dashboards.pem -days 3650 -sha256 -extfile dashboards.ext
  rm -f dashboards.csr dashboards.ext
fi

echo "Generated certs in $OUT_DIR"
