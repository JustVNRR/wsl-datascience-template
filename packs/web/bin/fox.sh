#!/usr/bin/env bash
# ==============================================================================
# FIREFOX - THE PRIVACY DEFAULTS - WHAT THE gmake TARGETS CALL
# ==============================================================================
# Two subcommands, one per target in make/fox.mk, and one file: in the
# browser's own directory, where install.sh already leaves wslg-audio.js - see
# install.sh for why the pack touches that directory at all.
#
# The file holds DEFAULT preferences, not orders, and that is the whole design:
#   - a default applies to every profile, present and future - no profile name
#     to guess, and a new one inherits it with nothing to do;
#   - a value set in about:config wins over it, so a site that needs one of
#     them relaxed is a one-line exception, not a fight with a lock;
#   - `off` is the file leaving: Firefox is back to its own defaults - no
#     prefs.js to rewrite, nothing half-applied.
#
# A `user.js` in a profile would force the values instead, and it is the
# arrangement this pack did not choose: the profile only exists after a first
# launch, a running Firefox has to be refused, and taking one value back means
# editing prefs.js by hand. All of that for a strength this file does not need:
# there is one user here, and about:config is theirs to use.
#
# `on` compares before it writes: identical file, nothing done, no password
# asked. That is what lets `pfox` - the shell function beside `fox` in
# web.zsh - run this first at every launch and stay a one-word command.
#
# What is being set, and why each of it, is the pack's page (docs/fox.md).

set -euo pipefail

# The one file these targets touch, and the whole state: the file is there, or
# it is not. FOX_PREF_FILE is what a test points at a stand-in copy.
PREF_FILE=${FOX_PREF_FILE:-/usr/lib/firefox/defaults/pref/fox-privacy.js}
PREF_DIR=$(dirname "$PREF_FILE")

# The preferences themselves, beside this script in the pack: a .js file, so
# that it is read like what it is - the very file Firefox reads - and not a
# heredoc to be rebuilt here. `on` installs it as it stands.
here=$(cd "$(dirname "$0")" && pwd)
PACK_COPY=$here/../fox-privacy.js

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

# Privileged work: /usr/lib/firefox belongs to the package, so the write and
# the removal go through sudo - and run as root (the day a test does), sudo
# would be one indirection too many. The same shape vpn.sh's as_root has.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# The pack's copy goes in whole, and `install` is what sets the mode on the
# way: 0644 - readable by every user, writable by root, the shape the sound
# preference has and what Firefox expects of a defaults file.
write_prefs() {
    as_root install -m 0644 "$PACK_COPY" "$PREF_FILE"
}

# Is the installed file already exactly the pack's copy? Both are 0644, so the
# question is answered as the user - and answered before any sudo. This is
# what makes an `on` that has nothing to do cost nothing.
prefs_are_current() {
    cmp -s "$PACK_COPY" "$PREF_FILE"
}

cmd_on() {
    [ -d "$PREF_DIR" ] ||
        die "no $PREF_DIR: Firefox is not installed here - it arrives from Windows (.\wsl.ps1 add_pack)."
    [ -f "$PACK_COPY" ] ||
        die "no $PACK_COPY: the pack's copy of the preferences is missing - put the pack's folder back (.\wsl.ps1 add_pack)."

    if [ -f "$PREF_FILE" ] && prefs_are_current; then
        printf 'The privacy settings are in place.\n'
        return 0
    fi

    write_prefs

    printf 'The privacy settings are in place: %s\n' "$PREF_FILE"
}

cmd_off() {
    if [ ! -f "$PREF_FILE" ]; then
        printf 'Nothing to remove: the privacy defaults are not in place.\n'
        return 0
    fi

    as_root rm -f "$PREF_FILE"

    printf 'The privacy defaults are removed - Firefox is back to its own.\n'
    printf '   Close and reopen Firefox for that to take effect.\n'
}

case "${1:-}" in
on)
    shift
    cmd_on "$@"
    ;;
off)
    shift
    cmd_off "$@"
    ;;
*)
    cat <<'USAGE'
usage: fox.sh <command>

  on                    write the pack's privacy defaults, where Firefox reads
                        its own - every profile, and about:config still wins.
                        An identical file is left alone, no password asked
  off                   take the file back - the browser's own defaults again

Both are gmake targets of the same name: gmake fox_tweak_on, fox_tweak_off.
pfox, in web.zsh, runs `on` and then opens a private window.
USAGE
    exit 2
    ;;
esac
