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
    echo "No PACK_PACKAGES found in $here/pack.conf" >&2
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

echo "Installing the tunnel and the browser (your password will be asked)..."



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
#
#    Two libraries come with them and are named nowhere else, both of them loaded
#    by the browser at runtime and invisible to apt:
#      - libavcodec60, the system decoder for H.264 and AAC, which is what
#        YouTube sends for its live streams (ordinary videos arrive in VP9/AV1,
#        decoded by the browser itself);
#      - libpulse0, the PulseAudio client: the sound of a WSLg window goes
#        through PulseAudio, and Mozilla's package only pulls ALSA.
#    A library cannot go in PACK_PACKAGES - see the comment there, and
#    docs/packs.md.
apt-get update
apt-get install -y --no-install-recommends $packages libavcodec60 libpulse0

# 3. The resolver itself, from Debian's archive.
cd /tmp
wget -q $resolver_url -O $resolver_package.deb
dpkg -i $resolver_package.deb
rm -f $resolver_package.deb

# 4. WSL must stop rewriting /etc/resolv.conf at every start, and the file has
#    to be a real one for openresolv to manage. Read at distro start, so this
#    takes effect at the next one - the last line of this script says so.
#
#    The resolver file itself is not written here: whatever this wrote, WSL's
#    own start poses over it. vpn.sh writes it - the base, from BASE_DNS -
#    before every mount, and that is also what the boot hook runs.
if grep -q '^[[:space:]]*generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    sed -i 's/^[[:space:]]*generateResolvConf.*/generateResolvConf = false/' /etc/wsl.conf
else
    printf '\n[network]\ngenerateResolvConf = false\n' >> /etc/wsl.conf
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
        echo \"Mozilla's signing key is not the one this pack knows - nothing was installed.\"
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

# The boot side, and it is installed now - not only when someone asks for the
# automatic start: a [boot] command that puts the base resolver back at every
# start of the distro. openresolv keeps its file in /run, /run is empty at each
# start, and WSL leaves /etc/resolv.conf alone here (this pack writes
# generateResolvConf = false): without the hook, a restarted instance would
# resolve nothing at all until a vpn target ran. vpn_auto_on/off only decide
# whether the same hook also raises the tunnel.
if ! bash "$here/bin/vpn.sh" hook on; then
    echo "The boot hook was not installed - run it by hand:"
    echo "   bash ~/.config/packs/web/bin/vpn.sh hook on"
fi

# The sound, once the browser is there. Its audio process is sandboxed, and on
# WSLg that sandbox is what keeps it away from the socket the sound travels
# through: with the client library installed the browser still plays in silence
# until this default says otherwise (measured on an instance).
#
# A default, not an order: it goes where Mozilla's own package puts its default
# preferences, so it applies to every profile - no name to guess, unlike a
# user.js in ~/.mozilla - and a value set in about:config still wins. remove.sh
# takes the file back.
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

# The servers, in one JSON in ~/.config/vpn (mode 600: it carries the private
# keys). Three cases, in this order:
#   - it is already there: nothing is touched, ever - that file is the user's;
#   - profiles are still in /etc/wireguard (a machine that ran the first shape of
#     this pack): their values move into the JSON, and the files stay where they
#     are - they are the user's too, and deleting them is their call;
#   - neither: the sample is copied over, and waits to be filled in.
servers=$HOME/.config/vpn/servers.json
if [ -f "$servers" ]; then
    echo "$servers is already there - left untouched."
else
    # The pack's own sample, checked before it is copied: a broken one would be
    # the user's file from the first minute, and jq is what reads it.
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
        echo "$servers is waiting for your keys - one entry per server, and"
        echo "   the sample says where every value goes - the keys and the"
        echo "   address come from the WireGuard configuration your provider"
        echo "   gives you, its DNS line with them."
        echo "   Then: gmake vpn_edit_profiles, and gmake vpn_up."
    fi
fi

# The pack's two variables, into the file the socle loads. `env_global_enable`
# merges the sample of every installed pack and adds what is missing - it never
# rewrites a value the user set, which is what makes it safe to run here, and why
# it saves the step an install used to leave over: a variable nobody merged is a
# target that answers "VPN_PROFILE is not set in .env.global".
#
# Best-effort on purpose: the merge loads every installed pack's module, and a
# broken one elsewhere would make it fail - that must not fail an install that
# worked, so the message says what to run by hand instead.
if ! make -f "$HOME/.config/zsh/gmake/Makefile" env_global_enable; then
    echo "The variables were not merged - run 'gmake env_global_enable' yourself."
fi

echo "Firefox is installed, and 'fox' opens it - its commands are in the picker (fcheat)."
echo "Privacy defaults for it, when you want them: gmake fox_tweak_on   (docs/fox.md)"
echo "WireGuard is installed: gmake vpn_status   (servers first, see docs/vpn.md)"
if [ -L /etc/resolv.conf ] || grep -q 'generateResolvConf' /etc/wsl.conf 2>/dev/null; then
    echo "The DNS setting is read when the distro starts: restart it once"
    echo "   (.\wsl.ps1 restart, from Windows) before the tunnel manages /etc/resolv.conf."
fi
