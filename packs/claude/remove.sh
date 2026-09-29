#!/usr/bin/env bash
# ==============================================================================
# THE CLAUDE PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added leaves the machine, and only that.
#
# Three things to take back, and they are the whole weight: the launcher, the
# versions behind it, and the desktop entry the CLI drops for its URL scheme -
# it names the launcher, so it dies with it.
#
# What the CLI wrote (~/.claude, its state file, its caches) and the dictionary
# the pack seeded are the user's, and they STAY - exactly as ~/.mozilla stays
# when the web pack leaves. Keeping them is the default, and the one question
# at the end is the only thing that says otherwise; with no answer to read, the
# default is the answer (docs/packs.md).

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

# Is this name declared by another pack that is still installed?
#
# A claim is a declaration, not a mention: these files talk about what they
# install, and a comment that says "claude" claims nothing. So the name is read
# off the two declaration lines - PACK_PACKAGES for what apt installs,
# PACK_OUTSIDE_APT for what apt never sees - and off install.sh as well, in one
# piece, for a pack written before PACK_PACKAGES existed.
claimed_elsewhere() {
    local other value word
    for other in "$HOME"/.config/packs/*/; do
        if [ "${other%/}" = "$here" ]; then
            continue
        fi
        value=$(sed -nE 's/^PACK_(PACKAGES|OUTSIDE_APT) *:=[[:space:]]*//p' "$other/pack.conf" 2>/dev/null)
        for word in $value; do
            if [ "$word" = "$1" ]; then
                return 0
            fi
        done
        grep -q -- "$1" "$other/install.sh" 2>/dev/null && return 0
    done
    return 1
}

claimed=0
if claimed_elsewhere claude; then
    claimed=1
    echo "claude: another installed pack claims it - left in place, with the versions it keeps."
else
    echo "Removing Claude Code and the versions it keeps..."
    # Every path is spelled from $HOME, so none can be empty when `rm` reads it,
    # and `rm -f` never fails on one that is already gone. The launcher may be a
    # symlink (the ordinary case) or a launcher file the CLI wrote for itself;
    # `rm -f` takes either, and takes nothing else.
    rm -f "$HOME/.local/bin/claude"
    rm -rf "$HOME/.local/share/claude"
    # And the desktop entry for the claude-cli:// scheme. Not a file the pack
    # wrote - the CLI drops it at a run - but it points at the launcher just
    # removed, so it is a dead entry the day the pack leaves (measured on a real
    # instance). Only that file: the applications directory is shared.
    rm -f "$HOME/.local/share/applications/claude-code-url-handler.desktop"
fi

