# Ubuntu WSL Data Science Template

An automated workflow to build and import lightweight, reproducible, and pre-configured Ubuntu 24.04 instances into WSL2 using Docker and PowerShell. Heavily optimized for Data Science, Python development, modern CLI tools, and seamless Google Cloud Platform (GCP) integration.

## Features

- **Base OS:** Ubuntu 24.04 LTS (purged default `ubuntu` user, UID 1000 assigned to your user).
- **Data Science Ready:** Pre-configured with `uv` (fast Python manager), and all necessary C/C++ build dependencies (`llvm`, `build-essential`, `libssl-dev`, etc.) to compile Cython and wheels flawlessly.
- **Node.js Integration:** Includes `nvm` with lazy-loading and automatic `.nvmrc` version switching to keep shell startup instantaneous.
- **Shell & Prompt:** Zsh powered by Oh-My-Zsh and Starship prompt with full XDG compliance (`$ZDOTDIR` located in `~/.config/zsh`).
- **Modern CLI Stack:** Rust-based replacements (`eza`, `bat`, `fzf`, `fd-find`, `zoxide`, `ripgrep`, `tealdeer`) with dynamic fallback to standard POSIX tools.
- **First-Boot Wizard:** Automatic interactive setup on first launch (user creation, password definition, `sudo` access, timezone configuration, auto-generated `/etc/wsl.conf` with **Systemd enabled**, and pre-fetching of the latest Python release and dev tools (`copier`, `cruft`, `ruff`)).
- **Workspace Skeleton:** A `~/projects` directory is provisioned for every new user via `/etc/skel`, ready to host scaffolded projects.
- **Interoperability:** Native Windows PATH integration preserved (Docker Desktop, VS Code CLI `code`, `explorer.exe`).
- **Clean Skeletons:** `/etc/skel` permissions strictly set (`root:root`) with automatic removal of lingering `.zcompdump` caches.

---

## Bundled Software & Stack

### Core System & CLI Utilities
- **Core:** `zsh`, `sudo`, `adduser`, `ca-certificates`, `curl`, `wget`, `openssh-client`, `tzdata`, `nano`, `tree`, `strace`, `tar`, `unzip`, `gzip`, `xz-utils`, `zstd`.
- **Search & Navigation:** `fzf` (fuzzy search), `fd-find` (linked to `fd`), `zoxide` (directory hopping), `ripgrep` (ultra-fast grep).
- **Inspection & Display:** `eza` (modern `ls` replacement), `batcat` (syntax highlighting, linked to `bat`), `jq` (JSON processor).
- **DevOps & Cloud:** `gh` (GitHub CLI), `direnv`, `shellcheck`, `google-cloud-sdk`, `sqlite3`.

