# Docker & Artifact Registry

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Local builds and runs, plus production images pushed to Google Artifact
Registry.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `docker_build_local` | Build the image locally for testing (`:dev` tag) | — |
| `docker_run_local` | Run the local container on port 8080 | — |
| `docker_auth` | Configure Docker to authenticate with GCP | — |
| `artifact_registry_create` | Create the Docker repository in Artifact Registry | ⚠️ |
| `artifact_registry_role` | Grant yourself Artifact Registry Writer (IAM) | ⚠️ |
| `docker_build_prod` | Build the production image (`linux/amd64`) | — |
| `docker_push_prod` | Push the production image to Artifact Registry | ⚠️ |

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GAR_IMAGE` | all build/run/push targets | `my-api` |
| `DOCKER_BASE_IMAGE` | build targets | `python:3.10.6-slim` |
| `PACKAGE_NAME` | build targets | `my-package` |
| `GCP_PROJECT` | registry targets | `my-project-id` |
| `GCP_REGION` | registry targets | `europe-west1` |
| `ARTIFACTSREPO` | registry targets | `my-artifacts` |

## Typical flow

`docker_auth` once per machine, `artifact_registry_create` +
`artifact_registry_role` once per project, then `docker_build_prod` →
`docker_push_prod` → [`cloudrun_deploy`](cloud_run.md).