# And the provider keys it wrote in the settings - the four shorthand ones, plus
# every key the dictionary declared. They are meaningless without the file that
# named them, and a token left behind by a removed pack is a token nobody looks
# after. Everything else in that file - the statusLine, the permissions, your own
# variables - is not looked at, here no more than when they are written.
settings=$HOME/.claude/settings.json
if [ -f "$settings" ]; then
    profiles=$HOME/.config/claude/profiles.json
    owned=$(
        {
            printf 'ANTHROPIC_BASE_URL\nANTHROPIC_AUTH_TOKEN\nANTHROPIC_API_KEY\nANTHROPIC_MODEL\n'
            if [ -f "$profiles" ]; then
                jq -r '(.profiles // [])[] | del(.id, .note) | keys[]' "$profiles" 2>/dev/null || true
            fi
        } | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))'
    )
    tmp=$(mktemp)
    if jq --argjson owned "$owned" '
            (.env // {}) as $env
            | .env = ($env | with_entries(select(.key as $k | ($owned | index($k)) == null)))
            | if .env == {} then del(.env) else . end
        ' "$settings" > "$tmp" 2>/dev/null; then
        chmod 600 "$tmp"
        mv "$tmp" "$settings"
        echo "The provider keys this pack wrote were taken back out of $settings."
    else
        rm -f "$tmp"
        echo "$settings could not be read - the provider keys in it were left as they are."
    fi
fi

# And the status line, only while it is still the pack's: one of your own is
# yours, and this never takes it away.
if [ -f "$settings" ]; then
    if jq -r '.statusLine.command // empty' "$settings" 2>/dev/null | grep -q 'packs/claude/bin/statusline.sh'; then
        tmp=$(mktemp)
        if jq 'del(.statusLine)' "$settings" > "$tmp" 2>/dev/null; then
            chmod 600 "$tmp"
            mv "$tmp" "$settings"
            echo "The pack's status line was taken back out of $settings."
        else
            rm -f "$tmp"
        fi
    fi
fi

# What the CLI wrote and the dictionary the pack seeded: the removals above were
# about the program, this is about the data, and it is the user's. It stays, and
# that is the default - sessions, a login, tokens are the things that cannot be
# fetched again - and a `n` is the one answer that takes it all. Asked only when
# the program really left (a pack claiming claude means the tool stays, and its
# data stays with it) and only when there is something to keep. With no answer
# to read, the default is the answer, like everywhere a pack asks
# (docs/packs.md). Framed, like the install question and for the same reason:
# this text lands in a Windows console, where a bare sentence gets lost.
wiped=0
has_data=0
if [ -e "$HOME/.claude" ] || [ -e "$HOME/.claude.json" ] || [ -e "$HOME/.config/claude" ]; then
    has_data=1
fi

if [ "$claimed" -eq 0 ] && [ "$has_data" -eq 1 ]; then
    echo ""
    echo "=============================================================================="
    echo "  Your data stays where it is:"
    echo "     ~/.claude and ~/.claude.json - settings, login, history, sessions"
    echo "     the caches under ~/.cache and ~/.local/state"
    echo "     ~/.config/claude/profiles.json - your providers, and their tokens"
    echo "  Keep it all? [Y/n]"
    echo "=============================================================================="
    echo ""
    if read -r answer; then
        case "$answer" in
        [nN]*)
            wiped=1
            rm -rf "$HOME/.claude" "$HOME/.claude.json" "$HOME/.cache/claude" \
                "$HOME/.local/state/claude" "$HOME/.config/claude"
            # And the pack's block in .env.global: the fence, the title, the
            # comments, and the CLAUDE_PROFILE line the target writes - removed
            # only when the block is really there, so a file that never saw the
            # merge is left byte for byte. The awk buffers the file because the
            # fence to drop is the line BEFORE the title.
            global_env=$HOME/.config/zsh/gmake/.env.global
            if [ -f "$global_env" ] && grep -q "^# CLAUDE - SHARED DEFAULTS (the claude pack)$" "$global_env"; then
                tmp=$(mktemp)
                if awk '
                        { lines[NR] = $0 }
                        END {
                            start = 0
                            for (i = 1; i <= NR; i++) {
                                if (lines[i] == "# CLAUDE - SHARED DEFAULTS (the claude pack)") { start = i; break }
                            }
                            if (start > 1 && lines[start - 1] ~ /^# =+$/) start = start - 1
                            end = 0
                            for (i = start; i <= NR; i++) {
                                if (lines[i] ~ /^CLAUDE_PROFILE=/) { end = i; break }
                            }
                            for (i = 1; i <= NR; i++) {
                                if (start > 0 && end > 0 && i >= start && i <= end) continue
                                print lines[i]
                            }
                        }
                    ' "$global_env" > "$tmp"; then
                    mv "$tmp" "$global_env"
                else
                    rm -f "$tmp"
                fi
            fi
            echo "All of it was removed as well."
            ;;
        esac
    fi
fi

if [ "$claimed" -eq 0 ]; then
    echo "Claude Code is gone."
    if [ "$wiped" -eq 1 ]; then
        echo "   Its data went with it: nothing of this pack is on the machine any more."
    else
        echo "   Left where they are: your providers, ~/.config/claude/profiles.json - they"
        echo "   carry your tokens - and ~/.claude, with its settings, its history and its login."
    fi
else
    echo "Claude Code is still there: another installed pack claims it."
fi

# Everything printed above is plain ASCII, like install.sh and for the same
# reason: this text travels through wsl.exe to the Windows console, which reads
# it in its own code page.
