# WSL DataScience Template

A reproducible WSL2 workstation for data science: one PowerShell command builds a fresh Ubuntu 24.04 distro with:
- the shell,
- optional tooling as packs — Python (`python`), Google Cloud (`gcp`), media and OCR (`vision`) — added with `.\wsl.ps1 add_pack`.

## Features

- **Minimal setup** — the build asks for your username and password; Ubuntu then asks for your region and city.
- **A modern shell** — Zsh, Oh My Zsh, and Starship, with fzf everywhere and Rust-based replacements for `ls` and `cat` ([shell environment](#shell-environment-zsh)).
- **Command memory** — cheatsheets stored as plain files, fuzzy-injected into the prompt with `Alt + z`.
- **Data Science ready** — the `python` pack brings `uv`, Python 3 and the C build toolchain most wheels are compiled with; `vision` brings the media and OCR tools.
- **Project scaffolding** — with the `python` pack, `fnew` fuzzy-picks a template from your curated catalog — or takes one by URL — and bootstraps the virtual environment and direnv.
- **MLOps** — `gmake` exposes modular targets for Docker, the environment files and GitHub, and a pack adds its own: GCP, BigQuery, Cloud Run and the VMs with `gcp`, the lint and test lanes with `python`. They appear as the packs do ([the gmake Makefile](#mlops-makefile-gmake), [optional tooling](#optional-tooling)).

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
   - Anything identifying a project (project ids, resource names) lives in its `.env`.
   - Both are gitignored, and both are built from committed samples by [`gmake env_global_enable` / `gmake env_project_enable`](docs/make/env.md) — the socle's samples plus those the packs ship beside their modules. The commands only ever add what is missing.

- **`gmake` vs `make`:**
  - Type `gmake` (without any arguments) to display a formatted help menu listing every gmake target (GCP compute, BigQuery, Docker, Cloud Run, etc.).
  - Use `fnew (recommended)`, `gmake copier_project`, `gmake cruft_project` or `gmake ccds_project` from `~/projects` to scaffold a project template.
  - Use `gmake <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the `Makefile` in `~/.config/zsh/gmake`.
  - Use `make <target>` from `~/projects/<your-project-folder>` to run project relative tasks from the local `Makefile` in your current project folder.

The gmake Makefile is split into one module per domain, each documented beside
it. The socle's modules live under `gmake/make/`, their pages in
[`docs/make/`](docs/make/); a pack carries its modules *and* its pages in the
same folder, under `packs/` at the root of this repository — so a pack is one
folder that can be lifted out whole. Indexed below along a project's lifecycle:

| Stage | Module | Main targets |
| :--- | :--- | :--- |
| Setup | [Environment files](docs/make/env.md) | `env_global_enable`, `env_project_enable` |
| Operate | [Docker](docs/make/docker.md) | `docker_build_local`, `docker_run_local` |
| Operate | [Packs installed here](docs/make/packs.md) | `packs_list` |
| Collaborate | [GitHub PRs](docs/make/github.md) | `gh_pr_*` |

Then the packs. Each one is listed once — the README does not follow a pack as
it grows, and a pack leaves with its folder:

| Pack | Start here | Main targets |
| :--- | :--- | :--- |
| `gcp` | [GCP onboarding guide](packs/gcp/docs/onboarding.md) | `gcp_*`, `gcs_*`, `iam_*`, `bigquery_*`, `cloudrun_*`, `vm_*`, `artifact_registry_*` |
| `python` | [Python](packs/python/docs/python.md) | `fnew`, `copier_project`, `cruft_project`, `ccds_project`, `lint*`, `test*` |
| `vision` | [Vision & OCR](packs/vision/docs/vision.md) | — |

A pack that brings no target of its own shows `—`: `vision` installs ffmpeg,
ImageMagick and Tesseract, and their commands go to the cheatsheet picker.

What a pack is, what it must contain, and how to add one:
[`docs/packs.md`](docs/packs.md). One reaches an instance with
[`.\wsl.ps1 add_pack`](docs/wsl/commands.md#add_pack) — or by being chosen while
the instance is built, [`.\wsl.ps1 build`](docs/wsl/commands.md#build) — and
leaves with `remove_pack`.

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
| Google Cloud CLI | [GCP onboarding guide](packs/gcp/docs/onboarding.md), [`.\wsl.ps1 add_pack`](docs/wsl/commands.md#add_pack) |
| Python | [Python](packs/python/docs/python.md), [`.\wsl.ps1 add_pack`](docs/wsl/commands.md#add_pack) |
| Vision & OCR | [Vision & OCR](packs/vision/docs/vision.md), [`.\wsl.ps1 add_pack`](docs/wsl/commands.md#add_pack) |

### Python & Data Science

The image carries none of it: `uv`, Python 3, the four packages most wheels are
compiled with (`build-essential`, `python3-dev`, `libffi-dev`, `libssl-dev`) and
the scaffolding tools arrive with the [`python` pack](packs/python/docs/python.md).

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
│   │   └── *_commands.sh    # Domain-specific command lists (git, docker, bash, etc.)
│   ├── gmake/               # MLOps Makefile ecosystem (the gmake alias)
│   │   ├── .env.global.sample  # The socle's share of the shared defaults (gmake env_global_enable)
│   │   ├── .env.project.sample # The socle's share of a project's variables (gmake env_project_enable)
│   │   ├── Makefile           # Entrypoint for the MLOps Makefile
│   │   └── make/            # The socle's modules, one per domain (pages in docs/make/)
│   │       ├── env.mk             # the two env files, assembled from the samples
│   │       ├── docker.mk          # image builds and local runs (docker only)
│   │       ├── github.mk          # GitHub PR workflow (gh CLI)
│   │       └── packs.mk           # what this instance carries (gmake packs_list)
│   ├── exports.zsh          # Environment variables and dynamic PATH exports
│   ├── fzf.zsh              # Fuzzy finder engines, layout, and preview templates
│   ├── history.zsh          # History file sizing and persistence policies
│   ├── navigation.zsh       # Advanced directory hopping (cdv, cda, fv, fa)
│   ├── prompts/
│   │   ├── starship.toml    # Starship visual configuration
│   │   └── starship.zsh     # Starship initialization hook
│   └── unzip.zsh            # Interactive archive extraction handler
├── assets/
│   ├── make-icon.ps1        # Regenerates the icon below (standalone PowerShell)
│   └── terminal-icon.png    # Windows Terminal profile icon (copied next to the VHDX)
├── docs/
│   ├── make/                # Documentation of the socle's gmake modules
│   ├── wsl/                 # Instance administration: the commands, their options, examples
│   └── zsh/                 # Shell environment documentation (plugins, keys, aliases, tools)
├── packs/                   # Optional tooling, one folder per pack
│   ├── gcp/                 # Google Cloud CLI, BigQuery, Cloud Run, VMs, Artifact Registry
│   │   ├── install.sh       # what `wsl.ps1 add_pack` runs inside the instance
│   │   ├── remove.sh        # what `wsl.ps1 remove_pack` runs before the folder goes
│   │   ├── env.global.sample  # the pack's shared defaults (GCP_REGION, CLOUDRUN_MEMORY…)
│   │   ├── env.project.sample # the pack's project variables (GCP_PROJECT, BUCKET_NAME…)
│   │   ├── make/            # the pack's modules, loaded as soon as the folder is there
│   │   ├── cheatsheets/     # the pack's fcheat sheets, each with its `# requires:` header
│   │   └── docs/            # the pack's pages, onboarding walkthrough included
│   ├── python/              # Python 3, uv, the compiler, the scaffolding tools
│   │   ├── pack.conf        # what it installs, and the line `add_pack` shows
│   │   ├── install.sh       # what `wsl.ps1 add_pack` runs inside the instance
│   │   ├── remove.sh        # what `wsl.ps1 remove_pack` runs before the folder goes
│   │   ├── make/            # its modules: lint, the test lanes, project setup
│   │   ├── cheatsheets/     # its fcheat sheets, and the catalog fnew reads
│   │   ├── zsh/             # its shell files: uv's PATH, the fnew picker
│   │   └── docs/            # the pack's pages, one per module
│   └── vision/              # ffmpeg, ImageMagick, Tesseract: media and OCR tools
│       ├── pack.conf        # what it installs, and the line `add_pack` shows
│       ├── install.sh       # what `wsl.ps1 add_pack` runs inside the instance
│       ├── remove.sh        # what `wsl.ps1 remove_pack` runs before the folder goes
│       ├── cheatsheets/     # their commands, in the fcheat picker
│       └── docs/            # the pack's page
├── scripts/                 # Instance administration, one file per command
│   ├── instance.ps1         # What they share: the marker, the look, Docker Desktop
│   └── *.ps1                # list, build, start, stop, shell, add_pack,
│                            # remove_pack, manage_packs, unregister, archive,
│                            # restore, duplicate, shrink
├── tests/                   # The suites that RUN the code: the arrow menu with a
│                            # scripted keyboard, the pack checklist, build's
│                            # questions over a stand-in docker, the doc drift
│   └── fake-docker/         # That stand-in: answers the preflight, fails the import
├── .github/
│   └── workflows/
│       ├── ci.yml           # Static checks, then the code suites on Windows
│       └── image.yml        # Rootfs image build (push/PR + weekly, catches upstream drift)
├── Dockerfile               # Rootfs build recipe: Ubuntu 24.04 and the socle's tools
├── first_boot.sh            # User creation, Systemd, sudo access
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
│   ├── .env.global          # Shared defaults (gmake env_global_enable)
│   ├── Makefile
│   └── make/*.mk            # the socle's modules
└── .zshrc, modules, prompts/, cheatsheets/

~/.config/packs/             # A pack lands here, its files and its tool together:
└── gcp/                     # added by `.\wsl.ps1 add_pack`, removed by remove_pack.
                             # ~/.zshrc reads its zsh/ here, gmake its make/ - nothing is copied

~/projects/<project>/        # One directory per project
├── .env.sample              # The template's list of variables (copied once to .env)
├── .env                     # This project's identity (filled in by you; env_project_enable tops it up)
├── .envrc                   # direnv hook (the template's, or written by the scaffolding)
└── .venv/

~/.local/share/oh-my-zsh/    # Cloned at build time
~/.local/bin/                # uv and its tools, once the python pack is installed
~/.local/share/uv/           # the Python builds it downloaded, and their environments
~/.config/gcloud/            # The two GCP logins (gcp_auth_cli, gcp_auth_libs)
/etc/wsl.conf                # Default user, systemd (first_boot.sh)
```

---

## Continuous Integration

Two GitHub Actions workflows, in `.github/workflows/`:

| Workflow | Runs on | What it proves |
| :--- | :--- | :--- |
| `ci.yml` — Checks | every push, PRs onto `main` | shellcheck on the shell scripts, `zsh -n` on the configuration, the ASCII-only rule for the `.ps1` files, the makefile parses with a complete help menu, the docs and cheatsheets stay in sync with the `gmake` modules — and three suites on Windows drive the real code: the arrow menu with a scripted keyboard, the pack checklist, `build`'s questions over a stand-in docker |
| `image.yml` — Rootfs image build | every push, PRs onto `main`, weekly, manual | the Dockerfile still resolves end to end: apt repositories, download URLs, git clones |

They check the **repository** — the files, and the code run against stand-ins,
never a running distro — so none of them replaces a real `.\wsl.ps1 build` run.

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
| [`.\wsl.ps1 list`](docs/wsl/commands.md#list) | list our instances and the archives |
| [`.\wsl.ps1 build`](docs/wsl/commands.md#build) | build an instance from the image |
| [`.\wsl.ps1 start`](docs/wsl/commands.md#start) | start a stopped instance |
| [`.\wsl.ps1 stop`](docs/wsl/commands.md#stop) | stop a running instance |
| [`.\wsl.ps1 shell`](docs/wsl/commands.md#shell) | open a shell inside an instance |
| [`.\wsl.ps1 add_pack`](docs/wsl/commands.md#add_pack) | install a pack into an instance |
| [`.\wsl.ps1 remove_pack`](docs/wsl/commands.md#remove_pack) | uninstall a pack from an instance |
| [`.\wsl.ps1 manage_packs`](docs/wsl/commands.md#manage_packs) | choose the packs an instance should carry |
| [`.\wsl.ps1 unregister`](docs/wsl/commands.md#unregister) | remove an instance |
| [`.\wsl.ps1 archive`](docs/wsl/commands.md#archive) | write an instance to a named archive |
| [`.\wsl.ps1 restore`](docs/wsl/commands.md#restore) | rebuild an instance from an archive |
| [`.\wsl.ps1 duplicate`](docs/wsl/commands.md#duplicate) | copy an instance under another name |
| [`.\wsl.ps1 shrink`](docs/wsl/commands.md#shrink) | reclaim the space an instance has freed |

Each command, with its options, its examples and what it prints, is documented
in [**Instance commands**](docs/wsl/commands.md).

---

## License

MIT — see [LICENSE](LICENSE).
