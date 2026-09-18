# Docker

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Local builds and runs, plus the production image — which is tagged for Google
Artifact Registry, where it is pushed from
[`artifact_registry.md`](artifact_registry.md).

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `docker_build_local` | Build the image locally for testing (`:dev` tag) | — |
| `docker_run_local` | Run the local container on port 8080 | — |
| `docker_build_prod` | Build the production image (`linux/amd64`) | — |
| `docker_push_prod` | Push the production image to Artifact Registry | ⚠️ |

None of these call `gcloud`: the three targets that do (`docker_auth`,
`artifact_registry_create`, `artifact_registry_role`) live in
[`artifact_registry.md`](artifact_registry.md), and appear in the menu only
when that CLI is installed.

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GAR_IMAGE` | all build/run/push targets | `my-api` |
| `DOCKER_BASE_IMAGE` | build targets | `python:3.10.6-slim` |
| `PACKAGE_NAME` | build targets | `my-package` |
| `GCP_PROJECT` | production targets | `my-project-id` |
| `GCP_REGION` | production targets | `europe-west1` |
| `ARTIFACTSREPO` | production targets | `my-artifacts` |

## Typical flow

`docker_build_local` and `docker_run_local` while developing; once the image is
worth shipping, `docker_build_prod` → `docker_push_prod` →
[`cloudrun_deploy`](cloud_run.md). Both production targets need the registry
to exist first — that is [artifact_registry.md](artifact_registry.md).
