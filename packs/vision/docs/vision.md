# Vision & OCR

[← Back to the README](../../../README.md#optional-tooling)

Three command-line tools and the system libraries behind them, installed by the
`vision` pack and removed with it. Nothing here is Python-specific: the pack
stops at the system tools, and the Python libraries that drive them belong to
the projects that use them.

## What it brings

| Tool | For | Commands |
| :--- | :--- | :--- |
| Tesseract OCR | reading the text out of an image | `tesseract` |
| ImageMagick | converting, resizing and cleaning images | `convert`, `identify`, `mogrify` |
| FFmpeg | audio and video | `ffmpeg`, `ffprobe` |

Tesseract reads **English and French** out of the box (the `tesseract-ocr-fra`
package is part of the pack). Another language is one command away:
`sudo apt-get install tesseract-ocr-<code>`.

## Installing and removing it

```powershell
.\wsl.ps1 add_pack      # pick the instance, then vision
.\wsl.ps1 remove_pack   # the reverse
```

The tools arrive with the pack's folder, and their commands with them — they
show up in the cheatsheet picker (`Alt + z`) as soon as the pack is installed.

On removal, a package that **another installed pack still claims** stays where
it is: that is what makes removing one pack safe when two of them share
something. What the pack never touches is your own files — it writes none.

## From Python

| Tool | Reached through |
| :--- | :--- |
| Tesseract | `pytesseract`, which drives the `tesseract` binary |
| FFmpeg | `opencv-python` or `ffmpeg-python`, for the video formats |

Those libraries are **project** dependencies: they live in the project's
`.venv` (a `pyproject.toml` entry), not in this pack. The pack only makes sure
the machine has the tools underneath.
