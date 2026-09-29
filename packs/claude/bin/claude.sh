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

# The program. `command -v` is also what the sheet's `# requires: claude` header
# asks, so the two agree on what "installed" means.
claude_bin=$(command -v claude 2>/dev/null || true)

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
        echo "  ❌ No 'claude' in this instance."
        echo ""
        echo "     The pack is there, the program is not - taken away by hand, or"
        echo "     an installation that stopped half way. Put it back with the"
        echo "     script that installed it the first time:"
        echo ""
        echo "         bash ~/.config/packs/claude/install.sh"
        echo ""
        return 1
    fi

    echo "  program    $(claude --version)"

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

    # The login, from the CLI's own answer (a JSON object, and jq is in the
    # image). `|| true`: the command exits non-zero when there is no login, and
    # that is an answer, not a failure - a `status` that stopped there would
    # hide everything above it.
    #
    # Three answers are spelled out rather than one with a fallback, because the
    # obvious short form is wrong: in jq, `//` treats false as absent, so
    # `.loggedIn // "unknown"` answers "unknown" for a `loggedIn: false` - which
    # is exactly what a fresh instance, logged in nowhere, reports.
    local auth answer
    auth=$(claude auth status 2>/dev/null || true)
    answer=$(printf '%s' "$auth" |
        jq -r 'if .loggedIn == true then "yes" elif .loggedIn == false then "no" else "unknown" end' 2>/dev/null || true)
    case "$answer" in
        yes) echo "  login      yes" ;;
        no)  echo "  login      no — the first session asks you to log in" ;;
        *)   echo "  login      unknown — 'claude auth status' had nothing to say" ;;
    esac

    echo ""
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
