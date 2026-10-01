#!/usr/bin/env bash
# ==============================================================================
# THE CLAUDE PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/claude, then
# runs this script from inside it, as the instance's own user.
#
# One tool, and it asks for no password: Anthropic's own installer unpacks a
# single binary under ~/.local - the launcher at ~/.local/bin/claude, the
# versions under ~/.local/share/claude/versions/<version>.
#
# Everything this script PRINTS is plain ASCII: it travels through wsl.exe to
# the Windows console, which reads those bytes in its own code page - an emoji
# or an em dash arrives there as garbage. The targets' output stays inside the
# instance and is not bound by that.

set -euo pipefail

# The messages: the shared library replaces this fallback when the image
# carries it; an instance built before it prints a plain sentence.
hint() { printf '%s\n' "$*"; }
if [ -r "$HOME/.config/zsh/lib/message.sh" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.config/zsh/lib/message.sh" || true
fi

# The sample is read from beside this file: the two travel together wherever
# the folder lands.
here=$(cd "$(dirname "$0")" && pwd)

# From a shell that has not read the zsh configuration: ~/.local/bin is not on
# its PATH yet, and the check below needs it there.
export PATH="$HOME/.local/bin:$PATH"

# The pack's own path, never what `claude` on the PATH resolves to: WSL appends
# the Windows directories, so a Windows Claude Code is found from inside - the
# PATH would answer "already installed" and this would install nothing.
launcher=$HOME/.local/bin/claude

if [ -x "$launcher" ]; then
    echo "Claude Code is already installed ($("$launcher" --version)) - nothing to do."
else
    # A Windows Claude Code is visible from here and really works - on Windows
    # paths, Windows files, the Windows copy of your settings. This pack's copy
    # runs on the instance's own files.
    #
    # So it is said, and one line is asked: a warning, not a gate. Yes is the
    # default, and only an explicit `n` refuses; declining is an ANSWER, not a
    # failure - exit code 2, which the socle reports as "not installed" rather
    # than as a broken installation.
    #
    # The question is yellow (lib/message.sh's hint): it travels to a Windows
    # console in a stream of other lines, where a bare sentence reads as one
    # more log line.
    #
    # No answer at all - a silent build - agrees with the default: the pack was
    # CHOSEN before the run started. What counts as an answer is whether a line
    # comes back, not whether stdin is a terminal.
    foreign=$(command -v claude 2>/dev/null || true)
    if [ -n "$foreign" ]; then
        echo ""
        hint "Claude Code is already installed on Windows."
        hint "Install a copy in this instance too? [Y/n]"
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
    # A PATH with no Windows in it, and that is the fix for a bug that cost
    # something real: WSL appends the Windows directories, so inside an instance
    # `npm` IS the Windows npm - and the installer's migration step followed it
    # through the wall, uninstalling Claude Code from Windows while installing
    # its own copy here. With no /mnt/c on the PATH no Windows program of any
    # name can be reached; everything the installer needs lives under /usr.
    #
    # $HOME/.local/bin is in it on purpose: without it the installer misses its
    # own directory and prints a setup note that is false here (the socle
    # exports it - zsh/exports.zsh).
    #
    # No sudo either: everything lands under $HOME, and under sudo that $HOME is
    # root's, where nobody would find the launcher.
    #
    # pipefail (set at the top) is what makes the pipe safe: a failed curl would
    # feed the installer an empty script, which exits 0.
    #
    # The installer's output is thinned to ASCII on its way through: it prints
    # bytes above 0x7F that a Windows console reads as garbage. Only those bytes
    # are dropped; the sentences stay.
    clean_path=$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    PATH=$clean_path curl -fsSL https://claude.ai/install.sh | PATH=$clean_path bash 2>&1 |
        LC_ALL=C tr -d '\200-\377'
fi

# The dictionary of providers: seeded once, never written again. Mode 600 - the
# tokens go in there, and what the pack writes in your settings comes out of it.
profiles=$HOME/.config/claude/profiles.json
if [ -f "$profiles" ]; then
    echo "$profiles is already there - left as it is."
else
    # Checked before it is copied: a broken sample would be discovered at the
    # first profile switch.
    jq -e . "$here/profiles.sample" > /dev/null ||
        { echo "$profiles: the pack's own sample of providers does not parse - nothing was written." >&2; exit 1; }
    install -d -m 0700 "$(dirname "$profiles")"
    install -m 600 "$here/profiles.sample" "$profiles"
    echo "A dictionary of providers is in place: $profiles."
    echo "Fill it with your tokens."
fi

# The socle builds .env.global from the samples; this runs that target once so
# the first `gmake claude_profile` finds it. Only when it is not there; a
# failure here is said, not fatal - the program is installed, which is what the
# pack came for.
global_env=$HOME/.config/zsh/gmake/.env.global
makefile=$HOME/.config/zsh/gmake/Makefile
if [ ! -f "$global_env" ] && [ -f "$makefile" ]; then
    echo "Building $global_env from the samples..."
    if ! make -f "$makefile" env_global_enable; then
        echo "$global_env could not be built - 'gmake env_global_enable' will do it from a shell."
    fi
fi

# The status line the instance's sessions draw: set once, and never over one
# that is already there. remove.sh takes back exactly the one this writes, and
# only while it is still the one.
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
    fi
fi

echo "Claude Code is ready."
