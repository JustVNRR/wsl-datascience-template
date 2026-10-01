#!/usr/bin/env bash
# ==============================================================================
# THE WEB PACK - WHAT IT REMOVES
# ==============================================================================
# `wsl.ps1 remove_pack` runs this before deleting the pack's folder: what the
# install added to the system leaves it, and only that. A package another
# installed pack still claims stays where it is. No library is ever removed
# (apt would take its dependents), and no autoremove here - remove_pack runs
# the cleanup that follows, with its two questions.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
declared=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$declared" ]; then
    echo "No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

# Is this package claimed by another pack that is still installed?
claimed_elsewhere() {
    grep -rl --include=pack.conf --include=install.sh -- "$1" "$HOME/.config/packs" 2>/dev/null |
        grep -qv "^${here}/"
}

echo "Taking the tunnel down, and removing its boot hook..."
"$here/bin/vpn.sh" hook off
"$here/bin/vpn.sh" down

echo "Removing the tunnel and the browser..."
for package in $declared; do
    if claimed_elsewhere "$package"; then
        echo "$package: another installed pack claims it - left in place."
        continue
    fi
    if [ "$package" = openresolv ]; then
        # No candidate in Ubuntu 24.04: it came from Debian's package.
        sudo dpkg -r openresolv
        continue
    fi
    sudo apt-get remove -y "$package"
done

# Libraries installed beside the browser: marked automatic, they become
# orphans for the cleanup remove_pack runs next.
echo "Leaving the browser's decoder and its sound client to the cleanup that follows..."
sudo apt-mark auto libavcodec60 libpulse0 2>/dev/null || true

# What the pack wrote in the browser's directory: the sound preference, and the
# privacy link with the file it points at.
echo "Removing the sound preference and the privacy link..."
sudo rm -f /usr/lib/firefox/defaults/pref/wslg-audio.js \
           /usr/lib/firefox/defaults/pref/fox-privacy.js
rm -f "$HOME/.config/fox-privacy.js"

echo "Removing Mozilla's repository..."
sudo rm -f /etc/apt/sources.list.d/mozilla.list \
           /etc/apt/preferences.d/mozilla \
           /etc/apt/preferences.d/firefox-no-snap \
           /etc/apt/keyrings/packages.mozilla.org.asc

# Regenerated at every mount - not a file of the user's.
echo "Removing the profile the pack generated..."
sudo rm -f /etc/wireguard/vpn.conf

echo "The tunnel and the browser are gone, and Mozilla's repository with them."
echo "   Left alone, on purpose:"
echo "     - your servers, ~/.config/vpn/servers.json - it carries your private keys"
echo "     - the VPN_PROFILE, VPN_KILL_SWITCH, VPN_MTU and BASE_DNS lines of ~/.config/zsh/gmake/.env.global"
echo "     - the profiles an older install left in /etc/wireguard, if any are still there"
echo "     - generateResolvConf = false in /etc/wsl.conf - a setting of the machine, not the pack's"
echo "     - your Firefox profile, ~/.mozilla - bookmarks, passwords, history"
echo "   systemd-resolved was removed to make room for openresolv:"
echo "     sudo apt install systemd-resolved    puts it back."
