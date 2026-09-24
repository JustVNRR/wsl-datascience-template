# WSL DataScience Template

A reproducible WSL2 workstation for data science: one PowerShell command builds a fresh Ubuntu 24.04 distro with:
- the shell,
- the Python stack,
- the MLOps workflow with GCP (run `gmake gcp_install` first).

## Features

- **Minimal setup** — the build asks for your username and password; Ubuntu then asks for your region and city.
- **A modern shell** — Zsh, Oh My Zsh, and Starship, with fzf everywhere and Rust-based replacements for `ls` and `cat` ([shell environment](#shell-environment-zsh)).
- **Command memory** — cheatsheets stored as plain files, fuzzy-injected into the prompt with `Alt + z`.
- **Data Science ready** — `uv` for Python, the C build toolchain needed to compile most wheels, and CV/OCR tooling preinstalled.
- **Project scaffolding** — `fnew` fuzzy-picks a template from your curated catalog — or takes one by URL — and bootstraps the virtual environment and direnv.
- **MLOps** — `gmake` exposes modular targets for GCP, BigQuery, Docker, Cloud Run, VMs, lint, and tests. The Google Cloud ones appear once their CLI is installed ([the gmake Makefile](#mlops-makefile-gmake), [optional tooling](#optional-tooling)).

---

## Prerequisites

- Windows 10/11 with **WSL2** installed and enabled.
- **Docker Desktop** (or Docker Engine running via WSL).
- PowerShell 5.1+ or PowerShell 7+, allowed to run local scripts — check it:
  ```powershell
  Get-ExecutionPolicy # Should return RemoteSigned or Unrestricted
  ```
  If it returns `Restricted` or `AllSigned` run:

  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

---

## Quick Start

Make sure Docker Desktop is running before you start.

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/JustVNRR/wsl-datascience-template.git
   cd wsl-datascience-template
   ```

2. **Build and register the instance:**

   ```powershell
   .\wsl.ps1 build
   ```

   It asks for the instance's name, then confirms where it will live —
   `D:\WSL\<name>` by default. Ctrl+C aborts.

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

## MLOps Makefile (`gmake`)

- **Cascading configuration:**

   - Only values shared across all projects belong in the shared `.env.global`
   - Anything identifying a project (GCP project, resource names) lives in its `.env`.
   - Both files are gitignored and start from committed samples in `gmake/` (`.env.global.sample`, `.env.project.sample`).

- **`gmake` vs `make`:**
  - Type `gmake` (without any arguments) to display a formatted help menu listing every gmake target (GCP compute, BigQuery, Docker, Cloud Run, etc.).
  - Use `fnew (recommended)`, `gmake copier_project`, `gmake cruft_project` or `gmake ccds_project` from `~/projects` to scaffold a project template.
  - Use `gmake <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the `Makefile` in `~/.config/zsh/gmake`.
  - Use `make <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the local `Makefile` in your current project folder.

The gmake Makefile is split into one module per domain under `gmake/make/`, each documented in [`docs/make/`](docs/make/) — indexed below along a project's lifecycle:

| Stage | Module | Main targets |
| :--- | :--- | :--- |
| Setup | [Optional tooling](docs/make/install.md) | `gcp_install`, `gcp_uninstall` |
| Create | [Project scaffolding](docs/make/project-setup.md) | `fnew`, `copier_project`, `cruft_project`, `ccds_project` |
| Verify | [Lint](docs/make/lint.md) | `lint`, `lint-py`, `lint-sh`, `lint-format` |
| Verify | [Tests](docs/make/tests.md) | `test`, `test-fast`, `test-functional`, `test-gcp` |
| Operate | [GCP infrastructure & IAM](docs/make/gcp.md) | `gcp_project_list`, `gcs_*`, `iam_setup_service_account` |
| Operate | [BigQuery](docs/make/bigquery.md) | `bigquery_*` |
| Operate | [Docker](docs/make/docker.md) | `docker_build_local`, `docker_run_local` |
| Operate | [Artifact Registry](docs/make/artifact_registry.md) | `artifact_registry_*` |
| Deploy | [Cloud Run](docs/make/cloud_run.md) | `cloudrun_*` |
| Operate | [Compute Engine (VMs)](docs/make/gcloud_compute.md) | `vm_*` |
| Collaborate | [GitHub PRs](docs/make/github.md) | `gh_pr_*` |

---

## Bundled Software & Stack

### Core System & CLI Utilities

| Category | Tools |
| :--- | :--- |
| Core | `zsh`, `sudo`, `adduser`, `ca-certificates`, `curl`, `wget`, `openssh-client`, `iputils-ping`, `tzdata`, `nano`, `less`, `tree`, `strace`, `lsof`, `tar`, `unzip`, `bzip2`, `unrar`, `p7zip-full`, `gzip`, `xz-utils`, `zstd` |
| Search & navigation | `fzf` (fuzzy search), `fd-find` (linked to `fd`), `zoxide` (directory hopping), `ripgrep` (ultra-fast grep) |
| Inspection & display | `eza` (modern `ls` replacement), `batcat` (syntax highlighting, linked to `bat`), `jq` (JSON processor), `tldr` (command examples, an alternative to man pages) |
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
source directory that the build copies into the image; nothing reads it from
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
│   ├── gmake/               # MLOps Makefile ecosystem (the gmake alias)
│   │   ├── .env.global.sample  # Shared-defaults contract (copy to .env.global, gitignored)
│   │   ├── .env.project.sample # Per-project contract (copy into a project as .env)
│   │   ├── Makefile           # Entrypoint for the MLOps Makefile
│   │   └── make/            # One Makefile module per domain (documented in docs/make/)
│   │       ├── install.mk         # optional tooling: install a CLI the image does not ship
│   │       ├── project-setup.mk   # copier/cruft scaffolding + venv/direnv bootstrap
│   │       ├── lint.mk            # ruff (Python) + shellcheck (shell) checks
│   │       ├── tests.mk           # pytest lanes (fast / functional / gcp)
│   │       ├── gcp.mk             # GCP projects, Cloud Storage buckets, IAM
│   │       ├── bigquery.mk        # BigQuery datasets & tables
│   │       ├── docker.mk          # image builds and local runs (docker only)
│   │       ├── artifact_registry.mk # the production image: build, push, auth, IAM
│   │       ├── cloud_run.mk       # Cloud Run deploy, logs, URL
│   │       ├── gcloud_compute.mk  # Compute Engine VM lifecycle
│   │       └── github.mk          # GitHub PR workflow (gh CLI)
│   ├── exports.zsh          # Environment variables and dynamic PATH exports
│   ├── fzf.zsh              # Fuzzy finder engines, layout, and preview templates
│   ├── history.zsh          # History file sizing and persistence policies
│   ├── navigation.zsh       # Advanced directory hopping (cdv, cda, fv, fa)
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
│   ├── make/                # Per-module documentation for the gmake Makefile
│   ├── optional_tooling/    # Onboarding for the tools the image does not ship
│   ├── wsl/                 # Instance administration: the commands, their options, examples
│   └── zsh/                 # Shell environment documentation (plugins, keys, aliases, tools)
├── scripts/                 # Instance administration, one file per command
│   ├── instance.ps1         # What they share: the marker, the look, Docker Desktop
│   └── *.ps1                # list, build, adopt, start, stop, shell, unregister,
│                            # archive, restore, duplicate, shrink
├── .github/
│   └── workflows/
│       ├── ci.yml           # Static checks (shellcheck, zsh -n, make parse, doc drift)
│       └── image.yml        # Rootfs image build (push/PR + weekly, catches upstream drift)
├── Dockerfile               # Rootfs build recipe with Ubuntu 24.04 and DS stack
├── first_boot.sh            # User creation, Systemd, sudo access, Python setup
├── wsl.ps1                  # The way in: one command at the root, the scripts in scripts\
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
│   ├── Makefile
│   └── make/*.mk
└── .zshrc, modules, prompts/, cheatsheets/

~/projects/<project>/        # One directory per project
├── .env                     # This project's identity (gmake gcp_enable_project_env)
├── .envrc                   # direnv hook (fnew / gmake copier_project)
└── .venv/

~/.local/share/oh-my-zsh/    # Cloned at build time
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
`.\wsl.ps1 build` run.

The weekly run is the point of `image.yml`: it does not check your last edit, it
catches **upstream drift** — a package that moved, a URL that changed — while the
repository sits untouched, so an upcoming rebuild does not surprise you.

Each workflow is documented in full at the top of its own file: read that before
changing one.

---

## Instance Administration (wsl.ps1)

Instances are listed, built, started, stopped, opened, copied, archived,
restored, compacted and removed from `wsl.ps1`, at the root of the repository.
The scripts themselves live in `scripts\` — `wsl.ps1` is the only thing to type.

| Command | What it does |
| :--- | :--- |
| [`.\wsl.ps1 list`](docs/wsl/commands.md#list) | show our instances, the archives, and what is left over |
| [`.\wsl.ps1 build`](docs/wsl/commands.md#build) | build an instance from the image (Docker, then WSL) |
| [`.\wsl.ps1 adopt`](docs/wsl/commands.md#adopt) | mark an instance that already exists as one of ours |
| [`.\wsl.ps1 start`](docs/wsl/commands.md#start) | start a stopped instance |
| [`.\wsl.ps1 stop`](docs/wsl/commands.md#stop) | stop a running instance |
| [`.\wsl.ps1 shell`](docs/wsl/commands.md#shell) | open a shell in one of our instances |
| [`.\wsl.ps1 unregister`](docs/wsl/commands.md#unregister) | remove an instance, and what it left on Windows |
| [`.\wsl.ps1 archive`](docs/wsl/commands.md#archive) | write an instance to a named archive |
| [`.\wsl.ps1 restore`](docs/wsl/commands.md#restore) | rebuild an instance from an archive |
| [`.\wsl.ps1 duplicate`](docs/wsl/commands.md#duplicate) | copy an instance under another name |
| [`.\wsl.ps1 shrink`](docs/wsl/commands.md#shrink) | reclaim the space an instance has freed |

Each command, with its options, its examples and what it prints, is documented
in [**Instance commands**](docs/wsl/commands.md).

---

## License

MIT — see [LICENSE](LICENSE).
