FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Remove default 'ubuntu' user created in Noble 24.04 base images
RUN userdel -r ubuntu 2>/dev/null || true

# Remove all dpkg drop-in filters so documentation and examples (like fzf bindings) are installed
RUN rm -f /etc/dpkg/dpkg.cfg.d/*

# 1. Install prerequisites for third-party repositories and core networking tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Configure third-party APT repositories (GitHub CLI, Google Cloud SDK, eza)
#
# The Google Cloud SDK repository is configured here but its package is not
# installed below: it weighs 409 MB and not every project uses Google Cloud.
# `gmake gcp_install` adds it on demand. Preparing the repository at build time
# is what keeps that target to a single apt-get, with nothing to fetch, sign or
# trust at runtime.
RUN mkdir -p -m 755 /etc/apt/keyrings \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list \
    # Google Cloud SDK
    && curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
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
    # Database CLI (the Google Cloud CLI is not installed here - see section 2:
    # its apt repository is ready, `gmake gcp_install` pulls the package)
    sqlite3 \
    # Build tools for compiling Python wheels & C-extensions
    build-essential \
    python3-dev \
    libffi-dev \
    libssl-dev \
    # Computer Vision & OCR dependencies
    ffmpeg \
    imagemagick \
    tesseract-ocr \
    libtesseract-dev \
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

# 4. Install prompt (Starship), Python manager (uv), tealdeer
RUN ARCH=$(dpkg --print-architecture) \
    && if [ "$ARCH" = "amd64" ]; then STARSHIP_ARCH="x86_64"; else STARSHIP_ARCH="aarch64"; fi \
    && curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-${STARSHIP_ARCH}-unknown-linux-gnu.tar.gz" -o starship.tar.gz \
    && tar -xzf starship.tar.gz -C /usr/local/bin \
    && rm starship.tar.gz \
    && curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh \
    && curl -fsSL "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-${STARSHIP_ARCH}-musl" -o /usr/local/bin/tldr \
    && chmod +x /usr/local/bin/tldr

# 5. Clone Oh-My-Zsh, custom plugins, and NVM into user skeleton
RUN git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /etc/skel/.local/share/oh-my-zsh \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
       /etc/skel/.local/share/oh-my-zsh/custom/plugins/zsh-syntax-highlighting \
    && git clone --depth=1 https://github.com/nvm-sh/nvm.git /etc/skel/.nvm

# Copy modular Zsh configuration to the user skeleton directory
COPY zsh /etc/skel/.config/zsh

# Bootstrap ZDOTDIR and create skeleton SSH directory
RUN echo 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' > /etc/skel/.zshenv \
    && echo 'skip_global_compinit=1' >> /etc/skel/.zshenv \
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