# Cloud Run

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Deploy containerized services to Google Cloud Run, and operate them.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `cloudrun_deploy` | Deploy the container to Cloud Run | ⚠️ |
| `cloudrun_list` | List all active Cloud Run services in the project | — |
| `cloudrun_url` | Retrieve the live URL of the deployed API | — |
| `cloudrun_logs` | Read the last 50 log lines of the service | — |
| `cloudrun_delete` | Delete the service and take the API offline | ⚠️ destructive |

`cloudrun_deploy` serves `$(GAR_IMAGE):prod` from
[`$(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(ARTIFACTSREPO)`](docker.md)
with unauthenticated access.

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GAR_IMAGE` | all targets | `my-api` |
| `GCP_REGION` | all targets | `europe-west1` |
| `GCP_PROJECT` | all targets | `my-project-id` |
| `ARTIFACTSREPO` | `cloudrun_deploy` | `my-artifacts` |
| `GAR_MEMORY` | `cloudrun_deploy` | `2Gi` |

After deployment, store the URL returned by `cloudrun_url` as `SERVICE_URL`
in your project's `.env` — it is the variable Cloud API tests read.
