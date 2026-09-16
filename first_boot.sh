#!/bin/bash
set -e

clear
echo "============================================================"
echo "      Welcome to your Data Science WSL Environment"
echo "============================================================"
echo ""

# Prompt for a valid Linux username (lowercase letters, digits, underscores, dashes)
while true; do
    read -rp "Enter your username: " NEW_USER
    if [[ "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        break
    else
        echo "Invalid username (use lowercase letters, numbers, underscores, and dashes only)."
    fi
done

echo ""
echo "Creating user account $NEW_USER..."
# Create user silently (skips Full Name, Room Number, etc.)
adduser --disabled-password --gecos "" --shell /usr/bin/zsh "$NEW_USER"

echo ""
echo "Please set a password for $NEW_USER:"
# Loop until the password is successfully set
while ! passwd "$NEW_USER"; do
    echo ""
    echo "[ERROR] Password setup failed (mismatch or empty). Let's try again."
done

# Grant administrative privileges (sudo prompts for the account password)
usermod -aG sudo "$NEW_USER"

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

# Export username for build script display
echo -n "$NEW_USER" > /tmp/installed_user

# Remove setup trigger from root bashrc and delete setup script
sed -i '/first_boot\.sh/d' /root/.bashrc 2>/dev/null || true
rm -f /root/first_boot.sh

su - "$NEW_USER" -c "tldr --update"
exit 0