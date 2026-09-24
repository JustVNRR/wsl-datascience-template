#!/bin/bash
set -e

clear
echo "============================================================"
echo "      Welcome to your Data Science WSL Environment"
echo "============================================================"
echo ""

# Prompt for a valid Linux username (lowercase letters, digits, underscores,
# dashes) that no account uses yet. adduser fails on a name that is already
# taken - root, daemon, www-data, _apt - and set -e would then abort the whole
# onboarding on adduser's raw error.
while true; do
    read -rp "Enter your username: " NEW_USER
    if [[ ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Invalid username (use lowercase letters, numbers, underscores, and dashes only)."
    elif id "$NEW_USER" >/dev/null 2>&1; then
        echo "The account '$NEW_USER' already exists - pick another name."
    else
        break
    fi
done

echo ""
echo "Creating user account $NEW_USER..."
# Create user silently (skips Full Name, Room Number, etc.)
adduser --disabled-password --gecos "" --shell /usr/bin/zsh "$NEW_USER"

# The trigger in /root/.bashrc runs this script again on every root shell, and
# the account exists from here: a re-run could only fail on adduser. Disarm it
# now rather than at the end, where a failure above would leave that loop
# running.
sed -i '/first_boot\.sh/d' /root/.bashrc 2>/dev/null || true

echo ""
echo "Please set a password for $NEW_USER:"
# Loop until the password is successfully set
while ! passwd "$NEW_USER"; do
    echo ""
    echo "[ERROR] Password setup failed (mismatch or empty). Let's try again."
done

# Grant administrative privileges (sudo prompts for the account password)
usermod -aG sudo "$NEW_USER"

# The docker client Docker Desktop injects is only usable through a group: the
# socket it creates is writable by root and by that group, and by nothing else.
# Created here, with the account, so the very first session has the right to
# use docker. Left to Docker Desktop, the group only arrives when it next
# restarts - and a session keeps the groups it started with, so the user is
# told to close a terminal and open a new one for something that should have
# worked from the start.
# --force, not a plain groupadd: the group may already exist, and set -e would
# abort the whole onboarding on that.
groupadd --force docker
usermod -aG docker "$NEW_USER"

echo ""
echo "Configuring timezone..."
dpkg-reconfigure -f readline tzdata
clear

# Write complete WSL configuration
cat << WSLCONF > /etc/wsl.conf
[boot]
systemd=true

[user]
default=$NEW_USER

[interop]
enabled=true
appendWindowsPath=true
WSLCONF

# Pre-fetch default Python version and install CLI tools via uv for the new user
echo "Setting up default Python runtime and tools via uv..."
su - "$NEW_USER" -c "uv python install 3 && uv tool install copier && uv tool install cruft && uv tool install ruff"
# The scaffold tools behind the template catalog. cookiecutter is the ancestor
# the others build on: installing its command too means a template whose README
# says `cookiecutter <url>` works exactly as written. cookiecutter-data-science
# provides `ccds`, the current Cookiecutter Data Science scaffold.
su - "$NEW_USER" -c "uv tool install cookiecutter"
su - "$NEW_USER" -c "uv tool install cookiecutter-data-science"

# Export username for build script display
echo -n "$NEW_USER" > /tmp/installed_user

# The trigger is gone already. The pages cache is a convenience, so a machine
# without network must not lose the rest of the run - and the script deletes
# itself last, once nothing below it can fail.
su - "$NEW_USER" -c "tldr --update" || echo "  (tldr cache left as it was)"
rm -f /root/first_boot.sh
exit 0