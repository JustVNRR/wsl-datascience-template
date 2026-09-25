# ==============================================================================
# MAIN ZSH CONFIGURATION (.zshrc)
# ==============================================================================

# --- 1. ENVIRONMENT & FOUNDATIONS ---
# Global variables and runtime engines must load before dependent modules
source "$ZDOTDIR/exports.zsh"
source "$ZDOTDIR/fzf.zsh"          # Defines preview templates and underlying fuzzy commands
source "$ZDOTDIR/history.zsh"      # History size, file path, and shell persistence options

# --- 2. OH-MY-ZSH CORE CONFIGURATION ---
export ZSH="$HOME/.local/share/oh-my-zsh"
ZSH_THEME=""                 # Disabled: prompt handled by Starship
ZSH_DISABLE_COMPFIX=true     # Skip security check on completion directories (faster startup)

# Active plugins
# Note: Syntax highlighting and autosuggestions MUST remain at the end.
plugins=(
    # --- Core Utilities ---
    git
    common-aliases
    last-working-dir

    # --- Navigation & History Search ---
    history-substring-search
    fzf

    # --- Environment & Tooling ---
    ssh-agent
    direnv
    docker
    docker-compose

    # --- Interactive UI & Completions ---
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# SSH-agent plugin configuration (quiet startup)
zstyle :omz:plugins:ssh-agent quiet yes
zstyle :omz:plugins:ssh-agent lazy yes

# Initialize Oh My Zsh
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump-${SHORT_HOST:-$(hostname)}-${ZSH_VERSION}"
source "${ZSH}/oh-my-zsh.sh"



# --- 3. COMMANDS, ALIASES & SHELL UTILITIES ---
source "$ZDOTDIR/aliases.zsh"      # Command shortcuts and interactive falias tool
source "$ZDOTDIR/navigation.zsh"   # Directory hopping and fuzzy file pickers (cdv, cda, fv, fa)
source "$ZDOTDIR/unzip.zsh"        # Interactive archive extraction handler
source "$ZDOTDIR/cheatsheet.zsh"   # Custom cheatsheet selector (fcheat)
source "$ZDOTDIR/scaffold.zsh"     # Interactive project scaffolding picker (fnew)

# --- 4. ZLE KEYBINDINGS ---
# Keybindings must load AFTER all custom functions and widgets are declared in memory
source "$ZDOTDIR/bindings.zsh"

# --- 5. DEVELOPMENT RUNTIMES ---
source "$ZDOTDIR/python.zsh"

# --- 6. PROMPT ENGINE ---
# Executed last to ensure runtime hooks and aliases are fully registered
source "$ZDOTDIR/prompts/starship.zsh"

# --- 7. WSL STARTUP DIRECTORY RESOLUTION ---
# If opened from a mounted Windows volume (/mnt/*), restore last working directory or fallback to Linux home
if [[ "$PWD" == /mnt/* ]]; then
    lwd 2>/dev/null || cd ~
fi