# Docker

[← Back to the README](../../../README.md#mlops-makefile-gmake)

The container on your machine: building an image and running it. The production
image is a Google concern — its tag names an Artifact Registry path — and lives
in [`artifact_registry.md`](../../gcp/docs/artifact_registry.md).

## Targets

| Target | Action | Confirmation |
| :--- | :--- | :--- |
| `docker_build_local` | Build the image locally for testing (`:dev` tag) | — |
| `docker_run_local` | Run the local container on port 8080 | — |

Both build **one project**: they run from its root, and the variables below
identify it.

Neither of these runs `gcloud`. The production side — `artifact_registry_build`
and `artifact_registry_push`, plus the three targets that do call it — lives in
[`artifact_registry.md`](../../gcp/docs/artifact_registry.md), and appears in
the menu only when the `gcp` pack is installed.

## Variables

| Variable | Required by | Example |
| :--- | :--- | :--- |
| `PACKAGE_NAME` | `docker_build_local` | `my-package` |
| `DOCKER_BASE_IMAGE` | `docker_build_local` | `python:3.10.6-slim` |
| `DOCKER_LOCAL_IMAGE` | both | `my-api` |
| `GAR_IMAGE` | the GCP build target | `my-api` |

The three the production image needs on top of these — `GCP_PROJECT`,
`GCP_REGION`, `ARTIFACTSREPO` — are on
[`artifact_registry.md`](../../gcp/docs/artifact_registry.md).

## Typical flow

`docker_build_local` and `docker_run_local` while developing; once the image is
worth shipping, [`artifact_registry_build`](../../gcp/docs/artifact_registry.md)
→ [`artifact_registry_push`](../../gcp/docs/artifact_registry.md) →
[`cloudrun_deploy`](../../gcp/docs/cloud_run.md).
