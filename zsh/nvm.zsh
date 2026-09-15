# ============================================================
# NODE.JS RUNTIME MANAGEMENT (NVM)
# ============================================================

export NVM_DIR="$HOME/.nvm"

# Fast-load NVM without triggering heavy default node resolution
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    \. "$NVM_DIR/nvm.sh" --no-use
fi

# Load bash completion only if file exists
if [[ -s "$NVM_DIR/bash_completion" ]]; then
    \. "$NVM_DIR/bash_completion"
fi

# ------------------------------------------------------------
# AUTOMATIC .nvmrc RESOLUTION VIA ZSH HOOK
# ------------------------------------------------------------
autoload -U add-zsh-hook

load-nvmrc() {
    # Ensure nvm function exists in current environment
    (( $+functions[nvm] )) || return 0

    local nvmrc_path
    nvmrc_path="$(nvm_find_nvmrc 2>/dev/null)"

    if [[ -n "$nvmrc_path" ]]; then
        local node_version nvmrc_node_version
        node_version="$(nvm version)"
        nvmrc_node_version="$(nvm version "$(cat "$nvmrc_path")")"

        if [[ "$nvmrc_node_version" == "N/A" ]]; then
            nvm install
        elif [[ "$nvmrc_node_version" != "$node_version" ]]; then
            nvm use --silent
        fi
    elif [[ -n "$(nvm version default 2>/dev/null)" && "$(nvm version)" != "$(nvm version default)" ]]; then
        nvm use default --silent
    fi
}

# Attach hook to directory change (chpwd) and run once on initial load
if (( $+functions[nvm] )); then
    add-zsh-hook chpwd load-nvmrc
    load-nvmrc
fi