# Artifact Registry

[← Back to the README](../../README.md#mlops-makefile-gmake)

The Google half of the Docker workflow: the repository that stores the
production image, the image itself, and what it takes to be allowed to push
there.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `artifact_registry_create` | Create the Docker repository in Artifact Registry | ⚠️ |
| `artifact_registry_role` | Grant yourself Artifact Registry Writer (IAM) | ⚠️ |
| `artifact_registry_auth` | Configure Docker to authenticate with GCP | — |
| `artifact_registry_build` | Build the production image (`linux/amd64`) | — |
| `artifact_registry_push` | Push the production image to Artifact Registry | ⚠️ |

Nothing here runs without `gcloud`: three targets call it, and the two that call
`docker` only tag and push to a path `gcloud auth configure-docker` unlocks. The
module therefore appears in the menu only when that CLI is installed — the local
container ([`docker.md`](docker.md)) needs nothing else. See
[optional tooling](install.md) for the menu rule.

## Variables

| Variable | Example |
|---|---|
| `GCP_PROJECT` | `my-project-id` |
| `GCP_REGION` | `europe-west1` |
| `ARTIFACTSREPO` | `my-artifacts` |

`artifact_registry_build` builds the same recipe as `docker_build_local`, so it
reads the same three variables — see [`docker.md`](docker.md).

## Typical flow

`artifact_registry_auth` once per region (it registers that region's registry
address in Docker's configuration), `artifact_registry_create` +
`artifact_registry_role` once per project, then `artifact_registry_build` →
`artifact_registry_push` → [`cloudrun_deploy`](cloud_run.md).
