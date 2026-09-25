# Instance Administration

`wsl.ps1`, at the root of the repository, is the only thing to type. The
commands themselves live in `scripts\`.

```powershell
.\wsl.ps1               # which command? - the menu below
```

```text
  (a command can also be typed:  .\wsl.ps1 <command> [options])

WSL DataScience template
  > list         list our instances and the archives
    build        build an instance from the image
    adopt        mark an existing instance as ours
    start        start a stopped instance
    stop         stop a running instance
    shell        open a shell inside an instance
    add_pack     install a pack into an instance
    remove_pack  uninstall a pack from an instance
    manage_packs choose the packs an instance should carry
    unregister   remove an instance
    archive      write an instance to a named archive
    restore      rebuild an instance from an archive
    duplicate    copy an instance under another name
    shrink       reclaim the space an instance has freed
  up/down to move, Enter to choose, Escape to cancel
```

It is the same menu every command shows when it asks something - the
instances, the packs, the archives - and it is answered the same way. Where
there is no console to read a key from (a script, a pipe), that menu becomes
the numbered prompt it used to be, and the answer is typed.

## All commands

| Command | What it does |
| :--- | :--- |
| [`.\wsl.ps1 list`](#list) | list our instances and the archives |
| [`.\wsl.ps1 build`](#build) | build an instance from the image |
| [`.\wsl.ps1 adopt`](#adopt) | mark an existing instance as ours |
| [`.\wsl.ps1 start`](#start) | start a stopped instance |
| [`.\wsl.ps1 stop`](#stop) | stop a running instance |
| [`.\wsl.ps1 shell`](#shell) | open a shell inside an instance |
| [`.\wsl.ps1 add_pack`](#add_pack) | install a pack into an instance |
| [`.\wsl.ps1 remove_pack`](#remove_pack) | uninstall a pack from an instance |
| [`.\wsl.ps1 manage_packs`](#manage_packs) | choose the packs an instance should carry |
| [`.\wsl.ps1 unregister`](#unregister) | remove an instance |
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

It takes no options: it asks for the name, for the folder, and — when this
checkout carries packs — which of them the instance should start with.

```text
==> Creating a new instance
Name of the instance (CTRL+C to abort): ubuntu-ml-dev
Create [D:\WSL\ubuntu-ml-dev]? [Y/n]
```

The name is checked as it is typed (letters, digits, `.`, `_`, `-`). The
location is then shown and confirmed — Enter accepts it, and it is the folder
every other command writes to. Answer `n` to put the disk somewhere else: the
folder question follows, and the path that comes out of it is shown and
confirmed in turn.

An answer that cannot be used comes back with the reason, and the question is
asked again:

- the folder is, or holds, the folder of another instance — erasing it would
  take that instance with it;
- the folder already exists — choose another location.

Docker Desktop must be running: the script checks before asking anything.

If an instance already carries the name, the script shows a red warning and
asks you to **type the exact name** to confirm. Anything else aborts: the
rebuild erases that instance and everything in it.

The packs are the last question, asked before anything is created:

```text
Packs for 'ubuntu-ml-dev'
  > [ ] gcp          The Google Cloud CLI (about 409 MB installed)
    [ ] vision       ffmpeg, ImageMagick and Tesseract OCR (about 500 MB)
  up/down to move, space to check, Enter to apply, Escape to cancel
```

Escape, or an empty checklist, is a real answer: no pack, and the build goes on.
A rebuild arrives with the boxes ticked for what the instance being replaced
carries, so its packs come back without being chosen again. What is ticked is
summarised and confirmed as in `manage_packs` — one question for the whole list.

They are installed **once the instance exists**, after the deployment and never
inside it. One whose installation fails does not fail the build: the instance is
built, the pack's files are taken back out, and the report on the screen names it
and points at `.\wsl.ps1 manage_packs` to finish.

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

## `add_pack`

Installs a pack into an instance: the tool itself (its packages and its APT
repository) and the pack's files — its gmake targets, its cheatsheets, its
environment samples.

```powershell
.\wsl.ps1 add_pack
```

Two lists, then it installs:

```text
Instances of this template:
   1.  template-bac       running       1.1 GB  D:\WSL\template-bac
   2.  ubuntu-template    stopped       2.4 GB  D:\WSL\ubuntu-template
   0.  Cancel
Which one? (0 to cancel) 2

Packs available for 'ubuntu-template':
   1.  gcp           The Google Cloud CLI (about 409 MB installed)
   0.  Cancel
       Already there: python
Which one? (0 to cancel) 1

==> Installing 'gcp' in 'ubuntu-template'...
    Your password may be asked: the packages belong to root.
