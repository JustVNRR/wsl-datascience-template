# What a Pack Is

[← Back to the README](../README.md#mlops-makefile-gmake)

A pack is optional tooling — a CLI the image does not ship, and the gmake
targets that drive it — living in one folder under `packs/`. The socle knows
nothing about any particular pack: it finds the folders, reads what they
declare, and follows. Adding a pack touches no file outside that folder.

## The folder

```text
packs/<name>/
├── pack.conf              # what the socle needs to know
├── install.mk             # loaded while the gate binary is ABSENT — the way in
├── make/*.mk              # loaded while it is PRESENT — what the pack offers
├── env.global.sample      # its share of the shared defaults
├── env.project.sample     # its share of a project's variables
├── cheatsheets/*.sh       # its fcheat sheets, each with a `# requires:` header
└── docs/*.md              # one page per module, plus its own walkthrough
```

## `pack.conf`

| Declaration | What it says |
| :--- | :--- |
| `PACK_NAME` | the folder's name, so a reader never has to look twice |
| `PACK_GATE` | the binary that decides which face is loaded |
| `PACK_GATE_EXEMPT_GOALS` | the targets reachable from anywhere, before a project exists |
| `PACK_IDENTIFYING_VARS` | the variables refused in a shared `.env.global` |

The last two are read with `sed`, not by including the file: the socle needs
them while it is still loading `.env.global`, before a pack may define
anything.

## The gate

`gmake help` is built by reading the **text** of the files make loaded, not
from the targets make defined. A module that was not loaded contributes no line
at all — which is why a pack has two faces rather than one conditional: an
`ifeq` around a target would leave its description in the text, and the menu
would show both faces at once.

Nothing is recorded anywhere. The question is asked again on every run, so
installing the CLI by any means brings the targets back, and removing it takes
them away. `PACK_GATES=x gmake help` forces every gate open — that is how CI
reads both faces.

## The cheatsheets

A sheet declares what it needs in its header, and the picker asks again every
time it opens:

```
# requires: <binary>      shown only when that binary is on the PATH
# requires: !<binary>     shown only when it is not
```

A pack that installs a tool ships the `!` sheet for the install and the plain
one for the uninstall, exactly as its two make files do.

## The variables

A pack ships samples, never the real files. `gmake env_global_enable` and
`gmake env_project_enable` read the socle's samples and every pack's, and
append only what the file does not already define — so a value you filled in
survives, and a pack added later is covered by the next run. See
[Environment files](make/env.md).

## Not yet

A pack lives in this repository. The day one moves to a repository of its own,
`pack.conf` will need to declare which contract version it was written
against — a field that would be dead weight today, since there is only ever
one version in play.
