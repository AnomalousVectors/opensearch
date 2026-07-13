# Third-Party Notices

This repository and the Docker images it builds incorporate or depend on
third-party software. This file summarizes the main upstream components.

## OpenSearch

- Project: [OpenSearch](https://opensearch.org/)
- Upstream images: `opensearchproject/opensearch`, `opensearchproject/opensearch-dashboards`
- License: Apache License 2.0
- Notice: OpenSearch is a registered trademark of the OpenSearch Project / Amazon Web Services, Inc. as applicable.

Anomalous Vectors images are **based on** these upstream images and are **not**
official OpenSearch Project images.

## transport-reactor-netty4

- Source: OpenSearch Project plugin distribution
- Installed in the Anomalous Vectors OpenSearch image for HTTP/2 over HTTPS
- License: Apache License 2.0 (OpenSearch Project)

## Anomalous Vectors repository code

Scripts, Compose files, config templates, and documentation in this repository
are licensed under the MIT License. See [LICENSE](LICENSE).

Upstream license and notice files that ship inside the base container images
remain authoritative for those components.
