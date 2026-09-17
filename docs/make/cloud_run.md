# Cloud Run

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Deploy containerized services to Google Cloud Run, and operate them.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `cloudrun_deploy` | Deploy the container to Cloud Run (private unless `CLOUDRUN_PUBLIC=true`) | ⚠️ |
| `cloudrun_list` | List all active Cloud Run services in the project | — |
| `cloudrun_url` | Retrieve the live URL of the deployed API | — |
| `cloudrun_logs` | Read the last 50 log lines of the service | — |
| `cloudrun_delete` | Delete the service and take the API offline | ⚠️ destructive |

`cloudrun_deploy` serves `$(GAR_IMAGE):prod` from
[`$(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/$(ARTIFACTSREPO)`](docker.md).
The service is **private by default**: callers need an identity token and the
`run.invoker` role. Set `CLOUDRUN_PUBLIC=true` in the project's `.env` to
expose a public URL instead (demos, public APIs).

## Calling a private service

```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" "$SERVICE_URL"
```

Grant the invoker role to another identity:

```bash
gcloud run services add-iam-policy-binding <SERVICE> \
    --member=user:<EMAIL> --role=roles/run.invoker --region=<REGION>
```

Redeploying an existing public service without `CLOUDRUN_PUBLIC` does **not**
remove its public access — the deploy leaves the IAM policy untouched. Remove
it explicitly:

```bash
gcloud run services remove-iam-policy-binding <SERVICE> \
    --member=allUsers --role=roles/run.invoker --region=<REGION>
```

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GAR_IMAGE` | all targets | `my-api` |
| `GCP_REGION` | all targets | `europe-west1` |
| `GCP_PROJECT` | all targets | `my-project-id` |
| `ARTIFACTSREPO` | `cloudrun_deploy` | `my-artifacts` |
| `GAR_MEMORY` | `cloudrun_deploy` | `2Gi` |
| `CLOUDRUN_PUBLIC` | `cloudrun_deploy` | empty (private) or `true` |

After deployment, store the URL returned by `cloudrun_url` as `SERVICE_URL`
in your project's `.env` — it is the variable Cloud API tests read. Tests
hitting a private service must send the `Authorization` header shown above.
