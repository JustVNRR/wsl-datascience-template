# Packs Installed Here

[← Back to the README](../../README.md#mlops-makefile-gmake)

What this instance carries — what you chose, not everything its folder holds.

## Target

| Target | Action | Confirmation |
|---|---|---|
| `packs_list` | List the packs installed in this instance | — |

## What it reads

A pack is installed when its folder is in `~/.config/packs`. Nothing else is
consulted: no list to keep up to date, no binary to test. The command reads
those folders and prints one line per pack — its name, and the description from
its own `pack.conf`:

```text
Packs installed in this instance:

  gcp       The Google Cloud CLI (about 409 MB installed)
  python    Python 3, uv, ruff and the compilation tools (about 530 MB installed)
  vision    ffmpeg, ImageMagick and Tesseract OCR (about 500 MB installed)

A pack is added or removed from Windows:  .\wsl.ps1 add_pack  /  .\wsl.ps1 manage_packs
```

That is all it says. What a pack *brings* — its gmake targets, its cheatsheet
entries — is what `gmake help` and the picker (fcheat) are for, each of them
already listing what is loaded. Repeating any of it here would be a second list
to keep in step, and "look in the picker" would say nothing useful when the
picker holds hundreds of commands.

A pack marked `PACK_VISIBLE := no` in its `pack.conf` has no line here either.
It is a shared dependency — `devops`, the project targets python and gcp both need
— and a shared engine is not a car: it does not belong in the list of what you
asked for. It arrived with the pack that requires it, and leaves with the last
one that does.

That leaves one state where a pack is installed and nothing is listed, and it is
not the same thing as an instance with no pack at all: a removal that stopped
half way leaves a dependency behind with nothing left to require it. The command
says which of the two it is, rather than print a header over nothing. An
instance with no pack at all, it says so, and where a pack comes from.

## What it cannot say

What is **available**. That is what the checkout on Windows carries, and an
instance does not know which checkout fed it. `.\wsl.ps1 add_pack` shows those,
one pack at a time, and `.\wsl.ps1 manage_packs` shows them all as a checklist —
that is where a pack arrives or leaves.

## Variables

None of its own. It reads `PACKS_DIR`, which the Makefile sets to `packs/` in
the repository and to `~/.config/packs` in an instance.
