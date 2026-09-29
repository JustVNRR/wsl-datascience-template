#!/usr/bin/env bash
# ==============================================================================
# THE CLAUDE PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/claude, then
# runs this script from inside it, as the instance's own user.
#
# One tool, and it asks for no password: Anthropic's own installer unpacks a
# single binary under ~/.local - the launcher at ~/.local/bin/claude, the
# versions it keeps at ~/.local/share/claude/versions/<version>.
#
# Everything this script PRINTS is plain ASCII, and short. Two reasons, and the
# second is the one that was measured: whatever it says travels through wsl.exe
# to the Windows console, which reads those bytes in its own code page - an
# emoji or an em dash arrives there as garbage. Nothing in the repository sets
# that encoding, so a pack's install and remove scripts are the ASCII half of
# the house; the targets, whose output stays inside the instance, are not.

set -euo pipefail

# This runs from a shell that has not read the zsh configuration, so ~/.local/bin
# is not on its PATH: the check below needs it there.
export PATH="$HOME/.local/bin:$PATH"

# The pack's own launcher, at the path this pack installs it to - never whatever
# `claude` the PATH happens to resolve to. WSL appends the Windows directories
# to the PATH, so a Claude Code installed on Windows (npm, or its own installer)
# is found from inside the instance: asking the PATH would answer "already
# installed" about a program that runs on the other side of the wall, and this
# script would install nothing at all. Measured, on a real instance.
launcher=$HOME/.local/bin/claude

if [ -x "$launcher" ]; then
    echo "Claude Code is already installed ($("$launcher" --version)) - nothing to do."
else
    # A Claude Code installed on Windows is visible from here, and it is a real
    # installation: typing `claude` works. It runs on the other side of the wall
    # though - Windows paths, Windows files, the Windows copy of your settings -
    # where what this pack installs runs here, on this instance's own files.
    #
    # So it is asked, and it is a real question: someone who works from Windows
    # on purpose should not pay for a second copy by accident. A bare Enter
    # declines - the answer that costs nothing is the one a bare Enter gives -
    # and declining is an ANSWER, not a failure: exit code 2, which the socle
    # reports as "not installed" rather than as a broken installation
    # (docs/packs.md). A run with nobody at the keyboard declines too: nothing
    # is downloaded on a guess.
    foreign=$(command -v claude 2>/dev/null || true)
    if [ -n "$foreign" ]; then
        echo "Claude Code is already installed on Windows."
        echo "Install a copy in this instance too? [y/N]"
        read -r answer || answer=""
        case "$answer" in
            [yY]*) ;;
            *)
                echo "Nothing was installed."
                exit 2
                ;;
        esac
    fi

    echo "Installing Claude Code from Anthropic's own script (a few minutes)..."
    # Everything below runs with a PATH that has no Windows in it, and that is
    # the fix for a bug that cost something real (measured, 2026-09-29).
    #
    # WSL appends the Windows directories to the PATH, so inside an instance
    # `npm` IS the Windows npm - /mnt/c/Program Files/nodejs/npm - and WSL will
    # happily run it. The installer's own migration step, which moves an older
    # npm installation to the native build, followed that: it ran `npm uninstall
    # --global @anthropic-ai/claude-code` THROUGH THE WALL and uninstalled Claude
    # Code from Windows, while the native build it installed landed here. The
    # trace is npm's own log, and its working directory was this very folder.
    #
    # With no /mnt/c on the PATH, no Windows program of any name can be reached:
    # the installer finds no npm to migrate, and no other `claude` to argue with
    # either. Everything it needs - curl, bash, sha256sum, zstd - lives under
    # /usr, and none of it is a Windows program.
    clean_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    #
    # No sudo, and the installer refuses it: everything lands under $HOME, and
    # under sudo that $HOME is root's, where the launcher would not be found by
    # anyone. Nothing here needs root, which is the other half of why this pack
    # declares PACK_OUTSIDE_APT instead of PACK_PACKAGES.
    #
    # pipefail is on from the top of this script, and it is what makes the pipe
    # safe: a curl that fails would feed the installer an empty script, which
    # exits 0, and the failure would surface one step later, on a missing
    # `claude`.
    #
    # The installer ends by printing a note - "~/.local/bin is not in your PATH,
    # run: echo ... >> your shell config file" - and nothing is done about it
    # here on purpose: the socle already exports that directory
    # (zsh/exports.zsh), so the note is already answered, and a pack that writes
    # into your files has something to undo the day it leaves. There is no
    # opt-out variable to set, unlike uv's installer, because there is nothing
    # to opt out of.
    PATH=$clean_path curl -fsSL https://claude.ai/install.sh | PATH=$clean_path bash
fi

echo "Claude Code is ready."
echo "   Next: gmake claude_status, and the first 'claude' asks you to log in."
