# GreyEye — Development Commands
# Run `make help` to see all available targets.

.DEFAULT_GOAL := help
SHELL := /bin/bash

COMPOSE := docker compose -f infra/docker-compose.yml -p greyeye

# ── Environment ──────────────────────────────────────────────────────────────

.PHONY: install
install: ## Install all workspace dependencies with uv
	uv sync --all-packages

.PHONY: install-dev
install-dev: install ## Install deps + pre-commit hooks
	uv run pre-commit install

# ── Local Infrastructure ─────────────────────────────────────────────────────

.PHONY: dev-up
dev-up: ## Start local dev stack (Postgres, Redis, NATS, MinIO)
	$(COMPOSE) up -d
	@echo "Waiting for services to become healthy..."
	$(COMPOSE) run --rm minio-init || true
	@echo "✓ Dev stack is ready."
	@echo "  Postgres : localhost:5432  (greyeye / greyeye_dev)"
	@echo "  Redis    : localhost:6379"
	@echo "  NATS     : localhost:4222  (monitor: http://localhost:8222)"
	@echo "  MinIO    : localhost:9000  (console: http://localhost:9001)"

.PHONY: dev-down
dev-down: ## Stop and remove dev stack containers
	$(COMPOSE) down

.PHONY: dev-reset
dev-reset: ## Stop dev stack and destroy all volumes
	$(COMPOSE) down -v

.PHONY: dev-logs
dev-logs: ## Tail logs from all dev stack services
	$(COMPOSE) logs -f

.PHONY: obs-up
obs-up: ## Start observability stack (Prometheus, Alertmanager, Grafana, Loki, Tempo)
	$(COMPOSE) up -d alertmanager prometheus grafana loki tempo
	@echo "✓ Observability stack is ready."
	@echo "  Prometheus    : http://localhost:9090"
	@echo "  Alertmanager  : http://localhost:9093"
	@echo "  Grafana       : http://localhost:3000  (admin / greyeye)"
	@echo "  Loki          : http://localhost:3100"
	@echo "  Tempo         : http://localhost:3200  (OTLP gRPC: localhost:4317)"

.PHONY: obs-down
obs-down: ## Stop observability stack
	$(COMPOSE) stop alertmanager prometheus grafana loki tempo

# ── Quality ──────────────────────────────────────────────────────────────────

.PHONY: lint
lint: ## Run ruff linter and formatter check
	uv run ruff check .
	uv run ruff format --check .

.PHONY: format
format: ## Auto-format code with ruff
	uv run ruff format .
	uv run ruff check --fix .

.PHONY: typecheck
typecheck: ## Run mypy type checking
	uv run mypy libs/ services/

.PHONY: check
check: lint typecheck ## Run all static checks (lint + typecheck)

# ── Testing ──────────────────────────────────────────────────────────────────

.PHONY: test
test: ## Run all unit tests
	uv run pytest -m "not integration and not slow" --tb=short -q

.PHONY: test-all
test-all: ## Run all tests; set RUN_INTEGRATION_TESTS=1 to include NATS integration
	uv run pytest --tb=short

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	uv run pytest --cov=libs --cov=services --cov-report=term-missing --cov-report=html

# ── NATS ─────────────────────────────────────────────────────────────────────

.PHONY: nats-bootstrap
nats-bootstrap: ## Create all NATS JetStream streams and consumers
	uv run python infra/nats_bootstrap.py

.PHONY: nats-verify
nats-verify: ## Verify NATS streams/consumers match expected config
	uv run python infra/nats_bootstrap.py --verify

.PHONY: nats-dry-run
nats-dry-run: ## Print NATS stream/consumer definitions (no connection)
	uv run python infra/nats_bootstrap.py --dry-run

# ── Database ─────────────────────────────────────────────────────────────────

.PHONY: migrate
migrate: ## Apply database migrations from supabase/migrations
	@set -euo pipefail; \
	for file in $$(find supabase/migrations -maxdepth 1 -type f -name '*.sql' | sort); do \
		echo "Applying $$file"; \
		if command -v psql >/dev/null 2>&1; then \
			PGPASSWORD=greyeye_dev psql -v ON_ERROR_STOP=1 -h localhost -U greyeye -d greyeye -f "$$file"; \
		else \
			docker exec -i greyeye-postgres psql -v ON_ERROR_STOP=1 -U greyeye -d greyeye < "$$file"; \
		fi; \
	done

.PHONY: migrate-down
migrate-down: ## Rollback one migration step
	cd libs/db_models && uv run alembic downgrade -1

