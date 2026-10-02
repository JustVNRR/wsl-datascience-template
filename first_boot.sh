#!/bin/bash
set -e

# The socle's colours, read from the skeleton the image carries them in - the
# instance has no account yet. A missing library leaves the questions plain
# rather than stopping the onboarding.
C_YELLOW=''
C_RESET=''
if [ -r /etc/skel/.config/zsh/lib/colours.sh ]; then
    # shellcheck source=/dev/null
    . /etc/skel/.config/zsh/lib/colours.sh || true
fi

clear
echo "============================================================"
echo "            Welcome to your WSL Stack environment"
echo "============================================================"
echo ""

# A name no account uses yet: adduser fails on a taken one (root, daemon,
# www-data...), and set -e would abort the whole onboarding on its raw error.
while true; do
    read -rp "${C_YELLOW}Enter your username: ${C_RESET}" NEW_USER
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

# The trigger in /root/.bashrc runs this again on every root shell, and the
# account exists from here: a re-run could only fail on adduser. Disarmed now,
# not at the end - a failure above would leave that loop running.
sed -i '/first_boot\.sh/d' /root/.bashrc 2>/dev/null || true

echo ""
# The account was created with no password of its own (--disabled-password):
# inside WSL nobody logs in with one, so the password's only job is sudo. Hence
# the question, defaulting to no - NOPASSWD lets anything running as this user
# become root with no prompt at all.
read -rp "${C_YELLOW}Run sudo without a password (passwordless)? [y/N] ${C_RESET}" PASSWORDLESS
echo ""

# The group is what makes sudo possible at all - both paths below need it.
usermod -aG sudo "$NEW_USER"

PASSWORDLESS_OK=no
if [[ "$PASSWORDLESS" =~ ^[Yy]$ ]]; then
    # The drop-in that makes sudo stop asking. No dot in the name and 0440:
    # sudo ignores a file whose name contains one or ends in ~, and refuses any
    # other mode. The syntax is checked before the file stays - an invalid file
    # in sudoers.d takes sudo away entirely - and on a failed check the
    # password path below runs.
    SUDOERS_FILE="/etc/sudoers.d/010-$NEW_USER-nopasswd"
    echo "$NEW_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    if visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
        PASSWORDLESS_OK=yes
        echo "sudo will not ask for a password."
    else
        rm -f "$SUDOERS_FILE"
        echo "[WARNING] The sudo rule could not be written - falling back to a password."
    fi
fi

if [[ "$PASSWORDLESS_OK" == no ]]; then
    echo "Please set a password for $NEW_USER:"
    while ! passwd "$NEW_USER"; do
        echo ""
        echo "[ERROR] Password setup failed (mismatch or empty). Let's try again."
    done
fi

# The docker socket Docker Desktop creates is writable by root and by this
# group only, so the group is created with the account: the very first session
# can use docker. Left to Docker Desktop, it only arrives at its next restart.
# --force, not a plain groupadd: the group may already exist, and set -e would
# abort the whole onboarding on that.
groupadd --force docker
usermod -aG docker "$NEW_USER"

echo ""
echo "Configuring timezone..."
dpkg-reconfigure -f readline tzdata
clear

# The WSL configuration the onboarding knows. No [boot] block: the image ships
# no /sbin/init, so systemd=true would do nothing - `gmake systemd_up` writes
# it on the instance that asks. mountFsTab=false likewise: no /etc/fstab lines
# yet, and `gmake fstab_up` is what applies them.
cat << WSLCONF > /etc/wsl.conf
[user]
default=$NEW_USER

[automount]
enabled=true
mountFsTab=false

[interop]
enabled=true
appendWindowsPath=true
WSLCONF

# No Python here: uv and the interpreter come with the `python` pack, the
# scaffolding tools with `scaffold` - they arrive on the instance that asks,
# with `.\wsl.ps1 add_pack` or by being chosen while the instance is built.

# Export username for build script display
echo -n "$NEW_USER" > /tmp/installed_user

# The pages cache is a convenience: a machine without network must not lose the
# run - and the script deletes itself last, once nothing below can fail.
su - "$NEW_USER" -c "tldr --update" || echo "  (tldr cache left as it was)"
rm -f /root/first_boot.sh
exit 0