#!/usr/bin/env bash
# ==============================================================================
# CLAUDE CODE, AND WHAT THIS INSTANCE KNOWS ABOUT IT
# ==============================================================================
# The script behind the pack's targets, the same arrangement as web's
# bin/vpn.sh: a module is one line per target, and the reading, the deciding and
# the wording live here.
#
# One subcommand today: status.

set -euo pipefail

# Where the pack put the program, named before anything looks for it - the same
# line install.sh carries, and for the same reason: called by make the PATH is
# zsh's, which already has ~/.local/bin, but called by hand from a shell that
# has not read the zsh configuration it is not, and the answer would be "not
# installed" about a program that is right there. A pack knows what it
# installed; it does not ask the caller's shell.
export PATH="$HOME/.local/bin:$PATH"

# The pack's program, at the path this pack installs it to - and not whatever
# `claude` the PATH resolves to, which is a different question with a different
# answer. WSL appends the Windows directories to the PATH, so a Claude Code
# installed on Windows is found from inside the instance: reported as this
# instance's own, `gmake claude_status` would describe a program that runs on
# the other side of the wall, and the "not installed" branch would never be
# reached. Measured on a real instance, and the reason install.sh tests the same
# path.
launcher=$HOME/.local/bin/claude
claude_bin=""
[ -x "$launcher" ] && claude_bin=$launcher

# What the PATH finds instead, when it finds something else. Named only, never
# used: the person will type `claude` and see it answer, and the message that
# says the pack's own is missing has to say why.
foreign_bin=$(command -v claude 2>/dev/null || true)
[ "$foreign_bin" = "$launcher" ] && foreign_bin=""

versions_dir=$HOME/.local/share/claude/versions
config_dir=$HOME/.claude

status() {
    echo ""
    echo "Claude Code, in this instance"
    echo ""

    # Absent, while the pack's folder is still there - this target just ran from
    # it. Two ways to get here, and the message names them both rather than
    # pick one: a program removed by hand, and an installation that did not
    # finish. Either way the way back is the pack's own install script, which
    # asks the machine before it downloads anything.
    if [ -z "$claude_bin" ]; then
        echo "  ❌ Claude Code is not installed in this instance."
        echo ""
        if [ -n "$foreign_bin" ]; then
            # The case a WSL instance hits as soon as Windows has one: typing
            # `claude` works, and it is not this one. Said before the way back,
            # because it is the surprise, not the detail.
            echo "     Your PATH does find one — $foreign_bin — but that one"
            echo "     runs on Windows, not here, and this pack did not put it there."
            echo ""
            echo "     The pack's own is missing: taken away by hand, or an"
            echo "     installation that stopped half way. Put it back with the"
            echo "     script that installed it the first time:"
        else
            echo "     The pack is there, the program is not - taken away by hand, or"
            echo "     an installation that stopped half way. Put it back with the"
            echo "     script that installed it the first time:"
        fi
        echo ""
        echo "         bash ~/.config/packs/claude/install.sh"
        echo ""
        return 1
    fi

    echo "  program    $("$claude_bin" --version)"

    # The launcher is a symlink into the versions the CLI keeps; the target is
    # worth showing, because that is where the disk goes.
    local target
    target=$(readlink -f "$claude_bin" 2>/dev/null || true)
    if [ -n "$target" ] && [ "$target" != "$claude_bin" ]; then
        echo "  launcher   $claude_bin → $target"
    else
        echo "  launcher   $claude_bin"
    fi

    # The versions kept on disk: one file each, and the whole weight of the
    # pack. The CLI keeps every version it installs, so this line is the one
    # that grows by about 230 MB at each update.
    if [ -d "$versions_dir" ]; then
        local count size
        count=$(find "$versions_dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
        size=$(du -sh "$versions_dir" 2>/dev/null | cut -f1)
        echo "  versions   $count on disk, $size — $versions_dir"
    fi

    # The settings, the credentials, the history and the sessions: what the CLI
    # writes for itself, and what a removal leaves where it is.
    if [ -d "$config_dir" ]; then
        echo "  config     $config_dir"
    else
        echo "  config     none yet — the first session writes it"
    fi

    access
    endpoint

    echo ""
}

# What a session will present, and where it will go. Two sources, read in the
# order the CLI reads them: the env block of its own settings file comes first -
# a settings file beats the shell, that is documented - and the environment
# after it. The `has` form rather than a truth test, so a variable that is set
# to something odd still counts as set.
#
# Only the NAME of the variable is ever printed, never its value: a status that
# showed a key would be a leak with a friendly face.
access() {
    local settings=$HOME/.claude/settings.json
    local name="" where=""

    if [ -f "$settings" ]; then
        name=$(jq -r '(.env // {}) | if has("ANTHROPIC_AUTH_TOKEN") then "ANTHROPIC_AUTH_TOKEN" elif has("ANTHROPIC_API_KEY") then "ANTHROPIC_API_KEY" else empty end' "$settings" 2>/dev/null || true)
        [ -n "$name" ] && where="in $settings"
    fi
    if [ -z "$name" ] && [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
        name=ANTHROPIC_AUTH_TOKEN
        where="in the environment"
    fi
    if [ -z "$name" ] && [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        name=ANTHROPIC_API_KEY
        where="in the environment"
    fi

    if [ -n "$name" ]; then
        echo "  access     a key $where ($name) — nothing to log in to"
        return
    fi

    # No key anywhere, so the stored login is what is left, and the CLI is the
    # one that knows it. `|| true`: no login at all exits non-zero, and that is
    # an answer, not a failure.
    #
    # The three answers are spelled out rather than written with a fallback,
    # because the obvious short form is wrong: in jq, `//` treats false as
    # absent, so `.loggedIn // "unknown"` answers "unknown" for a
    # `loggedIn: false` - which is what a fresh instance, logged in nowhere,
    # reports.
    local auth answer
    auth=$("$claude_bin" auth status 2>/dev/null || true)
    answer=$(printf '%s' "$auth" |
        jq -r 'if .loggedIn == true then (.authMethod // "a login") elif .loggedIn == false then "none" else "unknown" end' 2>/dev/null || true)
    case "$answer" in
        none)    echo "  access     nothing yet — a key in the settings, or a login" ;;
        unknown) echo "  access     unknown — 'claude auth status' had nothing to say" ;;
        *)       echo "  access     a login ($answer)" ;;
    esac
}

# Where the requests go, from the same two places as the key above. A key with
# no base URL talks to the Anthropic API; a base URL is what points a session at
# a gateway or a provider that speaks the same API.
endpoint() {
    local settings=$HOME/.claude/settings.json
    local url=""

    if [ -f "$settings" ]; then
        url=$(jq -r '(.env // {}).ANTHROPIC_BASE_URL // empty' "$settings" 2>/dev/null || true)
    fi
    [ -z "$url" ] && url=${ANTHROPIC_BASE_URL:-}

    if [ -n "$url" ]; then
        echo "  endpoint   $url"
    else
        echo "  endpoint   the Anthropic API — no ANTHROPIC_BASE_URL set"
    fi
}

case "${1:-}" in
    status)
        status
        ;;
    *)
        echo "Usage: $(basename "$0") <status>" >&2
        exit 2
        ;;
esac
