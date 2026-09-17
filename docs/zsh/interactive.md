# Interactive Tools (fzf)

[← Back to the README](../../README.md#shell-environment-zsh)

The fzf-powered layer: pickers for files, directories, branches, commands,
and aliases — plus a smart archive extractor.

### Navigation & files

| Command | Action |
| :--- | :--- |
| `cdv` | Fuzzy `cd` into a visible directory |
| `cda` | Fuzzy `cd` anywhere, hidden directories included (`.git` excluded) |
| `fv` | Fuzzy-find a visible file and open it in VS Code (also `Alt + O`) |
| `fa` | Same for all files, hidden included (also `Alt + A`) |

### Git

| Command | Action |
| :--- | :--- |
| `fb` | Fuzzy checkout of a local branch, with a commit log preview |
| `fgl` | Browse the commit log fuzzily, previewing each commit |

### Cheatsheets & aliases

| Command | Action |
| :--- | :--- |
| `fcheat` | Fuzzy-search the `cheatsheets/*.sh` command lists and load a command into the prompt (also `Ctrl + H`) |
| `falias` | Fuzzy-search your aliases and load one into the prompt (also `Ctrl + G`) |

The `cheatsheets/` directory is scanned at every shell startup: add, edit,
or remove files there to curate your own command menu.

### Archives

`extract` unpacks any common archive (zip, tar.\*, gz, bz2, xz, 7z, rar…)
into a directory of your choice — the destination is pre-filled from the
archive name and editable in place, and you are asked whether to delete the
original archive afterwards. Run it bare to fuzzy-pick an archive in the
current tree.

### Scaffolding

`fnew` — the interactive project scaffolding picker — lives with the
Makefile workflow: see [Project scaffolding](../make/project-setup.md).
