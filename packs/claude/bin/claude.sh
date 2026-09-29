#!/usr/bin/env bash
# ==============================================================================
# CLAUDE CODE - WHAT THE gmake TARGETS CALL
# ==============================================================================
# The subcommands, one per target in make/claude.mk, and the same split as the
# tunnel's bin/vpn.sh: what needs a terminal (a menu) or a decision (which
# provider is in force) lives here rather than inside a recipe, so each recipe
# stays one line and this file is read like any other shell script.
#
# Three files hold this half of the pack:
#
#   ~/.config/claude/profiles.json   your providers: one entry per endpoint, with
#                                    its own token. Yours - the pack seeds it from
#                                    its sample, and never writes in it again.
#                                    Mode 600: the tokens go in there.
#   ~/.config/zsh/gmake/.env.global  CLAUDE_PROFILE, the entry in use. The socle
#                                    loads this file into every gmake run, and
#                                    `gmake env_global_enable` merges the pack's
#                                    line into it.
#   ~/.claude/settings.json          NOT a file the pack keeps: it is the CLI's
#                                    own, and what this writes in it is the env
#                                    block - the keys the dictionary declares and
#                                    no others. Everything else in that file
#                                    (statusLine, permissions, your own
#                                    CLAUDE_CODE_*) is not looked at, and the
#                                    pack's removal takes its keys back out.
#
# Why settings.json at all: a variable exported by a shell only reaches what that
# shell starts, and the CLI reads its own settings file whatever launches it. A
# profile written there is the one every session obeys, however it is started -
# the whole point of the exercise.
#
# One file the pack only READS: ~/.claude/projects, the CLI's own store of the
# folders a session has run in - one directory per folder, a file per session.
# `claude_project` lists them from there and opens the one chosen; nothing here
# ever writes in it.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
SAMPLE=$here/../profiles.sample

PROFILES=$HOME/.config/claude/profiles.json
SETTINGS=$HOME/.claude/settings.json
GLOBAL_ENV=$HOME/.config/zsh/gmake/.env.global
PROJECTS_STORE=$HOME/.claude/projects

# Where the pack put the program, named before anything looks for it - called by
# make the PATH is zsh's, which has ~/.local/bin, but called by hand from a shell
# that has not read the zsh configuration it is not, and the answer would be "not
# installed" about a program that is right there. A pack knows what it installed;
# it does not ask the caller's shell.
export PATH="$HOME/.local/bin:$PATH"

# The program, at the path this pack installs it to - and not whatever `claude`
# the PATH resolves to, which is a different question with a different answer.
# WSL appends the Windows directories to the PATH, so a Claude Code installed on
# Windows is found from inside the instance: reported as this instance's own,
# `gmake claude_status` would describe a program that runs on the other side of
# the wall, and the "not installed" branch would never be reached. Measured on a
# real instance, and the reason install.sh tests the same path.
launcher=$HOME/.local/bin/claude
claude_bin=""
[ -x "$launcher" ] && claude_bin=$launcher

# What the PATH finds instead, when it finds something else. Named only, never
# used: the person will type `claude` and see it answer, and the message that
# says the pack's own is missing has to say why.
foreign_bin=$(command -v claude 2>/dev/null || true)
[ "$foreign_bin" = "$launcher" ] && foreign_bin=""

# What an id may be. It names a provider in the menus, and it is written into
# .env.global, where make reads it: a space would be trimmed, a `#` would cut the
# line short and an `=` would end the name. So letters, digits, dot, dash and
# underscore.
VALID_ID='^[A-Za-z0-9._-]+$'

die() {
    printf '❌ %s\n' "$*" >&2
    exit 1
}

# --- the dictionary -----------------------------------------------------------

# jq reads it, and nothing greps inside it: a structured file is read by a tool
# that knows the structure, and one that does not parse is an error with a line
# number rather than a wrong value. jq is in the image, like the rest of what
# this pack leans on.
json_ok() {
    [ -f "$PROFILES" ] && jq -e . "$PROFILES" > /dev/null 2>&1
}

# Every id, one per line, in the file's order: what the menus show.
ids() {
    [ -f "$PROFILES" ] || return 0
    jq -r '(.profiles // [])[] | .id // empty' "$PROFILES" 2>/dev/null || true
}

# How many entries carry that id. It has to be exactly one: two entries with the
# same id are two answers to one question.
entries() {
    [ -f "$PROFILES" ] || { printf '0'; return 0; }
    jq -r --arg id "$1" '[ (.profiles // [])[] | select(.id == $id) ] | length' "$PROFILES" 2>/dev/null || printf '0'
}

