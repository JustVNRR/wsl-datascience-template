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

Two folders are scanned every time the picker opens: the socle's
`cheatsheets/`, and each installed pack's own. Add, edit or remove files there
to curate your own command menu; a pack that leaves takes its sheets with it.

### The shell follows the packs too

A pack may bring shell files (`zsh/*.zsh`) — `fnew` comes with the `python`
pack's. They are read where they live, and the list is looked at again before
every prompt, the way the picker asks its question at every opening. Install a
pack from Windows while a shell is open and the next prompt says so and
restarts the shell; remove one and the next prompt does the same, which is the
only way its commands can stop existing.

So one command is all it takes — and the shell right after a change is the
first one that sees it: the restart happens at a prompt boundary, which is why
the command that noticed the change is the last one the old shell runs.

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

`fnew` — the interactive project scaffolding picker — comes with the `python`
pack: see [Project scaffolding](../../packs/python/docs/project-setup.md).