.PHONY: seed
seed: ## Load development seed data
	@if command -v psql >/dev/null 2>&1; then \
		PGPASSWORD=greyeye_dev psql -v ON_ERROR_STOP=1 -h localhost -U greyeye -d greyeye -f supabase/seed.sql; \
	else \
		docker exec -i greyeye-postgres psql -v ON_ERROR_STOP=1 -U greyeye -d greyeye < supabase/seed.sql; \
	fi

# ── Docker Builds ────────────────────────────────────────────────────────────

REGISTRY ?= ghcr.io/greyeye
TAG      ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "dev")

SERVICES := api_gateway auth_service config_service ingest_service inference_worker aggregator reporting_api notification_service

.PHONY: docker-build
docker-build: ## Build Docker images for all services
	@for svc in $(SERVICES); do \
		echo "Building $$svc..."; \
		docker build -t $(REGISTRY)/$$svc:$(TAG) -f infra/docker/Dockerfile.$$svc .; \
	done

.PHONY: docker-push
docker-push: ## Push all Docker images to registry
	@for svc in $(SERVICES); do \
		docker push $(REGISTRY)/$$svc:$(TAG); \
	done

.PHONY: docker-build-%
docker-build-%: ## Build a single service image (e.g. make docker-build-auth_service)
	docker build -t $(REGISTRY)/$*:$(TAG) -f infra/docker/Dockerfile.$* .

# ── Helm ─────────────────────────────────────────────────────────────────────

.PHONY: helm-lint
helm-lint: ## Lint the Helm umbrella chart
	helm lint infra/helm/greyeye

.PHONY: helm-template
helm-template: ## Render Helm templates locally (dry-run)
	helm template greyeye infra/helm/greyeye

.PHONY: helm-template-prod
helm-template-prod: ## Render Helm templates with production values
	helm template greyeye infra/helm/greyeye -f infra/helm/greyeye/values-production.yaml

# ── Terraform ───────────────────────────────────────────────────────────────

TF_DIR := infra/terraform
TF_ENV ?= production

.PHONY: tf-init
tf-init: ## Initialise Terraform (run once per backend change)
	cd $(TF_DIR) && terraform init

.PHONY: tf-plan
tf-plan: ## Show Terraform execution plan (TF_ENV=production|staging)
	cd $(TF_DIR) && terraform plan -var-file=envs/$(TF_ENV).tfvars -out=tfplan

.PHONY: tf-apply
tf-apply: ## Apply Terraform changes (TF_ENV=production|staging)
	cd $(TF_DIR) && terraform apply tfplan

.PHONY: tf-destroy
tf-destroy: ## Destroy all Terraform-managed resources (DANGEROUS)
	cd $(TF_DIR) && terraform destroy -var-file=envs/$(TF_ENV).tfvars

.PHONY: tf-fmt
tf-fmt: ## Format all Terraform files
	terraform fmt -recursive $(TF_DIR)

.PHONY: tf-validate
tf-validate: ## Validate Terraform configuration
	cd $(TF_DIR) && terraform validate

.PHONY: tf-bootstrap
tf-bootstrap: ## Bootstrap Terraform state backend (run once)
	cd $(TF_DIR)/bootstrap && terraform init && terraform apply

# ── Backup & DR ──────────────────────────────────────────────────────────────

.PHONY: backup-status
backup-status: ## Show backup and DR status report
	bash infra/scripts/backup-status.sh

.PHONY: backup-full
backup-full: ## Trigger an immediate full backup (K8s CronJob)
	kubectl create job --from=cronjob/greyeye-pgbackrest-full \
		greyeye-pgbackrest-full-manual-$$(date +%s) -n greyeye-data

.PHONY: backup-diff
backup-diff: ## Trigger an immediate differential backup (K8s CronJob)
	kubectl create job --from=cronjob/greyeye-pgbackrest-diff \
		greyeye-pgbackrest-diff-manual-$$(date +%s) -n greyeye-data

.PHONY: restore-drill
restore-drill: ## Trigger an immediate restore drill (K8s CronJob)
	kubectl create job --from=cronjob/greyeye-pgbackrest-restore-drill \
		greyeye-pgbackrest-drill-manual-$$(date +%s) -n greyeye-data

.PHONY: dr-failover
dr-failover: ## Execute DR failover to standby region (DANGEROUS)
	@echo "WARNING: This will promote the DR replica and redirect traffic."
	@read -p "Type 'failover' to confirm: " confirm && [ "$$confirm" = "failover" ] || exit 1
	bash infra/scripts/dr-failover.sh

