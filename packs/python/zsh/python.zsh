# ============================================================
# PYTHON RUNTIME: UV
# ============================================================
# This file is the pack's: the socle reads it where it lives
# (~/.config/packs/python/zsh/python.zsh) and copies nothing anywhere - a pack
# that goes takes its shell configuration with it.

# Ensure uv tool binaries (copier, cruft, etc.) are in PATH
export PATH="$HOME/.local/bin:$PATH"

# Enable completions for uv and uvx
if command -v uv &>/dev/null; then
    eval "$(uv generate-shell-completion zsh)"
    eval "$(uvx --generate-shell-completion zsh 2>/dev/null)"
fi
