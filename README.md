# Ubuntu WSL Data Science Template

An automated workflow to build and import lightweight, reproducible, and pre-configured Ubuntu 24.04 instances into WSL2 using Docker and PowerShell. Heavily optimized for Data Science, Python development, modern CLI tools, and seamless Google Cloud Platform (GCP) integration.

## Features

- **Base OS:** Ubuntu 24.04 LTS (purged default `ubuntu` user, UID 1000 assigned to your user).
- **Data Science Ready:** Pre-configured with `uv` (fast Python manager), and all necessary C/C++ build dependencies (`llvm`, `build-essential`, `libssl-dev`, etc.) to compile Cython and wheels flawlessly.
- **Node.js Integration:** Includes `nvm` with lazy-loading and automatic `.nvmrc` version switching to keep shell startup instantaneous.
- **Shell & Prompt:** Zsh powered by Oh-My-Zsh and Starship prompt with full XDG compliance (`$ZDOTDIR` located in `~/.config/zsh`).
- **Modern CLI Stack:** Rust-based replacements (`eza`, `bat`, `fzf`, `fd-find`, `zoxide`, `ripgrep`, `tealdeer`) with dynamic fallback to standard POSIX tools.
- **First-Boot Wizard:** Automatic interactive setup on first launch (user creation, password definition, passwordless `sudo` access, timezone configuration, auto-generated `/etc/wsl.conf` with **Systemd enabled**, and pre-fetching of the latest Python release and dev tools (`copier`, `cruft`, `ruff`)).
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

### Lint

- `gmake lint`: run all checks (Python + shell), non-destructive. Launched without a scope it asks for confirmation — once, even though it chains both checks.
- `gmake lint-py` / `gmake lint-sh`: single-domain check (`PY_TARGETS` / `SH_TARGETS` to scope), same confirmation when launched bare.
- `gmake lint-format`: auto-fix and format Python code.
- `ruff` (installed at first boot via `uv tool`) and `shellcheck` (bundled in the image) — lint rules live in each project's `pyproject.toml`, only the tool lives on the machine.

### Tests

- `gmake test`: run the whole test suite.
- `gmake test-fast`: fast lane only, no external infrastructure (the CI lane).
- `gmake test-functional`: tests that need real local infrastructure (`.env`, Docker, a trained model...).
- `gmake test-gcp`: tests that hit a real GCP environment (test/staging/prod).
- The lanes rely on a marker convention (`functional`, `gcp`) declared in each project's `pyproject.toml` (`[tool.pytest.ini_options] markers`); unmarked tests run in every lane, so projects without the convention work out of the box. Unlike ruff, `pytest` lives in each project's virtual environment (`uv add --dev pytest`) since it must import the project's code and plugins.

### Template Catalog (`fnew`)

- Project templates are centralized in `cheatsheets/templates.tsv`: one per line (`url`, `tool`, `version`, `description`, tab-separated). The optional `version` column pins a template ref (e.g. `v1`), passed as `--vcs-ref` (Copier) or `--checkout` (Cruft) — useful when a template's default branch targets a different tool.
- Type `fnew` anywhere to fuzzy-pick a template from the catalog, enter your project name, and scaffold it. `fnew` delegates to the `copier_project` / `cruft_project` global targets (virtual environment + direnv bootstrap included, auto-detecting uv-native and requirements.txt projects). The destination directory is always displayed and must be confirmed when you are outside `~/projects`.
- The catalog is re-scanned on every `fnew` call: add, edit, or remove lines to curate your own shortlist.

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
│   │   └── make/            # Modular Makefile rules (gcp, biquerry, cloud_run, lint, etc.)
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
├── first_boot.sh            # User creation, Systemd, passwordless sudo, Python setup
├── build.ps1                # PowerShell build, export, safety checks, and import script
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
   During build execution, the script will prompt you for your preferred username and timezone. The setup wizard will automatically assign passwordless `sudo`, configure `systemd`, and fetch the latest Python release via `uv`.

4. **Launch your session:**
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