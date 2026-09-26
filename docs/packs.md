# What a Pack Is

[← Back to the README](../README.md#mlops-makefile-gmake)

A pack is optional tooling — a CLI the image does not ship, the gmake targets
that drive it, the shell commands, the variables it reads — and the two scripts
that install and remove it, all of it living in one folder under `packs/`. The
socle knows nothing about any particular pack: it finds the folders and loads
what they carry. Adding a pack touches no file outside that folder.

A pack needs no tool: `devops` is targets and nothing else — the mirror of
`vision`, which is a tool and no target. What a pack brings is what its folder
carries, and a folder may carry one of the two, or both.

## The folder

```text
packs/<name>/
├── pack.conf              # what the socle and the installer read
├── install.sh             # what `.\wsl.ps1 add_pack` runs inside the instance
├── remove.sh              # what `.\wsl.ps1 remove_pack` runs before the folder goes
├── make/*.mk              # its targets, loaded as soon as the folder is there
├── zsh/*.zsh              # its shell files, read where they live (never copied)
├── env.global.sample      # its share of the shared defaults
├── env.project.sample     # its share of a project's variables
├── cheatsheets/*.sh       # its fcheat sheets, each with a `# requires:` header
└── docs/*.md              # its pages: one per module, and whatever else it needs
```

Only the first three are always there. The rest is what the pack needs: `vision`
brings no target, no variable of its own and no sample — its folder is a
`pack.conf`, two scripts, a sheet and a page. `devops` is the other extreme, with
no package to install — its folder carries modules, two samples and its pages,
and its two scripts have nothing to do but say so. `scaffold` is both at once:
one package to install (uv), targets, a sheet, a sample and its pages.

## `pack.conf`

| Declaration | What it says |
| :--- | :--- |
| `PACK_DESCRIPTION` | the line `add_pack` shows in its list of packs |
| `PACK_REQUIRES` | the packs it is installed on top of |
| `PACK_VISIBLE` | `no` keeps it out of every list: nobody chooses it |
| `PACK_PACKAGES` | the system packages it installs — named once, read by both scripts, and by a neighbour's removal |
| `PACK_OUTSIDE_APT` | the tools it installs outside apt (a binary in `~/.local`) — named for the same reason, and read the same way |
| `PACK_IDENTIFYING_VARS` | the variables refused in a shared `.env.global` |
| `PACK_WELCOME` | the line `build` prints on a fresh instance, when this pack is among the chosen ones |

Only the first is always there. `PACK_IDENTIFYING_VARS` is read with `sed`, not
by including the file: the socle needs it while it is still loading
`.env.global`, before a pack may define anything. `PACK_DESCRIPTION` is read by
`add_pack`, from Windows.

## Installed, or not

The folder **is** the state. The socle loads `packs/*/make/*.mk` and asks
nothing else: a pack is installed exactly when its folder is in
`~/.config/packs`, which is where `.\wsl.ps1 add_pack` puts it — the files and
the tool together. Nothing is recorded anywhere, so nothing can disagree with
what is on the machine.

`gmake help` follows the same rule as ever: it is built by reading the **text**
of the files make loaded, so a pack whose folder is gone contributes no line at
all. That is why the two-faced arrangement this replaces — a module loaded only
when a given binary was on the PATH — had to go: it made a pack's commands
appear or disappear for a reason that was not the pack's presence.

A pack's targets are ordinary ones, with one thing they can declare themselves:
a target that only makes sense from `~/projects` (scaffolding) says so in its
module — `SCAFFOLD_GOALS += copier_project cruft_project ccds_project`, in
`packs/scaffold/make/project-setup.mk` — and the location gate in the Makefile
reads that declaration. The gate is checked after the modules are loaded,
precisely so it can: `$(error)` fires when make *reads* the line, and a target
nobody declares would be treated as a project target and refused from
`~/projects` with a message about a project root that is not the point.

A pack also curates its own template catalog (`cheatsheets/templates.tsv`), and
the `scaffold` pack's `fnew` reads every installed pack's, showing each row with
the pack it was read from. What runs once such a row's template has been copied
is that pack's to declare — `SCAFFOLD_AFTER_python := init_venv`, in its own
module, beside the macro it names — and `fnew` names the row's pack on the make
command line. A pack that declares nothing names nothing: its projects are
copied and left alone.

Removing is the same story from the other end: `.\wsl.ps1 remove_pack` runs the
pack's own `remove.sh` first, then deletes the folder, then takes back the
dependencies that came in with the pack and that no `remove.sh` ever named —
they are the bulk of the weight (the vision pack leaves 203 packages and
462 MB behind). What the install wrote in your files — a login, a `.env` you
filled in — stays, because it is yours and not the pack's. The rule that
decides what may go is in [Instance commands](wsl/commands.md#remove_pack).

Several packs at once go through `.\wsl.ps1 manage_packs`, which is a checklist
of every pack this repository carries: the ones the instance has arrive checked,
and one Enter installs what is missing and takes out what is not. It copies the
newcomers' folders before removing anything, so a package two packs share is
left where it is — [the order, and why](wsl/commands.md#manage_packs).

A new instance can start with its packs already in place: `.\wsl.ps1 build`
asks the same checklist before it builds, and installs the answer once the
instance exists.

They are all documented in
[Instance commands](wsl/commands.md#add_pack).

## The shell

A pack may bring shell files (`zsh/*.zsh`), and the socle reads them **where
they live** — `~/.config/packs/*/zsh/*.zsh`, from the `.zshrc` that loads
everything else. Nothing is copied into `~/.config/zsh`: a pack that leaves
takes its commands out of the shell exactly as it takes its targets out of the
menu, and an instance carrying no pack reads nothing there at all. The
`scaffold` pack's `fnew` and the catalogs it reads travel together that way — the
picker resolves them from its own file's location, not from a path that only
exists in the socle.

## Two packs, one choice

`PACK_REQUIRES` names a pack it is installed on top of — one name, or several.
What it requires arrives **before** it, a pack lands on what it needs, and it
leaves **after** it, when the last pack that required it goes.

The second half is what makes an invisible pack possible. `PACK_VISIBLE := no`
is a pack in no list: not in `add_pack`'s, not in `manage_packs`' checklist, not
in `gmake packs_list`. You cannot choose it, and you cannot remove it by hand —
either one would pull the base out from under a pack still installed. It arrives
with the pack that requires it, it leaves with the last one that does, and it is
never alone.

`devops` and `scaffold` are the two of them, each the mirror of `vision` in its
own way: `devops` is the project targets `python` and `gcp` both need, and
`scaffold` is the act of creating a project — which `python` needs, and which is
not python.

They are required for what they bring, not for a macro: `gcp` reads
`PACKAGE_NAME` and `DOCKER_BASE_IMAGE`, whose sample is `devops`'s; `python`
fabricates the projects its targets build, push and configure, and it is the pack
that has something to do once a template has been copied
(`SCAFFOLD_AFTER_python`). What a target *calls* — `check_vars`,
`confirm_action` — is the socle's, loaded with every module, and a pack that
writes a target declares nothing.

## Two packs, one package

Two packs may install the same package — a compiler, a media library — and they
will, the day a use case arrives that needs what another one already wanted.
The second install is a non-event: apt answers *already the newest version*, uv
answers *already installed*. What must not happen is the second pack breaking
when the first one leaves.

So a pack **does not own** what it installs: it is one of the claimants. Before
removing a package, its `remove.sh` looks for that name in the declarations of
the packs still installed — `pack.conf`, and `install.sh` as well for a pack
written before `PACK_PACKAGES` existed. A claimed package is left where it is,
and the last pack to want it takes it away with it.

What apt never sees goes through the same question. A tool a pack installs
itself — a binary under `~/.local`, outside dpkg's graph — is declared in
`PACK_OUTSIDE_APT`, and its `remove.sh` asks before erasing a single file. `uv`
is the case that exists: `python` uses it for a project's environment, `scaffold`
for every tool it runs, so the first of the two to leave leaves it where it is
and the last one takes it away, with the interpreter it downloaded and its
cache.

Two things a `remove.sh` never does:

- **`autoremove` from inside a `remove.sh`.** apt removes the package it is
  given and leaves its dependencies alone — measured: taking `tesseract-ocr`
  away leaves `libtesseract5` behind. Those dependencies are taken back, but by
  `remove_pack`, not by the pack: "does anything still need this?" is a question
  about the whole instance — apt for what apt installed, `ldd` for the programs
  living outside its graph — and a pack cannot see the instance it lands in.
- **Remove a library.** apt *does* take the programs that depend on it along
  when a library goes (measured, and it says so before doing it). A pack names
  programs.

What this buys: no pack has to be cut to avoid an overlap, and no one has to
arbitrate who owns what. A pack that needs a package installs it, whether or
not a neighbour already did.

## The cheatsheets

A sheet declares what it needs in its header, and the picker asks again every
time it opens:

```
# requires: <binary>      shown only when that binary is on the PATH
# requires: !<binary>     shown only when it is not
```

A tool removed by hand (`sudo apt remove google-cloud-cli`) leaves a folder
behind and a sheet whose commands would not run: the header hides it. That is
the whole job it has left — the sheets it used to pair with, for installing and
uninstalling the tool, went with the gate.

## The variables

A pack ships samples, never the real files. `gmake env_global_enable` and
`gmake env_project_enable` read the socle's samples and every installed pack's,
and append only what the file does not already define — so a value you filled
in survives, and a pack installed later is covered by the next run. See
[Environment files](../packs/devops/docs/env.md).

## Not yet

One field has no reader, and is absent for that reason: `PACK_CONTRACT` — the
version of this contract, which no instance has ever met another of, since the
packs and the installer still come from the same checkout. A field nothing
reads is not a safety.
