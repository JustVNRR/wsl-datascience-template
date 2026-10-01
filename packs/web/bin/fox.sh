#!/usr/bin/env bash
# ==============================================================================
# FIREFOX - THE PRIVACY SETTINGS - WHAT THE LAUNCHERS AND THE TARGETS CALL
# ==============================================================================
# Two sets, two launchers, two manual commands:
#
#   fox-privacy-light.js    everything invisible: tracking protection, URL
#                           cleaning, telemetry off, HTTPS-only, DoH off,
#                           geolocation denied. What `fox` puts in place, and
#                           what the pack's install leaves.
#   fox-privacy-strict.js   the light set, plus anti-fingerprinting (RFP and
#                           letterboxing) and WebRTC off - the two that are
#                           noticed day to day. What `pfox` puts in place.
#
# One set is ever in place, and it is a file of DEFAULT preferences, not
# orders:
#   - a default applies to every profile, present and future - no profile name
#     to guess, and a new one inherits it with nothing to do;
#   - a value set in about:config wins over it, so a site that needs one of
#     them relaxed is a one-line exception, not a fight with a lock;
#   - `off` is everything leaving: Firefox is back to its own defaults - no
#     prefs.js to rewrite, nothing half-applied.
#
# And choosing a set costs no password: the browser's directory holds a LINK -
# /usr/lib/firefox/defaults/pref/fox-privacy.js, pointing at
# $HOME/.config/fox-privacy.js - and a set is put in place by replacing THAT
# file, which lives in the user's home. Only the link's creation (once - the
# install does it, the first run as a fallback) and `off` go through sudo.
#
# A `user.js` in a profile would force the values instead, and it is the
# arrangement this pack did not choose: the profile only exists after a first
# launch, a running Firefox has to be refused, and taking one value back means
# editing prefs.js by hand. All of that for a strength this file does not need:
# there is one user here, and about:config is theirs to use.
#
# What is in each set, and why each line, is the pack's page (docs/fox.md).

set -euo pipefail

# The link Firefox reads, and the file it points at: those two are the whole
# state. FOX_PREF_FILE is what a test points at a stand-in copy.
PREF_FILE=${FOX_PREF_FILE:-/usr/lib/firefox/defaults/pref/fox-privacy.js}
PREF_DIR=$(dirname "$PREF_FILE")
SLOT=$HOME/.config/fox-privacy.js

# The sets themselves, beside this script in the pack.
here=$(cd "$(dirname "$0")" && pwd)

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

# Privileged work: /usr/lib/firefox belongs to the package, so the link and
# anything removed from there go through sudo - and run as root (the day a
# test does), sudo would be one indirection too many. The same shape vpn.sh's
# as_root has.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# The link, in place and pointing at the slot. Asked before every switch, and
# answered WITHOUT any sudo first: a launch where it is already right must
# not cost a password. `ln -sfn` replaces whatever is there - the plain file
# of the pack's first shape included, which is the migration.
ensure_link() {
    [ -d "$PREF_DIR" ] ||
        die "no $PREF_DIR: Firefox is not installed here - it arrives from Windows (.\wsl.ps1 add_pack)."
    if [ -L "$PREF_FILE" ] && [ "$(readlink -- "$PREF_FILE")" = "$SLOT" ]; then
        return 0
    fi
    as_root ln -sfn "$SLOT" "$PREF_FILE" ||
        die "the link could not be written to $PREF_FILE"
}

# One of the two sets, in the slot. Copies only when the slot holds something
# else, so the ordinary launch writes nothing. Answers 0 when it changed
# something, 1 when the slot already held it - both are a success.
#
# Every write is checked, and that is not decoration: put_set runs inside `if`
# conditions (use, cmd_on), where bash suspends `set -e` - an unchecked `cp`
# that failed would be reported as "in place" the step after (measured, in the
# harness: a missing ~/.config and a full four-line lie).
put_set() {
    local src=$here/../fox-privacy-$1.js
    [ -f "$src" ] ||
        die "no $src: the pack's copy of the $1 set is missing - put the pack's folder back (.\wsl.ps1 add_pack)."
    ensure_link
    if [ -f "$SLOT" ] && cmp -s "$src" "$SLOT"; then
        return 1
    fi
    install -d "$(dirname "$SLOT")"
    cp "$src" "$SLOT" ||
        die "the $1 set could not be written to $SLOT"
    return 0
}

# What the launchers call: silent when there is nothing to change, one line
# when the set in place changes under them.
use() {
    if put_set "$1"; then
        printf 'The %s privacy settings are in place - Firefox reads them as it starts.\n' "$1"
    fi
}

# The manual switch: the strict set, and it says so even when it changed
# nothing (the file path is where the set now lives).
cmd_on() {
    if put_set strict; then
        printf 'The privacy settings are in place: %s\n' "$SLOT"
    else
        printf 'The privacy settings are in place.\n'
    fi
}

cmd_off() {
    if [ ! -e "$PREF_FILE" ] && [ ! -e "$SLOT" ]; then
        printf 'Nothing to remove: the privacy settings are not in place.\n'
        return 0
    fi

    as_root rm -f "$PREF_FILE"
    rm -f "$SLOT"

    printf 'The privacy settings are removed - Firefox is back to its own.\n'
    printf '   Close and reopen Firefox for that to take effect.\n'
}

case "${1:-}" in
on) cmd_on ;;
off) cmd_off ;;
light) use light ;;
strict) use strict ;;
*)
    cat <<'USAGE'
usage: fox.sh <command>

  light                 put the light privacy settings in place - what `fox`
                        runs at every launch; silent when nothing changes
  strict                put the strict ones in place - what `pfox` runs
  on                    the strict ones, and it says so (gmake fox_tweak_on)
  off                   take everything out - the browser's own defaults again
                        (gmake fox_tweak_off)

The first switch sets the link up (one sudo, once); after that a switch costs
no password, and about:config still wins over both sets. docs/fox.md tells
what each set holds.
USAGE
    exit 2
    ;;
esac
