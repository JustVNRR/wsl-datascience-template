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
#   - no marker (/etc/wireguard/auto) or a profile that is gone: it does nothing
#     and says so in its log;
#   - the network is not always up when WSL runs this line, and wg-quick has to
#     resolve the endpoint: it tries again a few times before giving up;
#   - it always exits 0 - a failure here would be a boot that hangs, and there is
#     nothing to hang for.
# What it did is written to /var/log/web-vpn.log, and `gmake vpn_status` reads
# the last line of it.

set -u

WG_DIR=/etc/wireguard
MARKER=$WG_DIR/auto
LOG=/var/log/web-vpn.log
TRIES=6
WAIT=5

log() {
    printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG"
}

# No marker: the pack was never told to start anything, which is the normal
# state of a fresh install.
[ -r "$MARKER" ] || exit 0

profile=$(head -n 1 "$MARKER" | tr -d '[:space:]')
[ -n "$profile" ] || exit 0

if [ ! -f "$WG_DIR/$profile.conf" ]; then
    log "❌ $profile: the marker names a profile that is not in $WG_DIR - nothing was started."
    exit 0
fi

# Already up (a session started it, or the marker was just set): leave it alone.
if /usr/bin/wg show interfaces 2>/dev/null | grep -qw "$profile"; then
    exit 0
fi

try=1
while [ "$try" -le "$TRIES" ]; do
    if /usr/bin/wg-quick up "$profile" >> "$LOG" 2>&1; then
        log "✅ $profile is up (attempt $try)."
        exit 0
    fi
    try=$((try + 1))
    [ "$try" -le "$TRIES" ] && sleep "$WAIT"
done

log "❌ $profile: gave up after $TRIES attempts - 'gmake vpn_up' will say more."
exit 0
