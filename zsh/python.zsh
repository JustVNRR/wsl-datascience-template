# ============================================================
# PYTHON RUNTIME: UV
# ============================================================

# Ensure uv tool binaries (copier, cruft, etc.) are in PATH
export PATH="$HOME/.local/bin:$PATH"

# Enable completions for uv and uvx
if command -v uv &>/dev/null; then
    eval "$(uv generate-shell-completion zsh)"
    eval "$(uvx --generate-shell-completion zsh 2>/dev/null)"
fi