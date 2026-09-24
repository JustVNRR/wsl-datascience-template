# Instance Administration

`wsl.ps1`, at the root of the repository, is the only thing to type. The
commands themselves live in `scripts\`.

```powershell
.\wsl.ps1               # list all available commands
```

```text
WSL DataScience template

  list         show the instances of this template, and the archives
  build        build an instance from the image (Docker, then WSL)
  adopt        mark an existing instance as one of this template's
  start        start a stopped instance
  stop         stop a running instance
  shell        open a shell in one of our instances
  unregister   remove an instance, and what it left on Windows
  archive      write an instance to a named archive
  restore      rebuild an instance from an archive
  duplicate    copy an instance under another name
  shrink       reclaim the space an instance has freed
```

## All commands

| Command | What it does |
| :--- | :--- |
| [`.\wsl.ps1 list`](#list) | show our instances, the archives, and what is left over |
| [`.\wsl.ps1 build`](#build) | build an instance from the image (Docker, then WSL) |
| [`.\wsl.ps1 adopt`](#adopt) | mark an instance that already exists as one of ours |
| [`.\wsl.ps1 start`](#start) | start a stopped instance |
| [`.\wsl.ps1 stop`](#stop) | stop a running instance |
| [`.\wsl.ps1 shell`](#shell) | open a shell in one of our instances |
| [`.\wsl.ps1 unregister`](#unregister) | remove an instance, and what it left on Windows |
| [`.\wsl.ps1 archive`](#archive) | write an instance to a named archive |
| [`.\wsl.ps1 restore`](#restore) | rebuild an instance from an archive |
| [`.\wsl.ps1 duplicate`](#duplicate) | copy an instance under another name |
| [`.\wsl.ps1 shrink`](#shrink) | reclaim the space an instance has freed |

## Which WSL instances are ours

Every instance created by `build`, `restore` or `duplicate` carries a
**marker**, named `.wsl-datascience-template`, in its own folder next to its
virtual disk:

```text
D:\WSL\ubuntu-template\
├── ext4.vhdx
├── terminal-icon.png
└── .wsl-datascience-template
```

## Where things live

One working folder, and nothing to decide: `D:\WSL` when the D: drive exists,
`%USERPROFILE%\WSL` otherwise.

```text
D:\WSL\
├── ubuntu-template\          an instance is a folder: its disk, its marker
├── template-bac\
└── archives\                 an archive is a folder too
    └── ubuntu-template\
        ├── ubuntu-template.tar.gz   the instance's file system
        ├── instance.json            its font, colours, and Docker state
        └── terminal-icon.png        its icon
```

---

## `list`

Lists all WSL instances carrying the `.wsl-datascience-template` marker.

```powershell
.\wsl.ps1 list
```

```text
Instances of this template:
   1.  template-bac       running       1.1 GB  D:\WSL\template-bac
   2.  ubuntu-template    stopped       2.4 GB  D:\WSL\ubuntu-template

Archives in D:\WSL\archives (most recent first):
      ubuntu-template            28.8 MB  2026-09-23 16:50
```

### Folders left behind by an unregistered instance

Removing an instance happens in two steps:

- Windows forgets the distribution.
- Then the folder and its multi-gigabyte disk are erased.

The second step sometimes fails. Windows no longer knows the instance, but the folder is still there, marker included, taking up room.

In that case `list` says it exists, what it weighs, and that it has to be deleted by hand:

```text
Folders left behind by an instance that is gone:
      vieux-test                        1.2 GB  D:\WSL\vieux-test
      No instance claims them, and no command removes them: delete them by hand.
```

---

## `build`

Builds a new instance from the rootfs image, walks you through the first-boot
onboarding (username, password, timezone), applies the Windows Terminal
profile, and opens a shell in it.

```powershell
.\wsl.ps1 build
```

It takes no options: it asks, twice.

```text
==> Creating a new instance
  Ctrl+C aborts at either question. Nothing is written before the build starts.
