# OpenSearch Dashboards with config substitution from .env (envsubst).
# Based on the OpenSearch Project image — not an official OpenSearch Project image.
ARG OPENSEARCH_VERSION=3.7.0
ARG AV_IMAGE_REVISION=2
ARG IMAGE_TAG=${OPENSEARCH_VERSION}-av.${AV_IMAGE_REVISION}

FROM opensearchproject/opensearch-dashboards:${OPENSEARCH_VERSION}

ARG OPENSEARCH_VERSION
ARG AV_IMAGE_REVISION
ARG IMAGE_TAG

LABEL org.opencontainers.image.title="Anomalous Vectors OpenSearch Dashboards" \
      org.opencontainers.image.description="Anomalous Vectors OpenSearch Dashboards image based on the OpenSearch Project image. Intended for local and development use with Anomalous Vectors tooling. This is not an official OpenSearch Project image." \
      org.opencontainers.image.source="https://github.com/AnomalousVectors/opensearch" \
      org.opencontainers.image.url="https://hub.docker.com/r/anomalousvectors/opensearch-dashboards" \
      org.opencontainers.image.vendor="Anomalous Vectors" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${IMAGE_TAG}" \
      org.opencontainers.image.base.name="opensearchproject/opensearch-dashboards:${OPENSEARCH_VERSION}" \
      com.anomalousvectors.opensearch.version="${OPENSEARCH_VERSION}" \
      com.anomalousvectors.image.revision="${AV_IMAGE_REVISION}"

# envsubst for substituting .env values into opensearch_dashboards.yml at container start
USER root
RUN (command -v dnf >/dev/null && dnf install -y gettext && dnf clean all) || (command -v yum >/dev/null && yum install -y gettext && yum clean all) || (command -v apt-get >/dev/null && apt-get update -y && apt-get install -y --no-install-recommends gettext-base && rm -rf /var/lib/apt/lists/*) || true
USER opensearch-dashboards

# Config template (repo is source of truth; baked into the image at build)
COPY --chown=opensearch-dashboards:opensearch-dashboards config/opensearch_dashboards.yml /templates/opensearch_dashboards.yml

COPY --chown=opensearch-dashboards:opensearch-dashboards --chmod=755 entrypoint-wrapper.sh /usr/share/opensearch-dashboards/entrypoint-wrapper.sh
RUN sed -i 's/\r$//' /usr/share/opensearch-dashboards/entrypoint-wrapper.sh \
  && sed -i 's/\r$//' /templates/opensearch_dashboards.yml

ENTRYPOINT ["/usr/share/opensearch-dashboards/entrypoint-wrapper.sh"]
CMD ["opensearch-dashboards"]