### Python & Data Science
- **Managers:** `uv` (Astral's fast Python package manager).
- **Build Libraries:** `build-essential`, `llvm`, `make`, `python3-dev`, `libssl-dev`, `zlib1g-dev`, `libbz2-dev`, `libreadline-dev`, `libsqlite3-dev`, `tk-dev`, `libffi-dev`, `liblzma-dev`.
- **Computer Vision & OCR:** `ffmpeg`, `imagemagick`, `tesseract-ocr`, `libtesseract-dev`.

### Oh My Zsh Plugins
- **`git`:** Git aliases and completion hooks.
- **`common-aliases`:** High-frequency shortcuts for common Unix commands.
- **`history-substring-search`:** Type any string and navigate matching historical commands via arrow keys.
- **`fzf`:** Official fuzzy completion engine bindings.
- **`ssh-agent`:** Quiet, lazy-loading SSH identity manager.
- **`last-working-dir` (`lwd`):** Automatically restores your last active directory upon opening a new shell.
- **`direnv` / `docker` / `docker-compose`:** Autocompletion and integration for environment and container management.
- **`zsh-autosuggestions`:** Fish-like history autosuggestions.
- **`zsh-syntax-highlighting`:** Fast Fish-like syntax highlighting directly on the command line.

---

## MLOps Global Makefile (`gmake`)

The environment ships with a highly modular, global Makefile designed for Data Science and GCP workflows, accessible from anywhere via the `gmake` alias.

- **`.env.global` Cascading Configuration:** The global workflow relies on a cascading environment variable pattern. It first loads `.env.global` (the configuration contract containing empty or safe default values). If a local `.env` file exists in your current working directory, it will automatically override the global values for that specific project.
- **`gmake` vs `make`:** 
  - Type `gmake` (without any arguments) anywhere to display a beautifully formatted help menu listing all available global targets (GCP compute, BigQuery, Docker, Cloud Run, etc.).
  - Use `gmake <target>` to run the global MLOps tasks.
  - Use `make <target>` to run tasks from a local `Makefile` specific to your current project folder.

The makefile is split into one module per domain under `cheatsheets/make/`, each documented in [`docs/make/`](docs/make/) — indexed below along a project's lifecycle:

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

## Keybindings (ZLE Keyboard Shortcuts)

The environment comes with custom ZLE widgets bound to ergonomic keyboard combinations:

### VS Code Integrations (Host Interop)
| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Alt + o` | Fuzzy-open visible file | Interactively search visible files and open the selected item in VS Code |
| `Alt + a` | Fuzzy-open any file | Interactively search all files (including hidden/dotfiles) and open in VS Code |
| `Alt + Shift + C` | Open Zsh Config | Directly open `$ZDOTDIR` (`~/.config/zsh`) in VS Code |
| `Alt + r` | Open History File | Directly open the persistent `$HISTFILE` in VS Code |

### Prompt Buffer Insertions & Helpers
| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Ctrl + F` | Insert file path | Fuzzy-find a file path and insert it at the current cursor position (`LBUFFER`) |
| `Ctrl + A` | Insert alias (`falias`) | Interactively pick an alias from a fuzzy menu and insert it into the prompt |
| `Ctrl + H` | Insert cheatsheet (`fcheat`) | Search and inject a saved cheatsheet command. |

**Note:**

- At every Zsh startup, the `cheatsheets/` directory is scanned.
- You can add, edit, or remove files in this folder to dynamically customize the commands available in the menu.

---

## Custom Aliases & Functions

### System & Navigation
- `b`: Go back to previous directory (`cd -`).
- `ports`: Show active listening network sockets (`sudo lsof -i -P -n | grep LISTEN`).
- `reload`: Re-source the primary configuration (`source ~/.config/zsh/.zshrc`).
- `zsh_conf`: Open configuration directory in VS Code (`code ~/.config/zsh`).

### Modern Utilities
- `ls`: Aliased to `eza --icons` (with graceful fallback).
- `ll`: Aliased to `eza -lh --icons --git`.
- `la`: Aliased to `eza -lah --icons --git`.
- `tree`: Aliased to `eza --tree --icons`.
- `cat`: Aliased to `bat` (syntax-highlighted output).
- `grep`: Aliased to `rg --color=auto`.

### Interactive Tools
- `falias`: Interactive alias search using `fzf`. Shows alias definitions with inline formatting and loads selection directly into the prompt buffer.
- `fnew`: Interactive project scaffolding. Fuzzy-pick a template from the catalog (`cheatsheets/templates.tsv`), name your project, and let the global Makefile bootstrap it.

---

## Prerequisites

- Windows 10/11 with **WSL2** installed and enabled.
- **Docker Desktop** (or Docker Engine running via WSL).
- PowerShell 5.1+ or PowerShell 7+.

---

## Project Structure

```text
├── .config/zsh/
│   ├── .zshrc               # Main orchestrator (loads OMZ, modules, prompts)
│   ├── aliases.zsh          # Custom shortcuts and interactive falias picker
│   ├── bindings.zsh         # ZLE widgets and keybindings
│   ├── cheatsheet.zsh       # Interactive cheatsheet selector (fcheat)
│   ├── cheatsheets/         # Auto-scanned directory for CTRL+H and global Makefile
│   │   ├── .env.global      # Global fallback environment variables for MLOps
│   │   ├── *_commands.sh    # Domain-specific command lists (git, docker, bash, etc.)
│   │   ├── templates.tsv    # Curated project template catalog (fnew picker)
│   │   ├── global_makefile.mk # Global entrypoint for the MLOps Makefile
│   │   └── make/            # Modular Makefile rules (gcp, bigquery, cloud_run, lint, etc.)
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
├── Dockerfile               # Rootfs build recipe with Ubuntu 24.04 and DS stack
├── first_boot.sh            # User creation, Systemd, sudo access, Python setup
├── build.ps1                # PowerShell build, export, safety checks, and import script
├── docs/
│   └── make/                # Per-module documentation for the global Makefile
├── .gitattributes           # Enforces strict LF line endings for shell scripts
├── .gitignore               # Prevents committing build artifacts (*.tar, *.vhdx)
└── README.md
```

---

## Quick Start

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

3. **Complete onboarding:**
   During build execution, the script will prompt you for your preferred username and timezone. The setup wizard will automatically add you to the `sudo` group, configure `systemd`, and fetch the latest Python release via `uv`.

4. **Configure your Windows Terminal profile appearance:**
   The prompt (Starship) and file listings (`eza`) render icons, glyphs, and colors that Windows Terminal cannot display with its default settings. Close and reopen Windows Terminal first — a freshly imported distro only appears in the settings profile list after a restart. Then open the settings (`Ctrl + ,`), select your distro's profile, and adjust:

   - **Font face — Nerd Font (required):** icons come from a [Nerd Font](https://www.nerdfonts.com/), a font patched with thousands of icons and symbols. The build script has already installed **MesloLGS NF** for the current Windows user (no admin rights needed) — just select it under **Appearance → Font face**. Any other Nerd Font from the site works too. Without one, every icon shows as a missing-glyph box (`□`).
   - **Color scheme (your choice):** Starship and `eza` emit named ANSI colors, and the scheme decides which RGB values they map to — dark or light, any well-designed scheme works, the prompt simply follows the terminal palette. The only pitfall is on light backgrounds, where some mappings (e.g. yellow or white) can look washed out — under **Appearance → Color scheme**, pick one whose 16 colors contrast well with its background.
   - **Profile icon (optional):** the **Icon** field on the profile's main settings page accepts a path to any local image (`.png`, `.ico`) — handy to tell your distro apart in the tab bar, with the Ubuntu logo for instance.

5. **Launch your session:**
   Once the script finishes and cleans up temporary build archives, launch your environment:
   ```powershell
   wsl -d <DistroName>
   ```

---

## Maintenance & Removal

To completely delete and unregister an instance (warning: this permanently deletes all data inside the instance):
```powershell
wsl --unregister <DistroName>
```