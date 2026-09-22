# Keybindings (ZLE)

[← Back to the README](../../README.md#shell-environment-zsh)

Custom ZLE widgets bound to ergonomic combinations. Defined in
`~/.config/zsh/bindings.zsh`.

### VS Code integrations (host interop)

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Alt + o` | Fuzzy-open visible file | Interactively search visible files and open the selected item in VS Code |
| `Alt + a` | Fuzzy-open any file | Interactively search all files (including hidden/dotfiles) and open in VS Code |
| `Alt + r` | Open history file | Directly open the persistent `$HISTFILE` in VS Code |
| `Ctrl + X` then `v` | Open Zsh config | Directly open `$ZDOTDIR` (`~/.config/zsh`) in VS Code |

### Prompt buffer

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `Ctrl + X` then `g` | Insert file path | Fuzzy-find a file path and insert it at the current cursor position (`LBUFFER`) |
| `Alt + y` | Insert alias (`falias`) | Interactively pick an alias from a fuzzy menu and insert it into the prompt |
| `Alt + z` | Replace the line (`fcheat`) | Search a saved cheatsheet and replace the whole line with the chosen command |

`Ctrl + X` then `g` is a sequence, not a combination: press Ctrl+X, release,
then press the second key. zsh waits for it (the `KEYTIMEOUT` delay, 0.4 s by
default).

These bindings are the ones zsh was not using, or was using for something
rare. What each one took is written in the comments of
`~/.config/zsh/bindings.zsh`.

The fuzzy pickers behind these bindings are documented in
[Interactive tools](interactive.md).
