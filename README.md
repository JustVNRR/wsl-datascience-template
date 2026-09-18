# WSL DataScience Template

A reproducible WSL2 workstation for data science: one PowerShell command builds a fresh Ubuntu 24.04 distro with:
- the shell,
- the Python stack,
- the MLOps workflow — the Google Cloud CLI is one `gmake gcp_install` away.

## Features

- **Minimal setup** — first boot asks for your username, password, region and timezone.
- **A modern shell** — Zsh, Oh My Zsh, and Starship, with fzf everywhere and Rust-based replacements for `ls`, `cat`, and `grep` ([shell environment](#shell-environment-zsh)).
- **Command memory** — cheatsheets stored as plain files, fuzzy-injected into the prompt with `Ctrl + H`.
- **Data Science ready** — `uv` for Python, the C build toolchain needed to compile most wheels, and CV/OCR tooling preinstalled.
- **Project scaffolding** — `fnew` fuzzy-picks a template from your curated catalog — or takes one by URL — and bootstraps the virtual environment and direnv.
- **MLOps** — `gmake` exposes modular targets for GCP, BigQuery, Docker, Cloud Run, VMs, lint, and tests. The Google Cloud ones appear once their CLI is installed ([global makefile](#mlops-global-makefile-gmake), [optional tooling](#optional-tooling)).

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
   ```

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

- **Cascading configuration:**

   - Only values shared across all projects belong in the shared `.env.global`
   - Anything identifying a project (GCP project, resource names) lives in its `.env`.
   - Both files are gitignored and start from committed samples in `gmake/` (`.env.global.sample`, `.env.project.sample`).

- **`gmake` vs `make`:**
  - Type `gmake` (without any arguments) to display a formatted help menu listing all available global targets (GCP compute, BigQuery, Docker, Cloud Run, etc.).
  - Use `fnew (recommended)`, `gmake copier_project` or `gmake cruft_project` from `~/projects` to scaffold a project template.
  - Use `gmake <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the global `Makefile` in `~/.config/zsh/gmake`.
  - Use `make <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the local `Makefile` in your current project folder.

The global makefile is split into one module per domain under `gmake/make/`, each documented in [`docs/make/`](docs/make/) — indexed below along a project's lifecycle:

| Stage | Module | Main targets |
| :--- | :--- | :--- |
| Setup | [Optional tooling](docs/make/install.md) | `gcp_install`, `gcp_uninstall` |
| Create | [Project scaffolding](docs/make/project-setup.md) | `fnew`, `copier_project`, `cruft_project`, `ccds_project` |
| Verify | [Lint](docs/make/lint.md) | `lint`, `lint-py`, `lint-sh`, `lint-format` |
| Verify | [Tests](docs/make/tests.md) | `test`, `test-fast`, `test-functional`, `test-gcp` |
| Operate | [GCP infrastructure & IAM](docs/make/gcp.md) | `gcp_project_list`, `gcs_*`, `iam_setup_service_account` |
| Operate | [BigQuery](docs/make/bigquery.md) | `bigquery_*` |
| Operate | [Docker](docs/make/docker.md) | `docker_build_*`, `docker_run_local`, `docker_push_prod` |
| Operate | [Artifact Registry](docs/make/artifact_registry.md) | `docker_auth`, `artifact_registry_*` |
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
| DevOps & cloud | `gh` (GitHub CLI), `direnv`, `shellcheck`, `sqlite3` |

### Optional Tooling

| Category | Tools |
| :--- | :--- |
| Google Cloud CLI | [GCP onboarding guide](docs/optional_tooling/gcp_onboarding.md) |

### Python & Data Science

| Category | Tools |
| :--- | :--- |
| Package manager | `uv` (Astral's fast Python package manager) |
| Build libraries | `build-essential`, `python3-dev`, `libffi-dev`, `libssl-dev` |
| Computer Vision & OCR | `ffmpeg`, `imagemagick`, `tesseract-ocr`, `libtesseract-dev` |

---

## Project Structure

Two distinct trees: the **repository** you clone and version, and the **distro**
the build produces. The shell environment is the link between them — `zsh/` is a
source directory that `build.ps1` copies into the image; nothing reads it from
the repository at runtime.

### The repository

```text
├── zsh/                     # Shell environment, deployed into the distro at build time
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
│   │       ├── install.mk         # optional tooling: install a CLI the image does not ship
│   │       ├── project-setup.mk   # copier/cruft scaffolding + venv/direnv bootstrap
│   │       ├── lint.mk            # ruff (Python) + shellcheck (shell) checks
│   │       ├── tests.mk           # pytest lanes (fast / functional / gcp)
│   │       ├── gcp.mk             # GCP projects, Cloud Storage buckets, IAM
│   │       ├── bigquery.mk        # BigQuery datasets & tables
│   │       ├── docker.mk          # image builds and local runs (docker only)
│   │       ├── artifact_registry.mk # the registry targets that call gcloud
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
│   ├── make-icon.ps1        # Regenerates the icon below (standalone PowerShell)
│   └── terminal-icon.png    # Windows Terminal profile icon (copied next to the VHDX)
├── docs/
│   ├── gcp/                 # GCP onboarding guide (accounts, auth, first steps)
│   ├── make/                # Per-module documentation for the global Makefile
│   └── zsh/                 # Shell environment documentation (plugins, keys, aliases, tools)
├── .github/
│   └── workflows/
│       ├── ci.yml           # Static checks (shellcheck, zsh -n, make parse, doc drift)
│       └── image.yml        # Rootfs image build (push/PR + weekly, catches upstream drift)
├── Dockerfile               # Rootfs build recipe with Ubuntu 24.04 and DS stack
├── first_boot.sh            # User creation, Systemd, sudo access, Python setup
├── build.ps1                # PowerShell build, export, safety checks, and import script
├── unregister.ps1           # Counterpart removal: distro, install folder, Terminal leftovers
├── .dockerignore            # Keeps the context lean, keeps .env.global out of the image
├── .gitattributes           # Enforces strict LF line endings for shell scripts
├── .gitignore               # Prevents committing build artifacts (*.tar, *.vhdx)
├── LICENSE                  # MIT
└── README.md
```

### Inside the distro

Written by the build or by `gmake` targets. None of it is versioned, and
deleting the distro deletes all of it.

```text
~/.config/zsh/               # = zsh/ from the repository
├── gmake/
│   ├── .env.global          # Shared defaults (gmake gcp_enable_global_env)
│   ├── global_makefile.mk
│   └── make/*.mk
└── .zshrc, modules, prompts/, cheatsheets/

~/projects/<project>/        # One directory per project
├── .env                     # This project's identity (gmake gcp_enable_project_env)
├── .envrc                   # direnv hook (fnew / gmake copier_project)
└── .venv/

~/.local/share/oh-my-zsh/    # Cloned at build time
~/.nvm/                      # Cloned at build time
~/.local/bin/                # uv tools: copier, cruft, ccds, cookiecutter, ruff
~/.config/gcloud/            # The two GCP logins (gcp_auth_cli, gcp_auth_libs)
/etc/wsl.conf                # Default user, systemd (first_boot.sh)
```

---

## Continuous Integration

Two GitHub Actions workflows, in `.github/workflows/`:

| Workflow | Runs on | What it proves |
| :--- | :--- | :--- |
| `ci.yml` — Static checks | every push, PRs onto `main` | shellcheck on the shell scripts, `zsh -n` on the configuration, the ASCII-only rule for the `.ps1` files, the makefile parses with a complete help menu, and the docs and cheatsheets stay in sync with the `gmake` modules |
| `image.yml` — Rootfs image build | every push, PRs onto `main`, weekly, manual | the Dockerfile still resolves end to end: apt repositories, download URLs, git clones |

They check the **repository**, not a running distro — neither replaces a real
`.\build.ps1` run.

The weekly run is the point of `image.yml`: it does not check your last edit, it
catches **upstream drift** — a package that moved, a URL that changed — while the
repository sits untouched, so an upcoming rebuild does not surprise you.

Each workflow is documented in full at the top of its own file: read that before
changing one.

---

## Maintenance & Removal

To completely delete an instance and everything it left behind, use the build script's counterpart:
```powershell
.\unregister.ps1 -DistroName <DistroName>
```

The distro's virtual disk is deleted, so **nothing inside it survives**, and a
rebuild destroys the existing instance the same way. Check this list before
either:

| Kept inside the distro | Before you unregister or rebuild |
| :--- | :--- |
| `~/projects/` | Nothing backs it up — push your work to a remote first |
| `~/.ssh/` | A key generated inside cannot be recovered: copy it out, or plan to revoke and regenerate it |
| `~/.config/gcloud/` | Both logins are redoable in minutes ([onboarding](docs/optional_tooling/gcp_onboarding.md)) |
| `~/.config/zsh/gmake/.env.global` | A handful of lines; `gmake gcp_install`, then `gmake gcp_enable_global_env`, recreate the file to refill |
| `~/.config/zsh/cheatsheets/templates.tsv` | Only for rows you added inside the distro: the file is redeployed from the repository at build time — move the line into `zsh/` to keep it |

---

## License

MIT — see [LICENSE](LICENSE).
