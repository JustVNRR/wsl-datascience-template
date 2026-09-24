# What a Pack Is

[← Back to the README](../README.md#mlops-makefile-gmake)

A pack is optional tooling — a CLI the image does not ship, the gmake targets
that drive it, and the script that installs both — living in one folder under
`packs/`. The socle knows nothing about any particular pack: it finds the
folders and loads what they carry. Adding a pack touches no file outside that
folder.

## The folder

```text
packs/<name>/
├── pack.conf              # what the socle and the installer read
├── install.sh             # what `.\wsl.ps1 add_pack` runs inside the instance
├── remove.sh              # what `.\wsl.ps1 remove_pack` runs before the folder goes
├── make/*.mk              # its targets, loaded as soon as the folder is there
├── env.global.sample      # its share of the shared defaults
├── env.project.sample     # its share of a project's variables
├── cheatsheets/*.sh       # its fcheat sheets, each with a `# requires:` header
└── docs/*.md              # its pages: one per module, and whatever else it needs
```

Only the first three are always there. The rest is what the pack needs: `vision`
brings no target, no variable of its own and no sample — its folder is a
`pack.conf`, two scripts, a sheet and a page.

## `pack.conf`

| Declaration | What it says |
| :--- | :--- |
| `PACK_DESCRIPTION` | the line `add_pack` shows in its list of packs |
| `PACK_PACKAGES` | the system packages it installs — named once, read by both scripts, and by a neighbour's removal |
| `PACK_IDENTIFYING_VARS` | the variables refused in a shared `.env.global` |

`PACK_IDENTIFYING_VARS` is read with `sed`, not by including the file: the socle
needs it while it is still loading `.env.global`, before a pack may define
anything. `PACK_DESCRIPTION` is read by `add_pack`, from Windows.

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

Removing is the same story from the other end: `.\wsl.ps1 remove_pack` runs the
pack's own `remove.sh` first, then deletes the folder. What the install wrote to
the system leaves with it; what it wrote in your files — a login, a `.env` you
filled in — stays, because it is yours and not the pack's.

Both commands are documented in
[Instance commands](wsl/commands.md#add_pack).

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

Two things a `remove.sh` never does:

- **`autoremove`.** apt removes the package it is given and leaves its
  dependencies alone — measured: taking `tesseract-ocr` away leaves
  `libtesseract5` behind. `autoremove` would take everything that no longer
  looks wanted, which is a judgement call apt cannot make about our packs.
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
[Environment files](make/env.md).

## Not yet

Two fields have no reader, and are absent for that reason: `PACK_CONTRACT` —
the version of this contract, which no instance has ever met another of, since
the packs and the installer still come from the same checkout — and
`PACK_REQUIRES`, a pack needing another. The section above is why that one is
not missed: a pack installs what it needs, so it has nothing to ask a neighbour
for, and the removal rule protects the shared package either way. A field
nothing reads is not a safety.
