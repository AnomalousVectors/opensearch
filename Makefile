# ================================
# OpenSearch Root Makefile
# ================================

.DEFAULT_GOAL := help

# -------------------------------
# Docker Targets
# -------------------------------

docker-up:
	@$(MAKE) --no-print-directory -C docker up

docker-down:
	@$(MAKE) --no-print-directory -C docker down

docker-destroy:
	@$(MAKE) --no-print-directory -C docker destroy

docker-restart:
	@$(MAKE) --no-print-directory -C docker restart

docker-logs:
	@$(MAKE) --no-print-directory -C docker logs

docker-ps:
	@$(MAKE) --no-print-directory -C docker ps

docker-health:
	@$(MAKE) --no-print-directory -C docker health

docker-env:
	@$(MAKE) --no-print-directory -C docker env

# -------------------------------
# Kubernetes Targets (placeholder)
# -------------------------------

k8s-up:
	@$(MAKE) --no-print-directory -C k8s up

k8s-down:
	@$(MAKE) --no-print-directory -C k8s down

# -------------------------------
# Help
# -------------------------------

help:
	@echo ""
	@echo "Available targets:"
	@echo ""
	@echo "  docker-up           Start Docker containers"
	@echo "  docker-down         Stop containers (keep containers/network)"
	@echo "  docker-destroy      Stop and remove containers/network"
	@echo "  docker-restart      Restart Docker containers"
	@echo "  docker-logs         Tail Docker logs"
	@echo "  docker-ps           Show Docker container status"
	@echo "  docker-health       Check OpenSearch cluster health"
	@echo "  docker-env          Show resolved .env"
	@echo ""
	@echo "  k8s-up              (placeholder) Start K8s resources"
	@echo "  k8s-down            (placeholder) Tear down K8s resources"
	@echo ""
	@echo "Usage:"
	@echo "  make docker-up"
	@echo "  make k8s-up"
	@echo ""