.PHONY: dr-failover-dry-run
dr-failover-dry-run: ## Dry-run DR failover (no changes made)
	bash infra/scripts/dr-failover.sh --dry-run

.PHONY: dr-failback
dr-failback: ## Execute DR failback to primary region (DANGEROUS)
	@echo "WARNING: This will redirect traffic back to the primary region."
	@read -p "Type 'failback' to confirm: " confirm && [ "$$confirm" = "failback" ] || exit 1
	bash infra/scripts/dr-failback.sh

.PHONY: dr-failback-dry-run
dr-failback-dry-run: ## Dry-run DR failback (no changes made)
	bash infra/scripts/dr-failback.sh --dry-run

# ── Load Testing ─────────────────────────────────────────────────────────────

.PHONY: loadtest-mvp
loadtest-mvp: ## Run MVP load test (10 cameras @ 10 FPS, 2 min)
	uv run python -m tests.loadtest.runner --mvp

.PHONY: loadtest-scale
loadtest-scale: ## Run scale load test (100 cameras @ 10 FPS, 5 min)
	uv run python -m tests.loadtest.runner --scale

.PHONY: loadtest-backpressure
loadtest-backpressure: ## Run backpressure verification test
	uv run python -m tests.loadtest.runner --backpressure

.PHONY: loadtest-latency
loadtest-latency: ## Run latency verification test
	uv run python -m tests.loadtest.runner --latency

.PHONY: loadtest-pipeline
loadtest-pipeline: ## Run NATS pipeline throughput test
	uv run python -m tests.loadtest.runner --pipeline

.PHONY: loadtest-all
loadtest-all: ## Run all load test scenarios
	uv run python -m tests.loadtest.runner --all

.PHONY: loadtest-quick
loadtest-quick: ## Run all load tests with reduced durations (CI smoke)
	uv run python -m tests.loadtest.runner --all --quick

.PHONY: loadtest-locust
loadtest-locust: ## Start Locust web UI for interactive load testing
	uv run locust -f tests/loadtest/locustfile.py --host http://localhost:8080

.PHONY: loadtest-locust-headless
loadtest-locust-headless: ## Run Locust headless: 100 users, 10/s ramp, 2 min
	uv run locust -f tests/loadtest/locustfile.py --host http://localhost:8080 \
		--headless -u 100 -r 10 --run-time 2m --csv tests/loadtest/results/locust

# ── Production Launch ────────────────────────────────────────────────────────

.PHONY: smoke-test
smoke-test: ## Run production smoke tests against API_BASE_URL
	bash infra/scripts/production-smoke-test.sh

.PHONY: burn-in
burn-in: ## Start 24h burn-in monitor (DURATION_HOURS=24 INTERVAL_MINUTES=15)
	bash infra/scripts/burn-in-monitor.sh \
		--duration $${DURATION_HOURS:-24} --interval $${INTERVAL_MINUTES:-15}

.PHONY: burn-in-short
burn-in-short: ## Start 1h burn-in monitor (quick validation)
	bash infra/scripts/burn-in-monitor.sh --duration 1 --interval 5

.PHONY: alerts-check
alerts-check: ## Check Prometheus for firing alerts
	@curl -sf "$${PROMETHEUS_URL:-http://localhost:9090}/api/v1/alerts" 2>/dev/null | \
		python3 -c "import sys,json; \
		data=json.load(sys.stdin); \
		alerts=data.get('data',{}).get('alerts',[]); \
		firing=[a for a in alerts if a.get('state')=='firing']; \
		print(f'{len(firing)} firing alerts:'); \
		[print(f'  [{a[\"labels\"].get(\"severity\",\"?\")}] {a[\"labels\"].get(\"alertname\",\"?\")}') for a in firing]" \
		2>/dev/null || echo "Could not reach Prometheus"

.PHONY: alerts-rules
alerts-rules: ## List loaded Prometheus alert rule groups
	@curl -sf "$${PROMETHEUS_URL:-http://localhost:9090}/api/v1/rules" 2>/dev/null | \
		python3 -c "import sys,json; \
		data=json.load(sys.stdin); \
		groups=data.get('data',{}).get('groups',[]); \
		print(f'{len(groups)} rule groups:'); \
		[print(f'  {g[\"name\"]}: {len(g[\"rules\"])} rules') for g in groups]" \
		2>/dev/null || echo "Could not reach Prometheus"

# ── Utilities ────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove build artefacts and caches
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .mypy_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .ruff_cache -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	rm -rf htmlcov .coverage

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
