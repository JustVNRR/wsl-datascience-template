# ==========================================
# TUNNEL CHEATSHEET (wireguard / proton)
# requires: wg
# ==========================================
# The `web` pack's tunnel: one WireGuard profile per server in /etc/wireguard,
# the DNS through openresolv, and WSL's own boot hook for the automatic start.
# The pack installs from Windows (`.\wsl.ps1 add_pack`), its page is
# packs/web/docs/vpn.md, and the module behind these targets is make/vpn.mk.
# Offered only while the tools are installed - the header above hides the sheet
# when they were removed by hand.

# --- 1. THE TUNNEL (gmake) ---
gmake vpn_status                               # Up or down, the DNS, the exit IP, what starts with the distro
gmake vpn_up                                   # Connect - the menu picks the server
gmake vpn_up VPN_PROFILE=ch                    # ... or name one, and skip the menu
gmake vpn_down                                 # Disconnect
gmake vpn_server                               # Choose the server the distro starts with
gmake vpn_auto_on                              # Bring the tunnel up with the distro
gmake vpn_auto_off                             # Stop bringing it up

# --- 2. ADD A SERVER, OR TAKE ONE OUT ---
gmake vpn_profile_add VPN_PROFILE=ch           # New profile from the sample, then the editor opens
gmake vpn_profile_remove VPN_PROFILE=ch        # Delete one (it asks first: the file holds your key)

# --- 3. WHAT IS REALLY HAPPENING ---
sudo wg show                                   # The interface, its peer, the last handshake
sudo wg show interfaces                        # Which profile is up
cat /etc/resolv.conf                           # 10.2.0.1 = the DNS goes through the tunnel
curl -s https://am.i.mullvad.net/ip            # The exit IP the world sees
sudo wg-quick down proton                      # The manual way, when a target is not at hand

# --- 4. THE PROFILES ---
sudo ls /etc/wireguard                        # One .conf per server, and the marker `auto`
sudo nano /etc/wireguard/ch.conf               # Edit one: the keys stay, the [Peer] changes
sudo cat /etc/wireguard/auto                   # The profile the distro starts with

# --- 5. WHEN THE AUTOMATIC START DOES NOTHING ---
sudo tail -20 /var/log/web-vpn.log             # What the boot hook tried, and why it stopped
cat /etc/wsl.conf                              # [boot] command= and [network] generateResolvConf
