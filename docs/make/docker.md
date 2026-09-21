# Docker

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

The container on your machine: building an image and running it. The production
image is a Google concern — its tag names an Artifact Registry path — and lives
in [`artifact_registry.md`](artifact_registry.md).

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `docker_build_local` | Build the image locally for testing (`:dev` tag) | — |
| `docker_run_local` | Run the local container on port 8080 | — |

Neither of these runs `gcloud`. The production side — `artifact_registry_build`
and `artifact_registry_push`, plus the three targets that do call it — lives in
[`artifact_registry.md`](artifact_registry.md), and appears in the menu only
when that CLI is installed.

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GAR_IMAGE` | all Docker targets | `my-api` |
| `DOCKER_BASE_IMAGE` | both build targets | `python:3.10.6-slim` |
| `PACKAGE_NAME` | both build targets | `my-package` |

The three the production image needs on top of these — `GCP_PROJECT`,
`GCP_REGION`, `ARTIFACTSREPO` — are on
[`artifact_registry.md`](artifact_registry.md).

## Typical flow

`docker_build_local` and `docker_run_local` while developing; once the image is
worth shipping, [`artifact_registry_build`](artifact_registry.md) →
[`artifact_registry_push`](artifact_registry.md) →
[`cloudrun_deploy`](cloud_run.md).
