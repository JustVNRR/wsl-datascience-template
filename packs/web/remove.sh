#!/usr/bin/env bash
# ==============================================================================
# THE WEB PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it, and only that.
#
# The tunnel first, then the packages, then Mozilla's repository: a tunnel still
# up while its tools are being taken away is a half-removed state, and the boot
# hook would try to raise it at the next start - so the hook goes, and the
# tunnel with it.
#
# One package at a time, because a package another installed pack still claims
# must stay where it is: a pack does not own what it installs, it is one of the
# claimants. The claim is read from every pack's declaration - pack.conf, and
# install.sh as well, for a pack written before PACK_PACKAGES existed. A pack
# that is gone claims nothing: the last one to want a package takes it away.
#
# Two things this never does: remove a library (a neighbour's program may depend
# on it, and apt would take that program along), and autoremove (the shared
# libraries Firefox pulled in are not ours to judge - `remove_pack` takes them
# back with a question the whole instance answers).

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
declared=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$declared" ]; then
    echo "❌ No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

# Is this package claimed by another pack that is still installed?
claimed_elsewhere() {
    grep -rl --include=pack.conf --include=install.sh -- "$1" "$HOME/.config/packs" 2>/dev/null |
        grep -qv "^${here}/"
}

echo "➖ Taking the tunnel down, and removing its boot hook..."
"$here/bin/vpn.sh" auto off
"$here/bin/vpn.sh" down

echo "➖ Removing the tunnel and the browser..."
for package in $declared; do
    if claimed_elsewhere "$package"; then
        echo "⏭️  $package: another installed pack claims it - left in place."
        continue
    fi
    if [ "$package" = openresolv ]; then
        # No candidate in Ubuntu 24.04: it came from Debian's package (see
        # install.sh), so it goes back the same way.
        sudo dpkg -r openresolv
        continue
    fi
    sudo apt-get remove -y "$package"
done

echo "➖ Removing Mozilla's repository..."
sudo rm -f /etc/apt/sources.list.d/mozilla.list \
           /etc/apt/preferences.d/mozilla \
           /etc/apt/preferences.d/firefox-no-snap \
           /etc/apt/keyrings/packages.mozilla.org.asc

# The profile of /etc/wireguard: not a file of the user's, this one - the pack
# writes it at every mount, out of the JSON - so it goes with the pack. The
# tunnel is already down by now, which is what wg-quick needed it for.
echo "➖ Removing the profile the pack generated..."
sudo rm -f /etc/wireguard/vpn.conf

echo "✅ The tunnel and the browser are gone, and Mozilla's repository with them."
echo "   Left alone, on purpose:"
echo "     - your servers, ~/.config/vpn/servers.json - it carries your private keys"
echo "     - the VPN_PROFILE and VPN_KILL_SWITCH lines of ~/.config/zsh/gmake/.env.global"
echo "     - the profiles an older install left in /etc/wireguard, if any are still there"
echo "     - generateResolvConf = false in /etc/wsl.conf - a setting of the machine, not the pack's"
echo "     - your Firefox profile, ~/.mozilla - bookmarks, passwords, history"
echo "   systemd-resolved was removed to make room for openresolv:"
echo "     sudo apt install systemd-resolved    puts it back."
