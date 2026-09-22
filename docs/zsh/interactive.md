# Interactive Tools (fzf)

[← Back to the README](../../README.md#shell-environment-zsh)

The fzf-powered layer: pickers for files, directories, branches, commands,
and aliases — plus a smart archive extractor.

### Navigation & files

| Command | Action |
| :--- | :--- |
| `cdv` | Fuzzy `cd` into a visible directory |
| `cda` | Fuzzy `cd` anywhere, hidden directories included (`.git` excluded) |
| `fv` | Fuzzy-find a visible file and open it in VS Code (also `Alt + o`) |
| `fa` | Same for all files, hidden included (also `Alt + a`) |

### Git

| Command | Action |
| :--- | :--- |
| `fb` | Fuzzy checkout of a local branch, with a commit log preview |
| `fgl` | Browse the commit log fuzzily, previewing each commit |

### Cheatsheets & aliases

| Command | Action |
| :--- | :--- |
| `fcheat` | Fuzzy-search the `cheatsheets/*.sh` command lists and load a command into the prompt (also `Alt + z`) |
| `falias` | Fuzzy-search your aliases and load one into the prompt (also `Alt + y`) |

The `cheatsheets/` directory is scanned every time the picker opens: add, edit,
or remove files there to curate your own command menu.

A sheet can declare what it needs, in a comment on a line of its own:

```text
# requires: gcloud
```

The picker then leaves that file out when `gcloud` is absent. `# requires:
!gcloud` does the reverse — for a sheet that only makes sense while the tool is
*missing*, typically the one holding the command that installs it. Nothing is
recorded: the question is asked again at every `Alt + z`, so installing the
tool by any means is enough.

### Archives

`extract` unpacks any common archive (zip, tar.\*, gz, bz2, xz, zst, 7z, rar…)
into a directory of your choice — the destination is pre-filled from the
archive name and editable in place, and you are asked whether to delete the
original archive afterwards. Run it bare to fuzzy-pick an archive in the
current tree.

### Scaffolding

`fnew` — the interactive project scaffolding picker — lives with the
Makefile workflow: see [Project scaffolding](../make/project-setup.md).
