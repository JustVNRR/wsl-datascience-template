# WSL Data Science Template with OMZ & GCP

A reproducible WSL2 workstation for data science: one PowerShell command builds a fresh Ubuntu 24.04 distro with:
- the shell,
- the Python stack,
- the GCP-oriented MLOps workflow already in place.

## Features

- **Minimal setup** — first boot asks for your username, password, region and timezone.
- **A modern shell** — Zsh, Oh My Zsh, and Starship, with fzf everywhere and Rust-based replacements for `ls`, `cat`, and `grep` ([shell environment](#shell-environment-zsh)).
- **Command memory** — cheatsheets stored as plain files, fuzzy-injected into the prompt with `Ctrl + H`.
- **Data Science ready** — `uv` for Python, a full build toolchain to compile any wheel, and CV/OCR libraries preinstalled.
- **Project scaffolding** — `fnew` fuzzy-picks a template from your curated catalog and bootstraps the virtual environment and direnv.
- **MLOps** — `gmake` exposes modular targets for GCP, BigQuery, Docker, Cloud Run, VMs, lint, and tests ([global makefile](#mlops-global-makefile-gmake)).

---

## Prerequisites

- Windows 10/11 with **WSL2** installed and enabled.
- **Docker Desktop** (or Docker Engine running via WSL).
- PowerShell 5.1+ or PowerShell 7+.

---

## Quick Start

Make sure Docker Desktop is running before you start.

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/JustVNRR/wsl-datascience-template.git
   cd wsl-datascience-template
   cp zsh/gmake/.env.global.sample zsh/gmake/.env.global
   ```
   The copy is your local, gitignored global configuration — fill in your region and zone at your convenience.

2. **Build and register the instance:**

   Default build (creates `ubuntu-datascience-build` installed at `D:\WSL\ubuntu-datascience-build`):
   ```powershell
   .\build.ps1
   ```

   Custom instance name and path:
   ```powershell
   .\build.ps1 -DistroName "ubuntu-ml-dev" -InstallPath "D:\WSL\ubuntu-ml-dev"
   ```

3. **Launch your session:**

   - Close Windows Terminal first — a freshly imported distro only appears in the profile list after a restart.
   - Launch your environment by choosing your distro's profile in a new Windows Terminal or by typing the following command in a powershell:

   ```powershell
   wsl -d <DistroName>
   ```

---

## Shell Environment (zsh)

The shell experience is documented per topic under [`docs/zsh/`](docs/zsh/):

| Topic | Doc | Highlights |
| :--- | :--- | :--- |
| Plugins | [Oh My Zsh plugins](docs/zsh/plugins.md) | `git`, `fzf`, autosuggestions, syntax highlighting |
| Keybindings | [ZLE shortcuts](docs/zsh/keybindings.md) | fuzzy-open in VS Code, insert paths, aliases, cheatsheet commands |
| Aliases | [Custom aliases](docs/zsh/aliases.md) | modern `ls` / `cat` / `grep`, `ports`, `reload` |
| Interactive tools | [fzf-powered commands](docs/zsh/interactive.md) | fuzzy navigation, git pickers, `fcheat`, `extract` |

---

## MLOps Global Makefile (`gmake`)

Follow the [GCP onboarding guide](docs/gcp/onboarding.md) before your first `gmake` target.

- **Cascading configuration:**

   - Only values shared across all projects belong in the `.env.global`
   - Anything identifying a project (GCP project, resource names) lives in its `.env`.
   - Both files are gitignored and start from committed samples in `gmake/` (`.env.global.sample`, `.env.project.sample`). 

- **Project-scoped execution:** 

- **`gmake` vs `make`:** 
  - Type `gmake` (without any arguments) to display a formatted help menu listing all available global targets (GCP compute, BigQuery, Docker, Cloud Run, etc.).
  - Use `fnew (recommanded)`, `gmake copier_project` or `gmake cruf_project` from `~/projects` to scaffold a project template.
  - Use `gmake <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the global `Makefile` in `~/.config/zsh/gcp`.
  - Use `make <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the local `Makefile` in to your current project folder.

The global makefile is split into one module per domain under `gmake/make/`, each documented in [`docs/make/`](docs/make/) — indexed below along a project's lifecycle:

| Stage | Module | Main targets |
| :--- | :--- | :--- |
| Create | [Project scaffolding](docs/make/project-setup.md) | `fnew`, `copier_project`, `cruft_project` |
| Verify | [Lint](docs/make/lint.md) | `lint`, `lint-py`, `lint-sh`, `lint-format` |
| Verify | [Tests](docs/make/tests.md) | `test`, `test-fast`, `test-functional`, `test-gcp` |
| Operate | [GCP infrastructure & IAM](docs/make/gcp.md) | `gcp_project_list`, `gcs_*`, `iam_setup_service_account` |
| Operate | [BigQuery](docs/make/bigquery.md) | `bigquery_*` |
| Operate | [Docker & Artifact Registry](docs/make/docker.md) | `docker_*`, `artifact_registry_*` |
| Deploy | [Cloud Run](docs/make/cloud_run.md) | `cloudrun_*` |
| Operate | [Compute Engine (VMs)](docs/make/gcloud_compute.md) | `vm_*` |
| Collaborate | [GitHub PRs](docs/make/github.md) | `gh_pr_*` |

---

## Bundled Software & Stack

### Core System & CLI Utilities

| Category | Tools |
| :--- | :--- |
| Core | `zsh`, `sudo`, `adduser`, `ca-certificates`, `curl`, `wget`, `openssh-client`, `tzdata`, `nano`, `tree`, `strace`, `lsof`, `tar`, `unzip`, `bzip2`, `unrar`, `p7zip-full`, `gzip`, `xz-utils`, `zstd` |
| Search & navigation | `fzf` (fuzzy search), `fd-find` (linked to `fd`), `zoxide` (directory hopping), `ripgrep` (ultra-fast grep) |
| Inspection & display | `eza` (modern `ls` replacement), `batcat` (syntax highlighting, linked to `bat`), `jq` (JSON processor) |
| DevOps & cloud | `gh` (GitHub CLI), `direnv`, `shellcheck`, `google-cloud-sdk`, `sqlite3` |

### Python & Data Science

| Category | Tools |
| :--- | :--- |
| Package manager | `uv` (Astral's fast Python package manager) |
| Build libraries | `build-essential`, `llvm`, `make`, `python3-dev`, `libssl-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `tk-dev`, `libffi-dev`, `liblzma-dev` |
| Computer Vision & OCR | `ffmpeg`, `imagemagick`, `tesseract-ocr`, `libtesseract-dev` |

---

## Project Structure

```text
├── .config/zsh/
│   ├── .zshrc               # Main orchestrator (loads OMZ, modules, prompts)
│   ├── aliases.zsh          # Custom shortcuts and interactive falias picker
│   ├── bindings.zsh         # ZLE widgets and keybindings
│   ├── cheatsheet.zsh       # Interactive cheatsheet selector (fcheat)
│   ├── cheatsheets/         # Auto-scanned data files: CTRL+H command lists (fcheat)
│   │   ├── *_commands.sh    # Domain-specific command lists (git, docker, bash, etc.)
│   │   └── templates.tsv    # Curated project template catalog (fnew picker)
│   ├── gmake/               # Global MLOps Makefile ecosystem (the gmake alias)
│   │   ├── .env.global.sample  # Shared-defaults contract (copy to .env.global, gitignored)
│   │   ├── .env.project.sample # Per-project contract (copy into a project as .env)
│   │   ├── global_makefile.mk # Global entrypoint for the MLOps Makefile
│   │   └── make/            # One Makefile module per domain (documented in docs/make/)
│   │       ├── project-setup.mk   # copier/cruft scaffolding + venv/direnv bootstrap
│   │       ├── lint.mk            # ruff (Python) + shellcheck (shell) checks
│   │       ├── tests.mk           # pytest lanes (fast / functional / gcp)
│   │       ├── gcp.mk             # GCP projects, Cloud Storage buckets, IAM
│   │       ├── bigquery.mk        # BigQuery datasets & tables
│   │       ├── docker.mk          # Local/prod Docker builds, Artifact Registry
│   │       ├── cloud_run.mk       # Cloud Run deploy, logs, URL
│   │       ├── gcloud_compute.mk  # Compute Engine VM lifecycle
│   │       └── github.mk          # GitHub PR workflow (gh CLI)
│   ├── exports.zsh          # Environment variables and dynamic PATH exports
│   ├── fzf.zsh              # Fuzzy finder engines, layout, and preview templates
│   ├── history.zsh          # History file sizing and persistence policies
│   ├── navigation.zsh       # Advanced directory hopping (cdv, cda, fv, fa)
│   ├── nvm.zsh              # Lazy-loaded Node Version Manager and .nvmrc hooks
│   ├── prompts/
│   │   ├── starship.toml    # Starship visual configuration
│   │   └── starship.zsh     # Starship initialization hook
│   ├── python.zsh           # uv autocompletion
│   ├── scaffold.zsh         # Interactive project scaffolding picker (fnew)
│   └── unzip.zsh            # Interactive archive extraction handler
├── assets/
│   └── terminal-icon.png    # Default Windows Terminal profile icon (copied next to the VHDX)
├── Dockerfile               # Rootfs build recipe with Ubuntu 24.04 and DS stack
├── first_boot.sh            # User creation, Systemd, sudo access, Python setup
├── build.ps1                # PowerShell build, export, safety checks, and import script
├── unregister.ps1           # Counterpart removal: distro, install folder, Terminal leftovers
├── docs/
│   ├── gcp/                 # GCP onboarding guide (accounts, auth, first steps)
│   ├── make/                # Per-module documentation for the global Makefile
│   └── zsh/                 # Shell environment documentation (plugins, keys, aliases, tools)
├── .gitattributes           # Enforces strict LF line endings for shell scripts
├── .gitignore               # Prevents committing build artifacts (*.tar, *.vhdx)
└── README.md
```

---

## Maintenance & Removal

To completely delete an instance and everything it left behind, use the build script's counterpart:
```powershell
.\unregister.ps1 -DistroName <DistroName>
```
