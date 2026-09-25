# Packs Installed Here

[← Back to the README](../../README.md#mlops-makefile-gmake)

What this instance carries.

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
  python    Python 3, uv and the scaffolding tools (about 570 MB installed)
  vision    ffmpeg, ImageMagick and Tesseract OCR (about 500 MB installed)

A pack is added or removed from Windows:  .\wsl.ps1 add_pack  /  .\wsl.ps1 manage_packs
```

That is all it says. What a pack *brings* — its gmake targets, its cheatsheet
entries — is what `gmake help` and the picker (fcheat) are for, each of them
already listing what is loaded. Repeating any of it here would be a second list
to keep in step, and "look in the picker" would say nothing useful when the
picker holds hundreds of commands.

With no pack installed, it says that, and where a pack comes from.

## What it cannot say

What is **available**. That is what the checkout on Windows carries, and an
instance does not know which checkout fed it. `.\wsl.ps1 add_pack` shows those,
one pack at a time, and `.\wsl.ps1 manage_packs` shows them all as a checklist —
that is where a pack arrives or leaves.

## Variables

None of its own. It reads `PACKS_DIR`, which the Makefile sets to `packs/` in
the repository and to `~/.config/packs` in an instance.
