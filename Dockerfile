FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Remove default 'ubuntu' user created in Noble 24.04 base images
RUN userdel -r ubuntu 2>/dev/null || true

# Remove all dpkg drop-in filters so documentation and examples (like fzf bindings) are installed
RUN rm -f /etc/dpkg/dpkg.cfg.d/*

# 1. Install prerequisites for third-party repositories and core networking tools
#
# apt-utils is here for the line it silences rather than for its own tools:
# without it, debconf announces "delaying package configuration, since apt-utils
# is not installed" on every apt run that configures a package - which is every
# pack's install, in front of the user, next to nothing else. It is part of a
# normal Ubuntu install, and what it depends on is already here.
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    gnupg \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure third-party APT repositories (GitHub CLI, eza)
#
# Only the tools this image installs get their repository registered here. A
# tool installed on demand registers its own, at the moment it is installed:
# the image then carries no key and no address for a machine that may never use
# it, and uninstalling that tool has something to undo.
RUN mkdir -p -m 755 /etc/apt/keyrings \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list \
    # eza (modern ls replacement)
    && curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list

# 3. Install system packages, developer CLI tools, build dependencies, and DS/ML libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    # System & Shell utilities
    locales \
    adduser \
    sudo \
    tzdata \
    zsh \
    nano \
    git \
    openssh-client \
    strace \
    lsof \
    # gmake is the whole MLOps interface of this image, and make used to arrive
    # as a dependency of build-essential - which is the python pack's now. It is
    # named here in plain sight: without this line the image would carry no make
    # at all, and every gmake target would be gone with it.
    make \
    # first_boot.sh writes systemd=true into /etc/wsl.conf, and WSL only boots
    # systemd when the distribution ships it. Without this package the
    # declaration is inert: `systemctl` does not exist and PID 1 stays the WSL
    # init. The ubuntu base image is trimmed and does not include it.
    systemd \
    # Pager and network probe the shell expects: git, systemctl and journalctl
    # page through `less` (a Recommends that --no-install-recommends drops),
    # and the bash cheatsheet documents both of these commands
    less \
    iputils-ping \
    tree \
    tar \
    unzip \
    bzip2 \
    unrar \
    p7zip-full \
    gzip \
    xz-utils \
    zstd \
    # Modern shell UX & CLI tools
    bat \
    direnv \
    eza \
    fd-find \
    fzf \
    gh \
    jq \
    ripgrep \
    shellcheck \
    zoxide \
    # Database CLI
    sqlite3 \
    # No Python, and no compiler for it: uv, python3-dev, libffi-dev,
    # libssl-dev and build-essential are the `python` pack's, and they arrive on
    # the instance that asks for them, with `.\wsl.ps1 add_pack`. Same for
    # ffmpeg, ImageMagick and Tesseract, the `vision` pack's. What this image
    # carries is what every project needs.
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure UTF-8 locale
RUN locale-gen en_US.UTF-8 fr_FR.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create symlinks for binary compatibility (fdfind -> fd, batcat -> bat)
RUN ln -s $(which fdfind) /usr/local/bin/fd \
    && ln -s $(which batcat) /usr/local/bin/bat

# Guarantee fzf bindings are uncompressed if dpkg shipped them compressed
RUN if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh.gz ]; then \
        gunzip -f /usr/share/doc/fzf/examples/key-bindings.zsh.gz; \
    fi

# 4. Install prompt (Starship) and tealdeer
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then STARSHIP_ARCH="x86_64"; else STARSHIP_ARCH="aarch64"; fi \
    && curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${STARSHIP_ARCH}-unknown-linux-gnu.tar.gz" -o starship.tar.gz \
    && tar -xzf starship.tar.gz -C /usr/local/bin \
    && rm starship.tar.gz \
    && curl -fsSL "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${STARSHIP_ARCH}-musl" -o /usr/local/bin/tldr \
    && chmod +x /usr/local/bin/tldr

# 5. Clone Oh-My-Zsh and its custom plugins into the user skeleton
RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.local/share/oh-my-zsh \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Copy modular Zsh configuration to the user skeleton directory
COPY zsh /etc/skel/.config/zsh

# Nothing of the packs, and that is deliberate: the image carries the socle. A
# pack arrives afterwards, on a living instance, with `.\wsl.ps1 add_pack`,
# which copies its folder into ~/.config/packs and runs its install script
# there - the files and the tool together. A machine that never wants one never
# pays for it, and `build` stays quick.

# Bootstrap ZDOTDIR and create the skeleton directories. The ubuntu base image
# leaves a bash dotfile set (.bashrc, .bash_logout, .profile) in /etc/skel, and
# every account created here would inherit it - for a shell this image never
# runs. They go.
RUN echo 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' > /etc/skel/.zshenv \
    && echo 'skip_global_compinit=1' >> /etc/skel/.zshenv \
    && rm -f /etc/skel/.bashrc /etc/skel/.bash_logout /etc/skel/.profile \
    && mkdir -p /etc/skel/.ssh \
    && mkdir -p /etc/skel/.local/state/zsh \
    && mkdir -p /etc/skel/.cache/zsh \
    && mkdir -p /etc/skel/projects \
    && chmod 700 /etc/skel/.ssh

# 6. Deploy first-boot onboarding script and trigger it via root bashrc
COPY first_boot.sh /root/first_boot.sh
RUN chmod +x /root/first_boot.sh \
    && echo '/root/first_boot.sh' >> /root/.bashrc \
    && chown -R root:root /etc/skel

# Purge any potential runtime dump caches
RUN rm -f /etc/skel/.config/zsh/.zcompdump* /root/.zcompdump*

CMD ["/bin/bash"]