# Packs Installed Here

[← Back to the README](../../README.md#mlops-makefile-gmake)

What this instance carries, and what each pack brings.

## Target

| Target | Action | Confirmation |
|---|---|---|
| `packs_list` | List the packs installed in this instance, with the commands of each | — |

## What it reads

A pack is installed when its folder is in `~/.config/packs`. Nothing else is
consulted: no list to keep up to date, no binary to test. The command reads
those folders and prints one block per pack — its name, the description from its
own `pack.conf`, and what it brings:

```text
Packs installed in this instance:

  gcp        The Google Cloud CLI (about 409 MB installed)
             gmake: 34 targets, listed by gmake help

  vision     ffmpeg, ImageMagick and Tesseract OCR (about 500 MB installed)
             its commands are in the cheatsheet picker (fcheat)

A pack is added or removed from Windows:  .\wsl.ps1 add_pack  /  .\wsl.ps1 manage_packs
```

The targets themselves are not repeated here: `gmake help` lists them, sorted,
and it is the same list. What this one answers is what the *packs* are — the
question you would otherwise answer by opening the picker and looking for a
command.

A pack that brings no gmake target says so instead of showing an empty line —
that is `vision`, whose commands live in its cheatsheets only.

With no pack installed, it says that, and nothing else.

## What it cannot say

What is **available**. That is what the checkout on Windows carries, and an
instance does not know which checkout fed it. `.\wsl.ps1 add_pack` shows those,
one pack at a time, and `.\wsl.ps1 manage_packs` shows them all as a checklist —
that is where a pack arrives or leaves.

## Variables

None of its own. It reads `PACKS_DIR`, which the Makefile sets to `packs/` in
the repository and to `~/.config/packs` in an instance.
