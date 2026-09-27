#!/usr/bin/env bash
# ==============================================================================
# THE WEB PACK - WHAT IT INSTALLS
# ==============================================================================
# `wsl.ps1 add_pack` copies this pack's folder into ~/.config/packs/web, then
# runs this script from inside it, as the instance's own user.
#
# Two halves, one folder. The browser comes from Mozilla's own repository - on
# Ubuntu 24.04 the package named `firefox` is a transitional one that installs
# the snap - and the tunnel is the user's own recipe, written up in docs/vpn.md:
# WireGuard, openresolv for the DNS, WSL's boot hook for the automatic start.
# The servers it connects to live in ~/.config/vpn/servers.json, which this seeds
# - or fills in from the profiles a first install had left in /etc/wireguard.
#
# Two of its moves are worth reading twice:
#   - `systemd-resolved` is removed when it is there. It ships the `resolvconf`
#     command that openresolv also provides, and the Debian package refuses to
#     install while it is present (measured: "conflicting packages - not
#     installing openresolv"). The removal message says how to put it back.
#   - `generateResolvConf = false` goes into /etc/wsl.conf, and /etc/resolv.conf
#     becomes a real file: WSL rewrites that file at every start otherwise, and
#     openresolv's work would be undone by the next boot. The setting is read at
#     distro start, so the message at the end asks for a restart.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
declared=$(sed -n 's/^PACK_PACKAGES *:=[[:space:]]*//p' "$here/pack.conf")

if [ -z "$declared" ]; then
    echo "❌ No PACK_PACKAGES found in $here/pack.conf" >&2
    exit 1
fi

# Two of the declared packages are installed apart, each for its own reason -
# and both would be worse than useless in the apt line below:
#   - firefox, because Mozilla's repository, its key and its pins are set up
#     later in this script. Asked for before that, apt answers with Ubuntu's
#     transitional package - which installs snapd and no browser (measured).
#   - openresolv, because Ubuntu 24.04 carries no such package: apt would answer
#     "no installation candidate" and stop everything. It comes from Debian's
#     archive instead, pinned - a foreign package is not updated by anything, so
#     the version is written down where it is read.
packages=
for package in $declared; do
    if [ "$package" != openresolv ] && [ "$package" != firefox ]; then
        packages="$packages $package"
    fi
done
resolver_package=openresolv
resolver_url=http://ftp.debian.org/debian/pool/main/o/openresolv/openresolv_3.12.0-1_all.deb

echo "➕ Installing the tunnel and the browser (your password will be asked)..."
# DEBIAN_FRONTEND, so that a package reconfigured on the way never stops the
# install to ask a question.
sudo bash -c "set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- the tunnel -------------------------------------------------------------

# 1. What the resolver needs, before it can be installed.
if dpkg -s systemd-resolved >/dev/null 2>&1; then
    apt-get remove -y systemd-resolved
fi

# 2. The tools: the WireGuard userland, the loader of the kernel module (kmod -
#    without it the module survives only until the next 'wsl --shutdown', see
#    docs/vpn.md), the routing tools wg-quick calls, and the firewall the kill
#    switch is written in.
apt-get update
apt-get install -y --no-install-recommends $packages

# 3. The resolver itself, from Debian's archive.
cd /tmp
wget -q $resolver_url -O $resolver_package.deb
dpkg -i $resolver_package.deb
rm -f $resolver_package.deb

# 4. WSL must stop rewriting /etc/resolv.conf at every start, and the file has
#    to be a real one for openresolv to manage. Read at distro start, so this
#    takes effect at the next one - the last line of this script says so.
if grep -q '^[[:space:]]*generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    sed -i 's/^[[:space:]]*generateResolvConf.*/generateResolvConf = false/' /etc/wsl.conf
else
    printf '\n[network]\ngenerateResolvConf = false\n' >> /etc/wsl.conf
fi
if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf
    printf 'nameserver 1.1.1.1\n' > /etc/resolv.conf
fi

# --- the browser ------------------------------------------------------------

# 5. Mozilla's signing key, and the check that it is Mozilla's.
#    grep reads the whole stream on purpose: with a --quiet match it would leave
#    the pipe, gpg would take a SIGPIPE, and pipefail would read that as a bad
#    key.
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc
gpg --show-keys --with-colons /etc/apt/keyrings/packages.mozilla.org.asc |
    grep '^fpr:::::::::35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3:' > /dev/null || {
        echo \"❌ Mozilla's signing key is not the one this pack knows - nothing was installed.\"
        rm -f /etc/apt/keyrings/packages.mozilla.org.asc
        exit 1
    }

# 6. Their repository, and two pins: theirs above Ubuntu's, and Ubuntu's
#    firefox - the transitional package - below everything, so a later apt run
#    cannot bring the snap stub back.
echo 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' > /etc/apt/sources.list.d/mozilla.list
printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla
printf 'Package: firefox*\nPin: release o=Ubuntu*\nPin-Priority: -1\n' > /etc/apt/preferences.d/firefox-no-snap

apt-get update
# --allow-downgrades, and it is not a nicety: Ubuntu's transitional package
# carries an epoch (1:1snap1), so apt ranks it ABOVE Mozilla's real one and
# refuses the change with \"Packages were downgraded and -y was used without
# --allow-downgrades\" on any machine where that stub was ever installed.
apt-get install -y --no-install-recommends --allow-downgrades firefox"

# The servers, in one JSON in ~/.config/vpn (mode 600: it carries the private
# keys). Three cases, in this order:
#   - it is already there: nothing is touched, ever - that file is the user's;
#   - profiles are still in /etc/wireguard (a machine that ran the first shape of
#     this pack): their values move into the JSON, and the files stay where they
#     are - they are the user's too, and deleting them is their call;
#   - neither: the sample is copied over, and waits to be filled in.
servers=$HOME/.config/vpn/servers.json
if [ -f "$servers" ]; then
    echo "ℹ️  $servers is already there - left untouched."
else
    # The pack's own sample, checked before it is copied: a broken one would be
    # the user's file from the first minute, and jq is what reads it.
    jq -e . "$here/vpn.servers.sample" > /dev/null ||
        {
            echo "❌ The pack's own sample of servers does not parse - nothing was written to $servers." >&2
            exit 1
        }
    if ! bash "$here/bin/vpn-migrate.sh" "$servers"; then
        echo "ℹ️  Nothing was migrated - the pack's sample is used instead."
    fi
    if [ ! -f "$servers" ]; then
        install -d -m 0700 "$(dirname "$servers")"
        install -m 600 "$here/vpn.servers.sample" "$servers"
        echo "📝 $servers is waiting for your keys - one entry per server, and"
        echo "   the file documents itself. Both keys and the address come from"
        echo "   your Proton account: Downloads, 'WireGuard configuration'."
        echo "   Then: gmake vpn_edit_profiles, and gmake vpn_up."
    fi
fi

echo "✅ Firefox is installed, and 'fox' opens it - its commands are in the picker (fcheat)."
echo "✅ WireGuard is installed: gmake vpn_status   (servers first, see docs/vpn.md)"
if [ -L /etc/resolv.conf ] || grep -q 'generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    echo "ℹ️  The DNS setting is read when the distro starts: restart it once"
    echo "   (wsl.exe --terminate <distro>, from Windows) before the tunnel manages /etc/resolv.conf."
fi
