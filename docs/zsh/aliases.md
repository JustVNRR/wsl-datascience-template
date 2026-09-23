# Aliases

[← Back to the README](../../README.md#shell-environment-zsh)

Defined in `~/.config/zsh/aliases.zsh`, on top of Oh My Zsh's own `git` and
`common-aliases` plugins.

### System & Navigation

| Alias | Runs | Description |
| :--- | :--- | :--- |
| `b` | `cd -` | Go back to the previous directory |
| `ports` | `sudo lsof -i -P -n \| grep LISTEN` | Show active listening network sockets |
| `reload` | `exec zsh` | Restart the shell, picking up configuration changes |
| `zsh_conf` | `code ~/.config/zsh` | Open the configuration directory in VS Code |

### Modern Utilities

| Alias | Runs |
| :--- | :--- |
| `ls` | `eza --icons=always` |
| `ll` | `eza -lh --icons=always --git` |
| `la` | `eza -lah --icons=always --git` |
| `tree` | `eza --tree --icons=always` |
| `cat` | `batcat` (syntax-highlighted output) |
| `grep` | `grep --color=auto` |

Each alias is only set when its underlying tool is installed.

Interactive commands like `falias` and `fnew` are documented in
[Interactive tools](interactive.md).