Name of the instance: ubuntu-ml-dev
Folder for 'ubuntu-ml-dev' [D:\WSL]:
```

The name is checked as it is typed (letters, digits, `.`, `_`, `-`), and Enter
takes the proposed folder — the one every other command writes to. Give
another path to put the disk on a second drive.

An answer that cannot be used comes back with the reason, and the question is
asked again:

- the folder is, or holds, the folder of another instance — erasing it would
  take that instance with it;
- the folder already exists and belongs to no instance of this template —
  delete it by hand, or give another name or folder.

Docker Desktop must be running: the script checks before asking anything.

If an instance already carries the name, the script shows a red warning and
asks you to **type the exact name** to confirm. Anything else aborts: the
rebuild erases that instance and everything in it.

---

## `adopt`

Marks an existing instance with the `.wsl-datascience-template` marker.

```powershell
.\wsl.ps1 adopt
```

```text
Registered instances that are not this template's:
   1.  distro                          1.2 GB  D:\WSL\distro
   2.  docker-desktop                  1.4 GB  D:\WSL\DockerDesktopWSL\main
   0.  Cancel
```

---

## `start`

Starts a stopped instance, without opening a shell in it.

```powershell
.\wsl.ps1 start
```

Only stopped instances are listed — an instance already running has nothing to
do here:

```text
Stopped instances - the ones that can be started:
   1.  template-bac                  1.1 GB
   2.  ubuntu-template               2.4 GB
   0.  Cancel
```

To work inside it, open its Windows Terminal profile — it is the profile the
build wrote, icon, font and colours included.

---

## `stop`

Stops a running instance.

```powershell
.\wsl.ps1 stop
```

Only running instances are listed:

```text
Running instances - the ones that can be stopped:
   1.  template-bac                  1.1 GB
   0.  Cancel
```

**Whatever is open in there and not saved is lost.** What is already written on
the disk stays exactly as it is — stopping ends the running processes, it does
not touch the disk. The script asks once before doing it, and the default is to
go ahead.

---

## `shell`

Opens a shell in one of our instances — the quickest way in when you are
already in a terminal.

```powershell
.\wsl.ps1 shell
```

The instance comes from the list, like everywhere else:

```text
Instances of this template:
   1.  template-bac       running       1.1 GB  D:\WSL\template-bac
   2.  ubuntu-template    stopped       2.4 GB  D:\WSL\ubuntu-template
   0.  Cancel
```

An instance that was stopped is started on the way in: `start` first is not
needed. The shell opens **in your home**, not in the Windows folder you ran the
command from — the same thing the build does when a new instance is ready.

`exit` in there brings you back to PowerShell.

---

## `unregister`

Removes an instance and everything it left on Windows.

```powershell
.\wsl.ps1 unregister
```

This is the only command that deletes without rebuilding, and it asks twice:

1. It lists the instances and you pick one.
2. It shows the red warning and asks you to **type the exact name**. An empty
   answer aborts, and picking from the list does not replace the typing.
3. It then offers `Archive it before deleting? [y/N]` — default no. Answering
   yes calls `archive` first, and **if the archive fails, nothing is deleted**.
4. It unregisters the distribution, then cleans up what it left behind: the
   installation folder, orphaned Windows Terminal profiles, this repository's
   appearance fragment, and its entry in Docker Desktop's list of integrated
   distros.

### What an instance takes with it

The virtual disk is deleted, so **nothing inside the instance survives**. A
rebuild destroys it the same way. Before either:

| Kept inside the instance | Before you unregister or rebuild |
| :--- | :--- |
| `~/projects/` | Nothing backs it up — push your work to a remote first |
| `~/.ssh/` | A key generated inside cannot be recovered: copy it out, or plan to revoke and regenerate it |
| `~/.config/gcloud/` | Both logins are redoable in minutes ([GCP onboarding](../optional_tooling/gcp_onboarding.md)) |
| `~/.config/zsh/gmake/.env.global` | A handful of lines; `gmake gcp_install`, then `gmake gcp_enable_global_env`, recreate the file |
| `~/.config/zsh/cheatsheets/templates.tsv` | Only for rows you added inside the instance: the file is redeployed at build time — move the line into `zsh/` to keep it |

`archive` is the way out: it writes the whole file system to a folder you can
restore from later.

---

## `archive`

Writes an instance to an archive: the file system, **plus what a tar cannot
carry** — the icon, the font and the colour scheme the instance was using, and
whether Docker Desktop knew it.

```powershell
.\wsl.ps1 archive
.\wsl.ps1 archive -Format tar.xz
```

| Option | Default | What it does |
| :--- | :--- | :--- |
| `-Format` | `tar.gz` | `tar`, `tar.gz` or `tar.xz` (`xz` compresses harder, and takes longer) |
| `-AfterExport` | `Ask` | what to do with the instance once the archive is written: `Ask`, `Start`, `Delete`, `Leave` |

If the instance is running, it has to be stopped for the export to read a
consistent disk — the script warns you first, because whatever is open and
unsaved goes with it.

It then shows the archives already taken and proposes the instance's own name:

```text
Archives already in D:\WSL\archives:
  ubuntu-template                    28.8 MB  2026-09-22 09:12

