# Keybindings (ZLE)

[← Back to the README](../../README.md#shell-environment-zsh)

Custom ZLE widgets bound to ergonomic combinations. Defined in
`~/.config/zsh/bindings.zsh`.

### VS Code integrations (host interop)

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Alt + O` | Fuzzy-open visible file | Interactively search visible files and open the selected item in VS Code |
| `Alt + A` | Fuzzy-open any file | Interactively search all files (including hidden/dotfiles) and open in VS Code |
| `Alt + Shift + C` | Open Zsh config | Directly open `$ZDOTDIR` (`~/.config/zsh`) in VS Code |
| `Alt + R` | Open history file | Directly open the persistent `$HISTFILE` in VS Code |

### Prompt buffer insertions

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Ctrl + F` | Insert file path | Fuzzy-find a file path and insert it at the current cursor position (`LBUFFER`) |
| `Ctrl + A` | Insert alias (`falias`) | Interactively pick an alias from a fuzzy menu and insert it into the prompt |
| `Ctrl + H` | Insert cheatsheet (`fcheat`) | Search and inject a saved cheatsheet command |

The fuzzy pickers behind these bindings are documented in
[Interactive tools](interactive.md).
