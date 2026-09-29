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

# The pack's own folder: the sample of providers is read from beside this file,
# so the two travel together wherever the folder lands.
here=$(cd "$(dirname "$0")" && pwd)

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
    # So it is said, and one line is asked: a warning, not a gate. The default
    # is yes, and only an explicit `n` refuses - the [y/N] this started as made
    # the person prove their intent at every build, and a bare Enter should not
    # make a chosen pack disappear (his call, 2026-09-29). Declining is still an
    # ANSWER, not a failure: exit code 2, which the socle reports as "not
    # installed" rather than as a broken installation (docs/packs.md).
    #
    # The silent case agrees with the default: a pack arrives because it was
    # CHOSEN - a box ticked in the checklist `build` asks before it builds, a row
    # picked from the list `add_pack` shows - so when no line comes back at all,
    # that choice is the answer, and it is yes. Refusing there put the two halves
    # of one screen against each other once: this script threw the folder away
    # while `build` still announced the pack as installed. Measured on a fresh
    # build, and fixed on both sides.
    #
    # What counts as the answer is whether a line comes back, not whether stdin
    # is a terminal: `y`, `n`, or the empty line a bare Enter sends are all
    # answers - and only the `n` is a no.
    foreign=$(command -v claude 2>/dev/null || true)
    if [ -n "$foreign" ]; then
        echo "Claude Code is already installed on Windows."
        echo "Install a copy in this instance too? [Y/n]"
        if read -r answer; then
            case "$answer" in
                [nN]*)
                    echo "Nothing was installed."
                    exit 2
                    ;;
            esac
        fi
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

# The dictionary of providers, seeded once and never written again - the same
# move the web pack makes with its servers. Mode 600: this is where the tokens
# go, and what the pack writes in your settings comes out of it.
profiles=$HOME/.config/claude/profiles.json
if [ -f "$profiles" ]; then
    echo "$profiles is already there - left as it is."
else
    # The pack's own sample, checked before it is copied: a broken one would be
    # copied over and discovered much later, at the first profile switch.
    jq -e . "$here/profiles.sample" > /dev/null ||
        { echo "$profiles: the pack's own sample of providers does not parse - nothing was written." >&2; exit 1; }
    install -d -m 0700 "$(dirname "$profiles")"
    install -m 600 "$here/profiles.sample" "$profiles"
    echo "A dictionary of providers is in place: $profiles (mode 600, waiting for your tokens)."
fi

# The file the pack's variable lives in - CLAUDE_PROFILE is written into it by
# claude_profile. The socle builds it from the samples, and this runs that same
# target once so that the first gmake claude_profile finds it instead of stopping
# on it. Only when it is not there: an existing file is never touched, and the
# target itself only ever adds what is missing. A failure here is said, not
# fatal: the program this pack carries is installed, which is what it came for.
global_env=$HOME/.config/zsh/gmake/.env.global
makefile=$HOME/.config/zsh/gmake/Makefile
if [ ! -f "$global_env" ] && [ -f "$makefile" ]; then
    echo "Building $global_env from the samples..."
    if ! make -f "$makefile" env_global_enable; then
        echo "$global_env could not be built - 'gmake env_global_enable' will do it from a shell."
    fi
fi

# The status line the instance's sessions draw: the pack's script, written into
# the settings file the CLI reads. Set once, and never over one that is already
# there - a status line of your own is yours. remove.sh takes back exactly the
# one this writes, and only while it is still the one.
settings=$HOME/.claude/settings.json
status_command="bash ~/.config/packs/claude/bin/statusline.sh"
if [ -f "$settings" ] && ! jq -e . "$settings" > /dev/null 2>&1; then
    echo "$settings does not parse - the status line was not set."
elif [ -f "$settings" ] && [ -n "$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null || true)" ]; then
    echo "$settings already has a status line - left as it is."
else
    install -d -m 0700 "$(dirname "$settings")"
    tmp=$(mktemp)
    if [ -f "$settings" ]; then
        ok=1
        jq --arg cmd "$status_command" '.statusLine = {"type": "command", "command": $cmd}' "$settings" > "$tmp" 2>/dev/null || ok=0
    else
        ok=1
        jq -n --arg cmd "$status_command" '{statusLine: {"type": "command", "command": $cmd}}' > "$tmp" || ok=0
    fi
    if [ "$ok" = "0" ]; then
        rm -f "$tmp"
        echo "$settings could not be written - the status line was not set."
    else
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        echo "A status line was added to $settings - the pack's, on two rows."
    fi
fi

echo "Claude Code is ready."
echo "   Next: gmake claude_status. gmake claude_profile picks a provider."