valid_id() {
    printf '%s' "$1" | grep -qE "$VALID_ID"
}

# What a profile means: the entry itself, minus the two keys that are this
# file's own. Flat on purpose - the keys are the ones the CLI reads, so a block
# copied out of a settings file goes in as it stands, and the pack has no
# vocabulary of its own to translate. An entry with nothing but an id is the
# login route, and gives {} - which is what takes another provider's keys back
# out.
profile_env() {
    jq -c --arg id "$1" '(.profiles // [])[] | select(.id == $id) | del(.id, .note)' "$PROFILES" 2>/dev/null
}

# Every key the pack may have written in the settings file: everything the
# dictionary declares, plus the four the pack knows by name whatever the file
# says. Those four are pinned because an entry can be DELETED from the
# dictionary, and what it had written would otherwise stop being taken back - a
# base URL left behind with no credential is the one mistake this pack refuses
# to make. That list is what applying takes back before it writes, so a key one
# provider set cannot survive a switch to another, and nothing is kept anywhere
# to remember it. It is also what the pack's removal uses.
owned_keys() {
    {
        printf 'ANTHROPIC_BASE_URL\nANTHROPIC_AUTH_TOKEN\nANTHROPIC_API_KEY\nANTHROPIC_MODEL\n'
        if [ -f "$PROFILES" ]; then
            jq -r '(.profiles // [])[] | del(.id, .note) | keys[]' "$PROFILES" 2>/dev/null || true
        fi
    } | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))'
}

# The env block of the settings file, its pack-owned keys only, keys sorted so
# that two runs can be compared byte for byte.
applied_env() {
    [ -f "$SETTINGS" ] || { printf '{}'; return 0; }
    jq -S -c '(.env // {}) | with_entries(select(.key | startswith("ANTHROPIC_")))' "$SETTINGS" 2>/dev/null || printf '{}'
}

# Writing it. The settings file is the CLI's and the user's; what this replaces
# is the keys the dictionary declares, and it keeps everything else - the
# statusLine, the permissions, the user's own CLAUDE_CODE_* - untouched. Mode
# 600, because it now holds a token.
apply_env() {
    local want=$1 owned tmp dir
    owned=$(owned_keys)
    dir=$(dirname "$SETTINGS")
    install -d -m 0700 "$dir"
    tmp=$(mktemp)

    if [ ! -f "$SETTINGS" ]; then
        # Nothing to write and nothing to create: a fresh instance that picks the
        # login profile gets no settings file out of it.
        [ "$want" = "{}" ] && { rm -f "$tmp"; return 0; }
        jq -n --argjson add "$want" '{ env: $add }' > "$tmp"
    else
        if ! jq --argjson add "$want" --argjson owned "$owned" '
                (.env // {}) as $env
                | .env = (($env | with_entries(select(.key as $k | ($owned | index($k)) == null))) + $add)
                | if .env == {} then del(.env) else . end
            ' "$SETTINGS" > "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            die "$SETTINGS does not parse: $(jq . "$SETTINGS" 2>&1 | head -n 1)"
        fi
    fi

    chmod 600 "$tmp"
    mv "$tmp" "$SETTINGS"
    if [ "$want" = "{}" ]; then
        printf '📝 %s: the keys this pack owns were taken back out\n' "$SETTINGS"
    else
        printf '📝 %s: %s\n' "$SETTINGS" "$(printf '%s' "$want" | jq -r 'keys | join(", ")')"
    fi
}

# --- the variables ------------------------------------------------------------

env_var() {
    local line
    [ -r "$GLOBAL_ENV" ] || return 0
    line=$(grep -E "^[[:space:]]*$1=" "$GLOBAL_ENV" | tail -n 1 || true)
    printf '%s\n' "${line#*=}"
}

profile_var() {
    env_var CLAUDE_PROFILE
}

# Writing the one variable. That file is the socle's - make reads it, and `gmake
# env_global_enable` fills it in from the samples - so this writes one line of it
# and nothing else: the line is replaced where it is, or appended when the
# variable is not there yet (which is what a machine that never ran
# env_global_enable looks like). The value is an id, checked by valid_id before
# this is called: no byte of it needs escaping.
write_env() {
    local name=$1 value=$2
    [ -f "$GLOBAL_ENV" ] || die "no $GLOBAL_ENV yet - 'gmake env_global_enable' builds it from the samples."
    if grep -qE "^[[:space:]]*$name=" "$GLOBAL_ENV"; then
        sed -i -E "s|^[[:space:]]*$name=.*|$name=$value|" "$GLOBAL_ENV"
    else
        printf '\n%s=%s\n' "$name" "$value" >> "$GLOBAL_ENV"
    fi
    printf '📝 %s=%s (%s)\n' "$name" "$value" "$GLOBAL_ENV"
}

# --- the menu -----------------------------------------------------------------

# fzf, like the other pickers of this shell (fcheat, fnew, the tunnel's servers).
# It needs a terminal, and says which way round that is: a menu cannot be
# answered from a pipe or a script, and a provider can be named instead.
pick() {
    local list choice
    list=$(ids)
    [ -n "$list" ] || die "no provider in $PROFILES - gmake claude_edit_profiles opens it."
    if ! choice=$(printf '%s\n' "$list" | fzf --prompt="$1 > " --info=inline --layout=reverse); then
        die "no provider chosen - a menu needs a terminal. Name one instead: gmake claude_profile CLAUDE_PROFILE=<id>"
    fi
    [ -n "$choice" ] || die "no provider chosen."
    printf '%s\n' "$choice"
}

# --- the projects -------------------------------------------------------------

# $HOME spelled ~, and nothing else: a menu column - and the substitution
# reverses exactly, so the display never hides the value.
short_path() {
    case "$1" in
    "$HOME") printf '~' ;;
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
    esac
}