```

Only the packs the instance does not have yet are offered. The packs are the
folders under `packs\`: a folder carrying a `pack.conf` is a pack.

**It asks for your password.** The packages and the APT address belong to root;
the pack's `install.sh` runs as you inside the instance and takes `sudo` where
it needs to. The prompt appears in this window, in the middle of the
installation.

Nothing has to be reopened afterwards: `gmake` reads the pack's files at every
run, and `fcheat` re-reads its cheatsheets at every opening.

One step is left for you, and the command names it at the end: `gmake
env_global_enable`, inside the instance, merges the pack's environment samples
into your `.env.global`. Nothing writes into that file on your behalf — it is
yours, and so is the project's `.env`.

If the installation fails, the pack's files are removed and the script says so.
What the install had already put in place stays; running `add_pack` again picks
up where it stopped.

---

## `remove_pack`

The reverse: the pack's own `remove.sh` runs first — the tool and its APT
repository leave the system — then its folder leaves the instance.

```powershell
.\wsl.ps1 remove_pack
```

```text
Packs installed in 'ubuntu-template':
   1.  gcp
   0.  Cancel
Which one? (0 to cancel) 1

==> Removing 'gcp' from 'ubuntu-template'...
    Its own remove.sh runs first - what it installed leaves the system.
    Then its folder leaves, and the gmake menu loses its commands.
Remove 'gcp'? [y/N] y
```

The list comes from the instance, not from this repository: a pack installed by
an older copy is still removable, because its `remove.sh` travelled with it.

Your password is asked here too. What the pack left in your files is not
touched: your `gcloud` logins, the variables it copied into `.env.global`.

A pack installed before packs carried a `remove.sh` is a special case: the
command says so, and deleting its files undoes nothing on the system side.

### What it takes back after the pack is gone

A `remove.sh` names what it installed — `ffmpeg`, the Google CLI — and takes
those away. What arrived with them as *dependencies* is nobody's to name, and it
is the bulk of the weight: the vision pack leaves **203 packages and 462 MB**
behind, measured. So the command asks one more question, and removes only if
both answers come back empty:

| Question | Who answers |
| :--- | :--- |
| Does any installed package depend on it? | apt — the automatic packages no installed package needs any more |
| Does anything **outside apt** link its libraries? | `ldd` over `~/.local`, `~/projects`, `/usr/local` and `/opt`, each library traced to its package with `dpkg -S` |

A program apt knows nothing about — a venv, a binary you built — stops the
cleanup, and the command names it:

```text
==> Taking back what 'vision' left on the system side...
    Kept in place: something outside apt still links what would go.

    /usr/local/bin/mytool links libtesseract5, liblept5, libtiff6
    Remove the package by hand if that program is gone.
```

When nothing answers yes, it goes — `46 dependencies nothing needs any more:
78 MB`.

This is the one place the repository runs `autoremove`, and it never runs it
blind: a package kept by mistake costs every user of the instance, a package
removed one step too early costs one `apt-get install` to whoever needs it
later.

---

## `manage_packs`

Several packs at once. The list shows every pack this repository carries, the
ones the instance already has arrive checked, and what comes back is applied:
the missing ones installed, the unchecked ones taken out.

```powershell
.\wsl.ps1 manage_packs
```

```text
Packs for 'new_distro2'
  > [x] gcp          The Google Cloud CLI (about 409 MB installed)
    [ ] vision       ffmpeg, ImageMagick and Tesseract OCR (about 500 MB)
  up/down to move, space to check, Enter to apply, Escape to cancel
```

Space checks and unchecks, Enter applies, Escape cancels. Each list gets a line
when it has something in it, and one question covers them both:

```text
Will install : vision
Will remove  : gcp
               Their tools leave the system, and with them the dependencies
               nothing needs any more.

Proceed? [Y/n]
```

If the boxes have not moved, it says so and stops there.

### The order, and why it is that one

The folders of the packs to add are copied **before** anything is removed. A
pack's `remove.sh` asks which installed pack still claims a package it is about
to take away, and a folder that has just arrived counts from that moment — so a
package two packs share is left where it is, and the newcomer finds it already
installed. Removing first would take the package away and put it straight back.

There is no list of packages compared anywhere: the packs themselves say what
they claim, and the question is asked of the instance.

`add_pack` and `remove_pack` stay what they were, for one pack at a time. A
failure here stops the run where it stands and says what is in place — what was
removed, what was placed, what was never touched.

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

### What is lost with the instance

The virtual disk is deleted, so **nothing inside the instance survives**. A
rebuild destroys it the same way. Before either:

| Kept inside the instance | Before you unregister or rebuild |
| :--- | :--- |
| `~/projects/` | Nothing backs it up — push your work to a remote first |
| `~/.ssh/` | A key generated inside cannot be recovered: copy it out, or plan to revoke and regenerate it |
| `~/.config/gcloud/` | Both logins are redoable in minutes ([GCP onboarding](../../packs/gcp/docs/onboarding.md)) |
| `~/.config/zsh/gmake/.env.global` | A handful of lines; `gmake env_global_enable` recreates them from the samples the instance carries |
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

