# GreyEye Deployment Readiness Checklist

## Fixed blockers

- [x] `pytest` collection no longer collides across service test packages.
- [x] Default `pytest` runs no longer stall on NATS integration tests.
  NATS JetStream integration coverage now requires `RUN_INTEGRATION_TESTS=1`.
- [x] Shared `/metrics` endpoint resolves correctly and serves Prometheus payloads.
- [x] Alert schema naming is aligned across notification service code, SQL migration, and seed data.
- [x] Config service now exposes `GET /v1/cameras/{camera_id}` for the mobile camera settings flow.
- [x] Flutter client auth no longer uses mock login/register state.
- [x] Flutter list providers now parse the backend's paginated `data` envelope.
- [x] Deployment docs and scrape configs now use the actual reporting and notification ports (`8005`, `8007`).
- [x] Reporting API export status uses request-scoped settings, eliminating test-order auth failures.

## Ready-to-verify items

- [x] `libs/observability/tests`
- [x] `libs/shared_contracts/tests`
- [x] `services/aggregator/tests`
- [x] `services/api_gateway/tests`
- [x] `services/auth_service/tests`
- [x] `services/config_service/tests`
- [x] `services/inference_worker/tests`
- [x] `services/ingest_service/tests`
- [x] `services/notification_service/tests`
- [x] `services/reporting_api/tests`
- [x] `uv run pytest -q`
  Verified on March 11, 2026: `771 passed, 15 skipped` in `108.56s`.

## Remaining deployment risks

- [ ] Real model artifacts must be present for inference.
  The detector and classifier still fall back to stub backends when ONNX models are unavailable.
- [ ] Notification delivery channels need production credentials.
  Email is still effectively a stub without SMTP configuration, and push requires an FCM key.
- [ ] Report export job state is process-local.
  Export metadata currently lives in memory, so jobs are not durable across restarts or multiple replicas.
- [ ] Flutter app still needs runtime environment validation.
  The client contract is corrected, but I did not run `flutter analyze` or an end-to-end mobile smoke test here.
- [ ] Helm and Terraform CLIs are not installed in this workspace.
  `make helm-lint`, `make helm-template-prod`, and `make tf-validate` are currently blocked by missing local binaries.

## Pre-deploy gate

- [x] Run `uv run pytest -q`
- [ ] Run `make helm-lint`
- [ ] Run `make helm-template-prod`
- [ ] Run `make tf-validate`
- [ ] Verify ONNX detector/classifier artifacts load in the target image
- [ ] Confirm Supabase schema is created from the updated migrations before seeding
- [ ] Smoke-test gateway auth, config, ingest, analytics, and alerts through `http://<gateway>/healthz`
