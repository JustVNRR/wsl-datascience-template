# GCP Infrastructure & IAM

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

Projects, Cloud Storage buckets, and service accounts — the ground floor of
the GCP modules. All targets read the cascading `.env.global` / `.env`
configuration.

## Targets

| Target | Action | Confirmation |
|---|---|---|
| `gcp_project_list` | List all GCP projects available to your account | — |
| `gcp_enable_compute` | Enable the Compute Engine API for the project | ⚠️ |
| `gcs_list_buckets` | List all Cloud Storage buckets in the project | — |
| `gcs_create_bucket` | Create a new Cloud Storage bucket | ⚠️ |
| `gcs_delete_bucket` | Delete a bucket **and all its contents** | ⚠️ destructive |
| `iam_setup_service_account` | Create the service account and assign IAM roles | ⚠️ |

`iam_setup_service_account` grants the BigQuery Data Editor and Cloud Storage
Object Admin roles. It also runs automatically as a prerequisite of
`vm_create` (see [Compute Engine](gcloud_compute.md)).

## Variables

| Variable | Required by | Example |
|---|---|---|
| `GCP_PROJECT` | most targets | `my-project-id` |
| `GCP_REGION` | `gcs_create_bucket` | `europe-west1` |
| `BUCKET_NAME` | `gcs_create_bucket`, `gcs_delete_bucket` | `my-data-bucket` |
| `SA_NAME` | `iam_setup_service_account` | `my-project-vm-sa` |

`SA_EMAIL` is derived automatically:
`$(SA_NAME)@$(GCP_PROJECT).iam.gserviceaccount.com`.
