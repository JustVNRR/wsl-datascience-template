#!/usr/bin/env bash
# ==============================================================================
# THE WEB PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies the pack's folder into ~/.config/packs/web, then
# runs this script from inside it, as the instance's own user.
#
# Firefox comes from Mozilla's own repository (Ubuntu's `firefox` is a snap
# stub), the tunnel is WireGuard over openresolv, and the servers land in
# ~/.config/vpn/servers.json - seeded here, or migrated from old
# /etc/wireguard profiles.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
declared=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$declared" ]; then
    echo "No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

# firefox is installed later (its repository comes first), and openresolv does
# not exist in Ubuntu 24.04 (Debian's package, pinned below): both would break
# the apt line.
packages=
for package in $declared; do
    if [ "$package" != openresolv ] && [ "$package" != firefox ]; then
        packages="$packages $package"
    fi
done
resolver_package=openresolv
resolver_url=http://ftp.debian.org/debian/pool/main/o/openresolv/openresolv_3.12.0-1_all.deb

echo "Installing the tunnel and the browser (your password will be asked)..."

# DEBIAN_FRONTEND: a package reconfigured on the way must not stop to ask.
sudo bash -c "set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- the tunnel -------------------------------------------------------------

# 1. systemd-resolved ships a resolvconf of its own; Debian's openresolv
#    refuses to install beside it.
if dpkg -s systemd-resolved >/dev/null 2>&1; then
    apt-get remove -y systemd-resolved
fi

# 2. wireguard-tools, kmod (the module dies with 'wsl --shutdown' without
#    modprobe - see docs/vpn.md), iproute2 and iptables for wg-quick and the
#    kill switch. libavcodec60 (H.264/AAC - YouTube live) and libpulse0 (WSLg's
#    sound) are libraries the browser loads at runtime: never in PACK_PACKAGES,
#    see docs/packs.md.
apt-get update
apt-get install -y --no-install-recommends $packages libavcodec60 libpulse0

# 3. The resolver, from Debian's archive (no such package in Ubuntu 24.04).
cd /tmp
wget -q $resolver_url -O $resolver_package.deb
dpkg -i $resolver_package.deb
rm -f $resolver_package.deb

# 4. WSL must stop rewriting /etc/resolv.conf at every start, or openresolv's
#    work is undone by the next boot. Read at distro start - the last lines of
#    this script ask for the restart. The file itself is written by vpn.sh
#    (the base, from BASE_DNS) before every mount.
if grep -q '^[[:space:]]*generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    sed -i 's/^[[:space:]]*generateResolvConf.*/generateResolvConf = false/' /etc/wsl.conf
else
    printf '\n[network]\ngenerateResolvConf = false\n' >> /etc/wsl.conf
fi

# --- the browser ------------------------------------------------------------

# 5. Mozilla's signing key, fingerprint checked. grep reads the whole stream:
#    with --quiet, gpg would take the SIGPIPE and pipefail would read it as a
#    bad key.
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc
gpg --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc |
    grep '^fpr:::::::::35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3:' > /dev/null || {
        echo \"Mozilla's signing key is not the one this pack knows - nothing was installed.\"
        rm -f /etc/apt/keyrings/packages.mozilla.org.asc
        exit 1
    }

# 6. Their repository, and two pins: theirs above Ubuntu's, and Ubuntu's snap
#    stub below everything.
echo 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' > /etc/apt/sources.list.d/mozilla.list
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla
printf 'Package: firefox*\nPin: release o=Ubuntu*\nPin-Priority: -1\n' > /etc/apt/preferences.d/firefox-no-snap

apt-get update
# --allow-downgrades: Ubuntu's stub carries an epoch (1:1snap1) and ranks
#    above Mozilla's package, so apt refuses the change without it.
apt-get install -y --no-install-recommends --allow-downgrades firefox"

# The boot hook, installed with the pack - not only with the automatic start:
# it puts the base resolver back at each start (/run is empty then, and WSL
# leaves /etc/resolv.conf alone here). vpn_auto_on/off only decide whether it
# also raises the tunnel.
if ! bash "$here/bin/vpn.sh" hook on; then
    echo "The boot hook was not installed - run it by hand:"
    echo "   bash ~/.config/packs/web/bin/vpn.sh hook on"
fi

# The sound of a WSLg window: the audio sandbox keeps the browser away from the
# socket WSLg serves, so this default turns it off. A default, not an order -
# about:config wins. remove.sh takes the file back.
pref_file=/usr/lib/firefox/defaults/pref/wslg-audio.js
if [ -d /usr/lib/firefox/defaults/pref ]; then
    sudo tee "$pref_file" > /dev/null <<'PREF'
// Set by the web pack: the sound of a WSLg window goes through PulseAudio, and
// the audio sandbox keeps the browser away from the socket WSLg serves. This is
// a default - a value set in about:config wins over it.
pref("media.cubeb.sandbox", false);
PREF
    sudo chmod 0644 "$pref_file"
    echo "The sound reaches WSLg (media.cubeb.sandbox off, as a default)."
else
    echo "No /usr/lib/firefox/defaults/pref: the sound was left alone."
fi

# The privacy link, and the light set in place: one link in the browser's
# directory, pointing at a file of the user's own - the launchers switch sets
# through it with no password (docs/fox.md). Best-effort, like the hook.
if ! bash "$here/bin/fox.sh" light; then
    echo "The privacy link was not set up - run it by hand:"
    echo "   bash ~/.config/packs/web/bin/fox.sh light"
fi

# The servers. The JSON is the user's: left alone when it exists; migrated from
# leftover /etc/wireguard profiles; the sample otherwise.
servers=$HOME/.config/vpn/servers.json
if [ -f "$servers" ]; then
    echo "$servers is already there - left untouched."
else
    # The sample is checked first: it would be the user's file from the first minute.
    jq -e . "$here/vpn.servers.sample" > /dev/null ||
        {
            echo "The pack's own sample of servers does not parse - nothing was written to $servers." >&2
            exit 1
        }
    if ! bash "$here/bin/vpn-migrate.sh" "$servers"; then
        echo "Nothing was migrated - the pack's sample is used instead."
    fi
    if [ ! -f "$servers" ]; then
        install -d -m 0700 "$(dirname "$servers")"
        install -m 600 "$here/vpn.servers.sample" "$servers"
        echo "$servers is waiting for your keys - the sample says where every"
        echo "   value goes, from the WireGuard configuration your provider"
        echo "   gives you (its DNS line with them)."
        echo "   Then: gmake vpn_edit_profiles, and gmake vpn_up."
    fi
fi

# The pack's variables, merged into the file the socle loads. Best-effort: the
# merge loads every installed pack's module, and a broken neighbour must not
# fail an install that worked.
if ! make -f "$HOME/.config/zsh/gmake/Makefile" env_global_enable; then
    echo "The variables were not merged - run 'gmake env_global_enable' yourself."
fi

echo "Firefox is installed, and 'fox' opens it - its commands are in the picker (fcheat)."
echo "It starts on the light privacy settings; pfox opens the strict ones (docs/fox.md)."
echo "WireGuard is installed: gmake vpn_status   (servers first, see docs/vpn.md)"
if [ -L /etc/resolv.conf ] || grep -q 'generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    echo "The DNS setting is read when the distro starts: restart it once"
    echo "   (.\wsl.ps1 restart, from Windows) before the tunnel manages /etc/resolv.conf."
fi
