# ================================
# Anomalous Vectors Docker Targets
# ================================

# Config
COMPOSEFILE_OPENSEARCH=./opensearch/docker-compose.yml
COMPOSEFILE_OPENSEARCH_DASHBOARDS=-./opensearch-dashboards/docker-compose.yml
COMPOSE_ALL=docker-compose -f $(COMPOSEFILE_OPENSEARCH) $(COMPOSEFILE_OPENSEARCH_DASHBOARDS)

# -------------------------------
# Primary Targets
# -------------------------------

up:
	./scripts/start.sh

down:
	./scripts/stop.sh

destroy:
	./scripts/destroy.sh

restart:
	./scripts/restart.sh

logs:
	./scripts/logs.sh

ps:
	./scripts/status.sh

health:
	./scripts/health.sh

env:
	cat ../.env
