# GCP Onboarding

[← Back to the README](../../README.md#mlops-global-makefile-gmake)

From a fresh distro to your first `gmake` command against Google Cloud — written
for a first serious contact with GCP. Every term is defined the first time it
appears; if you already know a section, skip it.

## The one concept: who is talking to GCP?

Every request to Google Cloud answers a single question: *who is making this
call?* Only two kinds of callers exist:

- **A human** — you, with your Google account.
- **A service account** — a **robot identity** created inside a project, for
  code that must run without a human around.

If you learned GCP at a bootcamp, you were handed a JSON file starting with
`"type": "service_account"`. That file is the **private key of a robot**:
whoever holds it *is* that robot, with all of its rights. Bootcamps use it
because a classroom shares one project — handing out a robot's key is simpler
than managing permissions and billing for every student.

On **your own project**, you are the human owner, and the human path needs no
file at all — two one-time commands (steps 1 and 5 below). The robot path
still exists and stays useful wherever there is no browser (CI, servers); this
template supports both.

| Caller | How | What you run |
|---|---|---|
| You, in the terminal (`gcloud`, `bq` — every `gmake` target) | Browser login; tokens are stored and refreshed for you | `gcloud auth login` |
| You, through your Python code (`google-cloud-*` libraries) | Same, but one command writes a hidden credentials file your libraries find automatically | `gcloud auth application-default login` |
| A robot, with a key file | JSON key + the `GOOGLE_APPLICATION_CREDENTIALS` variable | *(the bootcamp method — optional here)* |
| A robot attached to a VM | No file: the VM is declared to *be* the robot when it is created | nothing — this is what `vm_create` does |

An **API key** (a bare character string) is yet another mechanism, meant for
public APIs such as Maps. Nothing in this template uses one.

> The two logins are separate on purpose: your tools and your programs have
> different rights and lifetimes. And if `GOOGLE_APPLICATION_CREDENTIALS` is
> set, your Python code ignores login 2 and uses the robot instead.

## The path, in order

### Step 0 — outside the distro, once

A Google account, a **GCP project**, and **billing enabled** on that project
(`console.cloud.google.com`). Without billing, BigQuery, Cloud Run, Artifact
Registry and VMs refuse to run — even inside their free tiers. On a personal
project you are the Owner and nothing below will ask you for permissions; on a
company project, ask your administrator for the roles of the modules you use.

### Step 1 — login 1: your tools

```bash
gcloud auth login
```

A browser window opens (WSL interop — if none opens, copy the URL gcloud
prints into any browser). This authorizes `gcloud` and `bq`, which is what
every `gmake` target calls.

### Step 2 — check what you can see

```bash
gmake gcp_project_list
```

Lists the projects your account can access — your first successful call.

### Step 3 — fill the two env contracts

Once per machine — your shared defaults, from the committed sample:

```bash
cp ~/.config/zsh/gmake/.env.global.sample ~/.config/zsh/gmake/.env.global
```

then fill `GCP_REGION` and `ZONE` at minimum.

Once per project — its identity, in the project folder:

```bash
cp ~/.config/zsh/gmake/.env.project.sample ~/projects/<name>/.env
```

then fill `GCP_PROJECT` at minimum; add each module's variables as you need
them.

`gmake` always passes `--project` explicitly, so you never need
`gcloud config set project` — the `.env` file is the single source of truth.

### Step 4 — enable the APIs

A fresh project has most Google Cloud APIs turned **off**; calling a disabled
one fails with a `SERVICE_DISABLED` error. Enable everything the modules use:

```bash
gmake gcp_enable_apis
```

Or one service at a time: `gcp_enable_compute`, `gcp_enable_storage`,
`gcp_enable_bigquery`, `gcp_enable_cloudrun`, `gcp_enable_artifact_registry`.
Enabling is free and idempotent.

### Step 5 — login 2: your Python code

```bash
gcloud auth application-default login
```

This is what your scripts, notebooks and tests read when they import
`google-cloud-bigquery` and friends. It is separate from step 1 — do both.

### Step 6 — first steps per workflow

- **Docker → Artifact Registry**: [`docker.md`](../make/docker.md) — one
  `docker_auth` per machine, one repository per project, then build → push.
- **Cloud Run**: [`cloud_run.md`](../make/cloud_run.md) — build → push →
  deploy; services are private by default.
- **VMs**: [`gcloud_compute.md`](../make/gcloud_compute.md) — note that
  `vm_setup` sends `scripts/setup_vm.sh` *from your project* to the VM; the
  template does not ship that file, so write a small bootstrap script (for
  example: install `uv`, create the venv) when you need it.
- **BigQuery**: [`bigquery.md`](../make/bigquery.md) — dataset → tables.

## Good to know

- **Credentials live inside the distro** (`~/.config/gcloud`). Recreating the
  distro loses both logins — redo steps 1 and 5 afterwards.
- **A JSON key is a password.** Whoever holds it *is* the robot. Never commit
  it, never paste it anywhere. Prefer the human logins whenever a browser is
  available; keep keys for CI and headless machines.
- Free tiers exist (BigQuery gives on the order of 1 TB of queries per month;
  Cloud Run and Artifact Registry have small free quotas) — but they all
  require billing to be enabled. Compute VMs are billed per second of uptime,
  hence the explicit `vm_start` / `vm_stop` targets.
