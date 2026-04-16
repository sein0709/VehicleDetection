# GreyEye — Development Commands
# Run `make help` to see all available targets.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# ── Environment ──────────────────────────────────────────────────────────────

.PHONY: install
install: ## Install all workspace dependencies with uv
	uv sync --all-packages

.PHONY: install-dev
install-dev: install ## Install deps + pre-commit hooks
	uv run pre-commit install

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
	uv run mypy ml/

.PHONY: check
check: lint typecheck ## Run all static checks (lint + typecheck)

# ── Testing ──────────────────────────────────────────────────────────────────

.PHONY: test
test: ## Run all unit tests
	uv run pytest -m "not integration and not slow" --tb=short -q

.PHONY: test-all
test-all: ## Run all tests
	uv run pytest --tb=short

.PHONY: test-cov
test-cov: ## Run tests with coverage report
	uv run pytest --cov=ml --cov-report=term-missing --cov-report=html

# ── ML Export ────────────────────────────────────────────────────────────────

DETECTOR_CKPT  ?= runs/detector/base/weights/best.pt
CLASSIFIER_CKPT ?= runs/classifier/base/best.pt
MODEL_VERSION  ?= v1.0.0
FLUTTER_ASSETS := apps/mobile_flutter/assets/models

.PHONY: export-tflite
export-tflite: ## Export detector and classifier to TFLite for on-device inference
	uv run python -m ml.export.export_detector \
		--model $(DETECTOR_CKPT) \
		--output-dir models/detector/$(MODEL_VERSION) \
		--format tflite
	uv run python -m ml.export.export_classifier \
		--model $(CLASSIFIER_CKPT) \
		--output-dir models/classifier/$(MODEL_VERSION) \
		--format tflite
	@mkdir -p $(FLUTTER_ASSETS)
	cp models/detector/$(MODEL_VERSION)/model.tflite $(FLUTTER_ASSETS)/detector.tflite
	cp models/classifier/$(MODEL_VERSION)/model.tflite $(FLUTTER_ASSETS)/classifier.tflite
	@echo "✓ TFLite models exported and copied to $(FLUTTER_ASSETS)/"

.PHONY: export-all
export-all: ## Export detector and classifier to all formats (ONNX, TorchScript, TFLite)
	uv run python -m ml.export.export_detector \
		--model $(DETECTOR_CKPT) \
		--output-dir models/detector/$(MODEL_VERSION) \
		--format all --version $(MODEL_VERSION)
	uv run python -m ml.export.export_classifier \
		--model $(CLASSIFIER_CKPT) \
		--output-dir models/classifier/$(MODEL_VERSION) \
		--format all --version $(MODEL_VERSION)
	@mkdir -p $(FLUTTER_ASSETS)
	cp models/detector/$(MODEL_VERSION)/model.tflite $(FLUTTER_ASSETS)/detector.tflite
	cp models/classifier/$(MODEL_VERSION)/model.tflite $(FLUTTER_ASSETS)/classifier.tflite
	@echo "✓ All model formats exported. TFLite models copied to $(FLUTTER_ASSETS)/"

# ── Flutter ──────────────────────────────────────────────────────────────────

.PHONY: flutter-run
flutter-run: ## Run the Flutter app in debug mode
	cd apps/mobile_flutter && flutter run

.PHONY: flutter-build
flutter-build: ## Build the Flutter app (release APK)
	cd apps/mobile_flutter && flutter build apk --release

.PHONY: flutter-test
flutter-test: ## Run Flutter unit tests
	cd apps/mobile_flutter && flutter test

.PHONY: flutter-build-macos
flutter-build-macos: ## Build the Flutter app as a standalone macOS .app (release)
	cd apps/mobile_flutter && flutter build macos --release
	@echo "✓ Built: apps/mobile_flutter/build/macos/Build/Products/Release/greyeye_mobile.app"

.PHONY: flutter-install-macos
flutter-install-macos: flutter-build-macos ## Build and install the macOS app to /Applications
	rm -rf /Applications/greyeye_mobile.app
	cp -R apps/mobile_flutter/build/macos/Build/Products/Release/greyeye_mobile.app /Applications/
	@echo "✓ Installed to /Applications/greyeye_mobile.app"

.PHONY: flutter-codegen
flutter-codegen: ## Run Drift and other code generation
	cd apps/mobile_flutter && dart run build_runner build --delete-conflicting-outputs

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