Name of the archive? [ubuntu-template]
```

Press Enter to accept it. If that name is taken, the proposal becomes
`ubuntu-template-1`, then `-2`, until one is free — so archives do not
accumulate under a name you did not choose. Typing the name of an existing
archive replaces it, and the script says so before doing it.

Once the archive is written, it asks what should happen to the instance:

```text
What should happen to 'ubuntu-template' now?
  a. Start it
  b. Delete it (the archive stays)
  c. Leave it stopped
```

The default is the state it was found in. Answering **b** goes through
`unregister`, so the exact name has to be typed again — the archive is what
remains.

---

## `restore`

Rebuilds an instance from an archive.

```powershell
.\wsl.ps1 restore
```

It lists the archives, most recent first, and you pick one:

```text
Archives in D:\WSL\archives (most recent first):
   1.  ubuntu-template  -  28.8 MB, 2026-09-23 16:50
   2.  template-bac     -  31.4 MB, 2026-09-22 09:12
   0.  Cancel
```

It then asks for the name of the new instance and imports it into
`D:\WSL\<name>`. If an instance already carries that name, it stops and tells
you the command to run first — **it deletes nothing on its own**.

The icon, the font, the colour scheme and Docker Desktop's knowledge of the
instance come back with it, from the values stored next to the tar. If the font
is no longer installed on Windows, the script says so rather than failing.

**The archive is kept**: restoring copies it into a new instance, it does not
consume it.

---

## `duplicate`

Copies an instance under another name, leaving the original alone.

```powershell
.\wsl.ps1 duplicate
```

The source comes from the list, and the copy's name is typed — it is the one
name that cannot be picked, because nothing exists under it yet. A name already
taken is refused: this command never unregisters anything, so a busy name is a
dead end rather than a problem to solve.

If the source is running, it has to be stopped for the copy — the script asks
first, and starts it again afterwards when it was the one that stopped it.

The copy lands in `D:\WSL\<name>` and comes out dressed like its source, icon,
font and colours included. It needs **twice the disk's size** free at peak: the
temporary archive and the copy exist at the same time. The script checks and
shows the numbers before starting.

> A copy is made by reading the instance into an archive and unpacking it, not
> by copying the virtual disk — a raw disk copy is refused while WSL is up.

---

## `shrink`

Gives back to Windows the space the instance has freed inside itself.

```powershell
.\wsl.ps1 shrink
```

Space is only added to a virtual disk, never returned on its own: a 60 GB file
deleted inside the instance stays occupied on the Windows side. Compacting the
disk is what returns it. Nothing inside the instance is touched, and the disk's
virtual size does not change — only what it occupies on Windows.

It first asks `Archive it first? [Y/n]`, default yes. Answering no compacts
directly; answering yes takes an archive named after the instance (replacing an
older one of the same name, so archives do not pile up), and **if the archive
fails, nothing is compacted**.

It works on a running instance as well as a stopped one, and leaves it in the
state it was found in.

