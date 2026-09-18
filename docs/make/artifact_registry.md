# Artifact Registry

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

The Google half of the Docker workflow: where the production image is stored,
and what it takes to be allowed to push there.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `docker_auth` | Configure Docker to authenticate with GCP | — |
| `artifact_registry_create` | Create the Docker repository in Artifact Registry | ⚠️ |
| `artifact_registry_role` | Grant yourself Artifact Registry Writer (IAM) | ⚠️ |

These three call `gcloud`, so their module is loaded only when that CLI is
installed — the rest of the Docker workflow
([`docker.md`](docker.md)) needs nothing else. See
[optional tooling](install.md) for the menu rule.

## Variables

| Variable | Example |
|---|---|
| `GCP_PROJECT` | `my-project-id` |
| `GCP_REGION` | `europe-west1` |
| `ARTIFACTSREPO` | `my-artifacts` |

## Typical flow

`docker_auth` once per machine, `artifact_registry_create` +
`artifact_registry_role` once per project, then `docker_build_prod` →
`docker_push_prod` → [`cloudrun_deploy`](cloud_run.md). The two build/push
targets live in [`docker.md`](docker.md): they drive docker, not gcloud.
