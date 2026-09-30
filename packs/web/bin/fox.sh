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
# What is being set, and why each of it, is the pack's page (docs/fox.md).

set -euo pipefail

# The one file these targets touch, and the whole state: the file is there, or
# it is not. FOX_PREF_FILE is what a test points at a stand-in copy.
PREF_FILE=${FOX_PREF_FILE:-/usr/lib/firefox/defaults/pref/fox-privacy.js}
PREF_DIR=$(dirname "$PREF_FILE")

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

# The file, whole, on every call: it is the pack's copy, and the header says so
# where someone opening it would look.
write_prefs() {
    as_root tee "$PREF_FILE" > /dev/null <<'PREF'
// Set by the web pack - `gmake fox_tweak_on` wrote it, `gmake fox_tweak_off`
// takes it back. These are DEFAULT values, not orders: they apply to every
// profile, and a value set in about:config wins over them. What each one does,
// and what it changes while browsing, is in docs/fox.md.

// --- Tracking protection: the Strict preset, named pref by pref ---
// (the category line is what the Settings page shows; the engines read the
// prefs, so both are set)
pref("browser.contentblocking.category", "strict");
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.fingerprinting.enabled", true);
pref("privacy.trackingprotection.cryptomining.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.trackingprotection.emailtracking.enabled", true);

// --- Tracking parameters stripped from URLs, in every window ---
pref("privacy.query_stripping.enabled", true);
pref("privacy.query_stripping.enabled.pbmode", true);

// --- Clicks and pages that would phone home ---
pref("browser.send_pings", false);
pref("beacon.enabled", false);

// --- Connections a page did not ask for ---
pref("network.prefetch-next", false);
pref("network.dns.disablePrefetch", true);

// --- TLS and DNS ---
// HTTPS-only in every window: a site served over plain http gets a warning
// page with a way through. DoH is off on purpose - the DNS of this instance is
// the tunnel's business (docs/vpn.md), and Firefox answering it itself would
// step around the tunnel.
pref("dom.security.https_only_mode", true);
pref("network.trr.mode", 5);

// --- What a page may read of the machine ---
// No camera/microphone enumeration (WSLg serves neither), and geolocation
// denied by default - one site can still be allowed through the padlock.
pref("media.navigator.enabled", false);
pref("permissions.default.geo", 2);

// --- Telemetry, studies, and the do-not-sell signal ---
pref("datareporting.healthreport.uploadEnabled", false);
pref("app.shield.optoutstudies.enabled", false);
pref("privacy.globalprivacycontrol.enabled", true);

// --- Anti-fingerprinting (the big switch: it changes what sites see) ---
// Time zone UTC, language en-US, a generic user-agent, canvas noise - and the
// letterboxing, which standardizes the window's size (grey margins around
// pages until the window matches a standard shape).
pref("privacy.resistFingerprinting", true);
pref("privacy.resistFingerprinting.letterboxing", true);

// --- WebRTC off ---
// No real-time connections from a page: this instance has no camera, and an
// in-browser call is a leak this browser does not need.
pref("media.peerconnection.enabled", false);
PREF
    # Readable by every user, writable by root: the shape the sound preference
    # has, and what Firefox expects of a defaults file.
    as_root chmod 0644 "$PREF_FILE"
}

cmd_on() {
    [ -d "$PREF_DIR" ] ||
        die "no $PREF_DIR: Firefox is not installed here - it arrives from Windows (.\wsl.ps1 add_pack)."

    local was=no
    if [ -f "$PREF_FILE" ]; then
        was=yes
    fi

    write_prefs

    if [ "$was" = yes ]; then
        printf 'The privacy defaults were already in place - the file is written again from the pack copy.\n'
    else
        printf 'The privacy defaults are in place: %s\n' "$PREF_FILE"
    fi
    printf '   Defaults, not orders: a value set in about:config wins over them.\n'
    printf '   Close and reopen Firefox for them to apply.\n'
    printf '   Sites will see en-US and UTC, and pages are letterboxed - the anti-fingerprinting trade, in docs/fox.md.\n'
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
                        its own - every profile, and about:config still wins
  off                   take the file back - the browser's own defaults again

Both are gmake targets of the same name: gmake fox_tweak_on, fox_tweak_off.
USAGE
    exit 2
    ;;
esac
