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

# --- 4. ZLE KEYBINDINGS ---
# Keybindings must load AFTER all custom functions and widgets are declared in memory
source "$ZDOTDIR/bindings.zsh"

# --- 5. PACKS ---
# Each installed pack's shell files, read where they live. A pack's folder is
# the whole switch, exactly as it is for its gmake modules: nothing is copied
# into this directory, so a pack that leaves takes its zsh with it - and an
# instance carrying no pack reads nothing here at all.
#
# The list is looked at again before every prompt, the way `gmake` asks its
# question at every run and `fcheat` at every opening. A pack installed from
# Windows while this shell was open is a command that answers on the next
# prompt; a pack removed stops being read. When the list has changed the shell
# restarts: that is `exec zsh` done by itself, and the only way to lose what a
# departed pack had defined - nothing here can undefine a function it never
# named, and no command from outside can reach into a running shell.
# [@] and not $var: in zsh, "$array" of an EMPTY array is one empty word, and
# this loop would then source "" - an instance carrying no pack is the case
# that must work, not the one that crashes.
typeset -ga _pack_zsh_loaded
_pack_zsh_loaded=("$ZDOTDIR"/../packs/*/zsh/*.zsh(N))
for _pack_zsh in "${_pack_zsh_loaded[@]}"; do
    source "$_pack_zsh"
done
unset _pack_zsh

_pack_zsh_follow() {
    local -a now
    now=("$ZDOTDIR"/../packs/*/zsh/*.zsh(N))
    [[ "${(j: :)_pack_zsh_loaded}" == "${(j: :)now}" ]] && return 0
    print -r -- "📦 the packs changed — restarting the shell"
    exec zsh
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _pack_zsh_follow

# --- 6. PROMPT ENGINE ---
# Executed last to ensure runtime hooks and aliases are fully registered
source "$ZDOTDIR/prompts/starship.zsh"

# --- 7. WSL STARTUP DIRECTORY RESOLUTION ---
# If opened from a mounted Windows volume (/mnt/*), restore last working directory or fallback to Linux home
if [[ "$PWD" == /mnt/* ]]; then
    lwd 2>/dev/null || cd ~
fi