# One line per project of this instance, most recently used first, shaped for
# fzf:  <path> TAB <last session>  <short path>
#
# The path is the first field and the only one that matters; fzf shows what is
# left of the tab (--with-nth) and prints the chosen line back whole, so
# `cut -f1` reads the path again.
#
# From where: ~/.claude/projects, one directory per folder a session has run in.
# The directory's NAME is an encoding of the path that cannot be decoded back (a
# dash is a dash in a folder's name too), so the path is read INSIDE the files:
# every session entry carries its cwd. A folder that is gone from the disk is
# not offered - there would be nothing to open - and neither is a directory
# whose files never name a cwd.
project_lines() {
    local dir newest cwd epoch when
    [ -d "$PROJECTS_STORE" ] || return 0

    for dir in "$PROJECTS_STORE"/*/; do
        [ -d "$dir" ] || continue
        # The newest session of that folder: when the project was last used, and
        # any of its files answers the same cwd. `find` and not `ls` - shellcheck
        # is right that a name says nothing about a filename, even here where
        # the names come from the CLI - and the whole read is guarded because
        # set -e is on: `head` closes a long pipe early (SIGPIPE), and no match
        # at all is not an error worth stopping for.
        newest=$(find "${dir%/}" -maxdepth 1 -type f -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null |
            sort -rn | head -n 1 | cut -d' ' -f2- || true)
        [ -n "$newest" ] || continue
        cwd=$(jq -r 'select(.cwd) | .cwd' "$newest" 2>/dev/null | head -n 1 || true)
        [ -n "$cwd" ] || continue
        [ -d "$cwd" ] || continue
        epoch=$(date -r "$newest" +%s 2>/dev/null || echo 0)
        when=$(date -r "$newest" '+%Y-%m-%d %H:%M' 2>/dev/null || true)
        printf '%s\t%s\t%s  %s\n' "$epoch" "$cwd" "$when" "$(short_path "$cwd")"
    done | sort -rn -k1,1 | cut -f2-
}

# fzf, the same picker as the provider menu, and the same demand: a menu needs a
# terminal. There is no name to fall back on here - the list IS the interface -
# so a refusal is just a refusal.
pick_project() {
    local choice
    if ! choice=$(printf '%s\n' "$1" | fzf --prompt='The project to open > ' --info=inline --layout=reverse --with-nth=2..); then
        die "no project chosen."
    fi
    [ -n "$choice" ] || die "no project chosen."
    printf '%s\n' "$choice" | cut -f1
}

# --- the targets --------------------------------------------------------------

# Choosing a provider: the id into .env.global, and what it means into the
# settings file. Both, always, in that order - the variable is the memory of the
# choice and the settings are the choice taking effect.
cmd_profile() {
    local wanted=${1:-} want has_url has_key

    if [ -z "$wanted" ]; then
        wanted=$(pick "The provider to use")
    fi
    valid_id "$wanted" || die "'$wanted' cannot be a provider id: letters, digits, dot, dash and underscore only."
    if ! json_ok; then
        die "no usable $PROFILES - gmake claude_edit_profiles creates it from the sample."
    fi
    case "$(entries "$wanted")" in
    1) ;;
    0) die "no provider '$wanted' in $PROFILES. It holds: $(ids | paste -sd' ' -). gmake claude_edit_profiles opens it." ;;
    *) die "'$wanted' appears more than once in $PROFILES - one entry per provider. gmake claude_edit_profiles opens it." ;;
    esac

    want=$(profile_env "$wanted")
    [ -n "$want" ] || die "could not read the profile '$wanted' out of $PROFILES."

    # The one mistake that costs something: a base URL and no credential. The CLI
    # sends whatever credential it has to that address, and the one it always has
    # is your claude.ai login - the header leaves with the OAuth in it. Refused
    # rather than written.
    has_url=$(printf '%s' "$want" | jq -r 'has("ANTHROPIC_BASE_URL")')
    has_key=$(printf '%s' "$want" | jq -r 'has("ANTHROPIC_AUTH_TOKEN") or has("ANTHROPIC_API_KEY")')
    if [ "$has_url" = "true" ] && [ "$has_key" != "true" ]; then
        die "the provider '$wanted' carries a base URL and no credential: it would send your claude.ai login to that address. Add an ANTHROPIC_AUTH_TOKEN to it (or an ANTHROPIC_API_KEY) - gmake claude_edit_profiles opens the file."
    fi

    write_env CLAUDE_PROFILE "$wanted"
    apply_env "$want"

    if [ "$want" = "{}" ]; then
        printf 'ℹ️  Nothing is written for it: the settings and the login decide. That is the subscription route.\n'
    else
        printf 'ℹ️  It applies now, and to every session, however you start one.\n'
    fi
}

cmd_edit_profiles() {
    local editor

    if [ ! -f "$PROFILES" ]; then
        install -d -m 0700 "$(dirname "$PROFILES")"
        install -m 600 "$SAMPLE" "$PROFILES"
        printf '📝 %s was created from the package sample - fill in your tokens.\n' "$PROFILES"
    fi
    if ! json_ok; then
        die "$PROFILES does not parse, and this will not open a broken file: $(jq . "$PROFILES" 2>&1 | head -n 1)"
    fi

    printf 'ℹ️  One entry per provider: the id, then the environment Claude Code\n'
    printf '   reads - the same names as in settings.json, so a block you already\n'
    printf "   have can be pasted as it stands. An entry with only an id is this\n"
    printf "   instance's own login. A base URL with no credential is refused.\n"

    # The editor is yours: $EDITOR when it is set (one command, no arguments),
    # nano otherwise - nano is in the image, and it is what the cheatsheets use.
    editor=${EDITOR:-nano}
    eval "$editor \"\$PROFILES\""

    # What the editor left behind. jq says where and why when it does not parse;
    # the ids are checked too, since they are what a menu shows and what
    # .env.global carries. Nothing is read from the file until both hold.
    if ! json_ok; then
        printf '⚠️  %s does not parse any more: %s\n' "$PROFILES" "$(jq . "$PROFILES" 2>&1 | head -n 1)" >&2
        printf '   gmake claude_edit_profiles opens it again - nothing is read from it until it does.\n' >&2
        return 1
    fi
    while read -r id; do
        [ -n "$id" ] || continue
        if ! valid_id "$id"; then
            printf "❌ %s: the id '%s' cannot be used - letters, digits, dot, dash and underscore only.\n" "$PROFILES" "$id" >&2
            return 1
        fi
        if [ "$(entries "$id")" != 1 ]; then
            printf "❌ %s: '%s' appears %s times - one entry per provider.\n" "$PROFILES" "$id" "$(entries "$id")" >&2
            return 1
        fi
    done < <(ids)
    printf '✅ %s: %s\n' "$PROFILES" "$(ids | paste -sd' ' -)"

    # And now the provider to use, straight away: a token rotated in the file is
    # the one the next session uses, and a menu over the list the file holds
    # cannot leave a name that no longer exists in CLAUDE_PROFILE.
    #
    # Only with a terminal: a test or a script runs this with EDITOR=true, and a
    # menu has nothing to ask with there - the edit stands on its own.
    if [ -t 0 ] && [ -t 1 ]; then
        cmd_profile
    fi
}

# Opening one: the launcher, in that folder, on the last conversation of that
# folder. Every project in the list is there because a session has run in it, so
# there is always one to continue - the list answers "resume if there is one" by
# itself. `exec`: the session replaces this script, and make waits on the
# session, not on a wrapper.
cmd_project() {
    local list cwd

    [ -n "$claude_bin" ] || die "Claude Code is not installed in this instance - bash ~/.config/packs/claude/install.sh puts it back."

    list=$(project_lines)
    if [ -z "$list" ]; then
        printf 'This instance has no project yet: one appears here once a session has run in its folder.\n'
        return 0
    fi

    cwd=$(pick_project "$list")
    [ -d "$cwd" ] || die "$cwd is gone - it was removed after the list was read."
    cd "$cwd" || die "cannot enter $cwd."
    exec "$claude_bin" --continue
}

# --- the status ---------------------------------------------------------------

# What the settings will present to the endpoint, read in the order the CLI reads
# it: the env block of its own settings file comes first - a settings file beats
# the shell, that is documented - and the environment after it. Only the NAME of
# the variable is ever printed, never its value: a status that showed a key would
# be a leak with a friendly face.
access() {
    local name="" where=""

    if [ -f "$SETTINGS" ]; then
        name=$(jq -r '(.env // {}) | if has("ANTHROPIC_AUTH_TOKEN") then "ANTHROPIC_AUTH_TOKEN" elif has("ANTHROPIC_API_KEY") then "ANTHROPIC_API_KEY" else empty end' "$SETTINGS" 2>/dev/null || true)
        [ -n "$name" ] && where="in $SETTINGS"
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

# Where the requests go, from the same place as the key above.
endpoint() {
    local url=""

    if [ -f "$SETTINGS" ]; then
        url=$(jq -r '(.env // {}).ANTHROPIC_BASE_URL // empty' "$SETTINGS" 2>/dev/null || true)
    fi
    [ -z "$url" ] && url=${ANTHROPIC_BASE_URL:-}

    if [ -n "$url" ]; then
        echo "  endpoint   $url"
    else
        echo "  endpoint   the Anthropic API — no ANTHROPIC_BASE_URL set"
    fi
}

# Which provider is named, and whether what the settings hold is what that
# provider says - the second half is the one worth having: it catches a token
# rotated in the dictionary and not applied, and a settings file edited by hand
# under the pack's feet.
profile_line() {
    local id applied want

    id=$(profile_var)
    applied=$(applied_env)

    if [ -z "$id" ]; then
        if [ "$applied" = "{}" ]; then
            echo "  provider   none — gmake claude_profile picks one"
        else
            echo "  provider   none named — the settings hold a provider of their own"
        fi
        return
    fi
    if ! json_ok || [ "$(entries "$id")" != 1 ]; then
        echo "  provider   $id — no such entry in $PROFILES"
        return
    fi
    want=$(profile_env "$id" | jq -S -c .)
    if [ "$want" = "$applied" ]; then
        echo "  provider   $id — applied"
    else
        echo "  provider   $id — NOT applied, the settings hold something else"
        echo "             gmake claude_profile CLAUDE_PROFILE=$id writes it"
    fi
}

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
        if [ -n "$foreign_bin" ]; then
            # The case a WSL instance hits as soon as Windows has one: typing
            # `claude` works, and it is not this one. One line, because it is
            # the surprise that needs saying, not the story behind it.
            echo "     Your PATH finds $foreign_bin instead - that one runs on Windows."
        fi
        echo "     Put the pack's own back:  bash ~/.config/packs/claude/install.sh"
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
    if [ -d "$HOME/.local/share/claude/versions" ]; then
        local count size
        count=$(find "$HOME/.local/share/claude/versions" -maxdepth 1 -type f 2>/dev/null | wc -l)
        size=$(du -sh "$HOME/.local/share/claude/versions" 2>/dev/null | cut -f1)
        echo "  versions   $count on disk, $size — $HOME/.local/share/claude/versions"
    fi

    # The settings, the credentials, the history and the sessions: what the CLI
    # writes for itself, and what a removal leaves where it is.
    if [ -d "$HOME/.claude" ]; then
        echo "  config     $HOME/.claude"
    else
        echo "  config     none yet — the first session writes it"
    fi

    profile_line
    access
    endpoint

    echo ""
}

case "${1:-}" in
    status)
        status
        ;;
    profile)
        shift
        cmd_profile "${1:-}"
        ;;
    edit_profiles)
        cmd_edit_profiles
        ;;
    project)
        cmd_project
        ;;
    *)
        echo "Usage: $(basename "$0") <status|profile|edit_profiles|project>" >&2
        exit 2
        ;;
esac
