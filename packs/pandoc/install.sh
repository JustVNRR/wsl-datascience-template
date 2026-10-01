#!/usr/bin/env bash
# ==============================================================================
# THE PANDOC PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/pandoc, then
# runs this script from inside it, as the instance's own user.
#
# One request for a password, for the packages, and one thing apt cannot bring:
# the fonts. The template this pack serves sets Arial as its main font, and
# Linux has no Arial - which cannot be aliased either (XeTeX ignores fontconfig
# substitutions), so the font FILES are what has to arrive. They are copied
# from the Windows installation this instance runs beside, into the user's own
# font directory, and the copy goes back with the pack.
#
# Everything this script PRINTS is plain ASCII: it travels through wsl.exe to
# the Windows console, which reads those bytes in its own code page.

set -euo pipefail

# The PATH is built here, not inherited: the shell this script runs from carries
# WSL's Windows directories, and nothing here needs Windows. The python pack's
# clean_path, kept identical so the packs read alike.
clean_path=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH=$clean_path

here=$(cd "$(dirname "$0")" && pwd)
packages=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$packages" ]; then
    echo "No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

echo "Installing Pandoc and the LaTeX engine (about 800 MB - your password will be asked)..."
# DEBIAN_FRONTEND, so that a package reconfigured on the way never stops the
# install to ask something.
sudo bash -c "set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends $packages"

# --- Arial, from the Windows side ---------------------------------------------
# Four faces: regular, bold, italic, bold italic. The directory is the pack's
# own, under the user's font directory: this script put them there, remove.sh
# takes them back.
win_fonts=/mnt/c/Windows/Fonts
fonts_dir=$HOME/.local/share/fonts/ms-arial

missing=""
for face in arial.ttf arialbd.ttf ariali.ttf arialbi.ttf; do
    [ -f "$win_fonts/$face" ] || missing=$face
done

if [ -z "$missing" ]; then
    echo "Copying Arial from Windows (the template asks for it)..."
    install -d "$fonts_dir"
    for face in arial.ttf arialbd.ttf ariali.ttf arialbi.ttf; do
        install -m 644 "$win_fonts/$face" "$fonts_dir/$face"
    done
    # fc-cache, so the new files are in fontconfig's cache at once and the first
    # build does not have to wait for a rescan.
    fc-cache -f >/dev/null 2>&1 || true
    echo "Arial is installed (regular, bold, italic, bold italic)."
else
    # Said, not fatal: pandoc and the engine are useful on their own, and only
    # a template that asks for Arial needs the font.
    echo "Note: no $missing at $win_fonts - a document whose template asks for Arial"
    echo "will stop on \"The font Arial cannot be found\". One way to get it:"
    echo "   sudo apt-get install ttf-mscorefonts-installer"
fi

echo "Pandoc and XeLaTeX are ready."
echo "   gmake pdf_from_md builds a project's markdown into a PDF - the cheatsheet (fcheat)"
echo "   has the commands, and the pack's page (packs/pandoc/docs/pandoc.md) the rest."
