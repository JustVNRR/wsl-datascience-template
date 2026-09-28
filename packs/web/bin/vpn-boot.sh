#!/usr/bin/env bash
# ==============================================================================
# THE TUNNEL AT DISTRO START - WHAT WSL'S [boot] HOOK RUNS
# ==============================================================================
# The pack's page says why this is not a systemd unit: this image declares
# systemd=true in /etc/wsl.conf, but WSL boots systemd by running /sbin/init,
# and the systemd package alone does not provide it (that is systemd-sysv). So
# `systemctl enable` answers "System has not been booted with systemd" here,
# and the hook WSL does offer - `command=` under `[boot]` - is the one that
# works, with no unit, no timer and no journal.
#
# It is copied to /usr/local/sbin by `gmake vpn_auto_on`, runs as root, and
# must never hold the distro back:
#   - which server, and whether there is a kill switch, are not decided here:
#     they are VPN_PROFILE and VPN_KILL_SWITCH in the user's .env.global, and the
#     pack's own script writes the profile out of them. This file finds the
#     instance's user and calls it - the boot path and the `gmake vpn_up` path are
#     the same code, so the profile cannot be stale when the tunnel comes up;
#   - the network is not always up when WSL runs this line, and wg-quick has to
#     resolve the endpoint: it tries again a few times before giving up;
#   - it always exits 0 - a failure here would be a boot that hangs, and there is
#     nothing to hang for.
# What it did is written to /var/log/web-vpn.log, and `gmake vpn_status` reads
# the last line of it.

set -u

LOG=/var/log/web-vpn.log
TRIES=6
WAIT=5
WSLCONF=/etc/wsl.conf

log() {
    printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG"
}

# The instance's user, and therefore the home whose .config holds the pack, the
# JSON and .env.global. This runs as root, so $HOME is /root and says nothing:
# the home has to be found, and /etc/wsl.conf is where the instance declares it
# ([user] default=) - the same declaration the user's own session starts with, so
# it is the one the tunnel must be raised for. When that names nobody, the pack's
# own folder is what tells one home from another. Nothing is written down here:
# change the user, or the server in .env.global, and the next start follows.
home_of_user() {
    local user home
    user=$(sed -n 's/^[[:space:]]*default[[:space:]]*=[[:space:]]*//p' "$WSLCONF" 2>/dev/null | head -n 1)
    if [ -n "$user" ]; then
        home=$(awk -F: -v u="$user" '$1 == u { print $6; exit }' /etc/passwd)
        if [ -n "$home" ] && [ -x "$home/.config/packs/web/bin/vpn.sh" ]; then
            printf '%s\n' "$home"
            return 0
        fi
    fi
    for home in /home/*; do
        if [ -x "$home/.config/packs/web/bin/vpn.sh" ]; then
            printf '%s\n' "$home"
            return 0
        fi
    done
    return 1
}

home=$(home_of_user) || {
    log "⚠️  no home carries the web pack - nothing was started."
    exit 0
}

# Already up: a session raised it, or this ran twice. Leave it alone.
if /usr/bin/wg show interfaces 2>/dev/null | grep -qx vpn; then
    exit 0
fi

try=1
while [ "$try" -le "$TRIES" ]; do
    # HOME, because the pack's script reads the user's files from it - the JSON of
    # servers and the two variables, of which the .env.global holds the server to
    # start. Handing it the home is the whole of what makes this call the same run
    # as `gmake vpn_up`, with the user's own files and the same decisions.
    if HOME="$home" "$home/.config/packs/web/bin/vpn.sh" up >> "$LOG" 2>&1; then
        log "✅ the tunnel is up (attempt $try)."
        exit 0
    fi
    try=$((try + 1))
    [ "$try" -le "$TRIES" ] && sleep "$WAIT"
done

log "❌ gave up after $TRIES attempts - 'gmake vpn_up' will say more."
exit 0
