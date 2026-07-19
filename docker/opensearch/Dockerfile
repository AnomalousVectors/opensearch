# OpenSearch with transport-reactor-netty4 (HTTP/2 + HTTPS) and cert generation.
# Based on the OpenSearch Project image — not an official OpenSearch Project image.
ARG OPENSEARCH_VERSION
ARG AV_IMAGE_REVISION
ARG IMAGE_TAG=${OPENSEARCH_VERSION}-av.${AV_IMAGE_REVISION}

FROM opensearchproject/opensearch:${OPENSEARCH_VERSION}

ARG OPENSEARCH_VERSION
ARG AV_IMAGE_REVISION
ARG IMAGE_TAG

LABEL org.opencontainers.image.title="Anomalous Vectors OpenSearch" \
      org.opencontainers.image.description="Anomalous Vectors OpenSearch image based on the OpenSearch Project image. Intended for local and development use with Anomalous Vectors tooling. This is not an official OpenSearch Project image." \
      org.opencontainers.image.source="https://github.com/AnomalousVectors/opensearch" \
      org.opencontainers.image.url="https://hub.docker.com/r/anomalousvectors/opensearch" \
      org.opencontainers.image.vendor="Anomalous Vectors" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${IMAGE_TAG}" \
      org.opencontainers.image.base.name="opensearchproject/opensearch:${OPENSEARCH_VERSION}" \
      com.anomalousvectors.opensearch.version="${OPENSEARCH_VERSION}" \
      com.anomalousvectors.image.revision="${AV_IMAGE_REVISION}"

# envsubst + openssl for config rendering and cert generation
USER root
RUN (command -v dnf >/dev/null && dnf install -y gettext openssl && dnf clean all) || (command -v yum >/dev/null && yum install -y gettext openssl && yum clean all) || (command -v apt-get >/dev/null && apt-get update -y && apt-get install -y --no-install-recommends gettext-base openssl && rm -rf /var/lib/apt/lists/*) || true
USER opensearch

# Install reactor-netty4 plugin for HTTP/2 over HTTPS
RUN /usr/share/opensearch/bin/opensearch-plugin install --batch transport-reactor-netty4

# Config templates (repo is source of truth; baked into the image at build)
COPY --chown=opensearch:opensearch config/opensearch.yml /usr/share/opensearch/config/opensearch.yml
COPY --chown=opensearch:opensearch config/opensearch-performance-analyzer/ /usr/share/opensearch/config/opensearch-performance-analyzer/
# Security overlays: clientcert auth for Dashboards leaf CN → kibana_server
# Live path (defaults) + av-security/ (re-applied after demo password install in entrypoint)
COPY --chown=opensearch:opensearch config/opensearch-security/config.yml /usr/share/opensearch/config/opensearch-security/config.yml
COPY --chown=opensearch:opensearch config/opensearch-security/roles_mapping.yml /usr/share/opensearch/config/opensearch-security/roles_mapping.yml
COPY --chown=opensearch:opensearch config/opensearch-security/config.yml /usr/share/opensearch/config/av-security/config.yml
COPY --chown=opensearch:opensearch config/opensearch-security/roles_mapping.yml /usr/share/opensearch/config/av-security/roles_mapping.yml

# Scripts: cert generation and entrypoint wrapper
COPY --chown=opensearch:opensearch --chmod=755 scripts/generate-certs.sh /usr/share/opensearch/scripts/generate-certs.sh
COPY --chown=opensearch:opensearch --chmod=755 entrypoint-wrapper.sh /usr/share/opensearch/entrypoint-wrapper.sh
RUN sed -i 's/\r$//' /usr/share/opensearch/scripts/generate-certs.sh /usr/share/opensearch/entrypoint-wrapper.sh \
  && sed -i 's/\r$//' /usr/share/opensearch/config/opensearch.yml \
    /usr/share/opensearch/config/opensearch-security/config.yml \
    /usr/share/opensearch/config/opensearch-security/roles_mapping.yml

ENTRYPOINT ["/usr/share/opensearch/entrypoint-wrapper.sh"]
CMD ["opensearch"]
