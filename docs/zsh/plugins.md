# Oh My Zsh Plugins

[← Back to the README](../../README.md#shell-environment-zsh)

Oh My Zsh drives the shell, with Starship handling the prompt (its visual
configuration lives in `prompts/starship.toml`). The plugins below are cloned
into the user skeleton at build time.

| Plugin | Role |
| :--- | :--- |
| `git` | Git aliases and completion hooks |
| `common-aliases` | High-frequency shortcuts for common Unix commands |
| `history-substring-search` | Type any string, then navigate matching historical commands with the arrow keys |
| `fzf` | Official fuzzy completion engine bindings |
| `ssh-agent` | Quiet, lazy-loading SSH identity manager |
| `last-working-dir` (`lwd`) | Restores your last active directory when opening a new shell |
| `direnv` / `docker` / `docker-compose` | Autocompletion and integration for environment and container management |
| `zsh-autosuggestions` | Fish-like history autosuggestions |
| `zsh-syntax-highlighting` | Fish-like syntax highlighting, live on the command line |

Ordering matters: `zsh-autosuggestions` and `zsh-syntax-highlighting` load
last, and `ssh-agent` runs quiet and lazy so it never slows down shell
startup. The full plugin list lives in `~/.config/zsh/.zshrc`.
