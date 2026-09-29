# ============================================================
# PYTHON RUNTIME: UV
# ============================================================
# This file is the pack's: the socle reads it where it lives
# (~/.config/packs/python/zsh/python.zsh) and copies nothing anywhere - a pack
# that goes takes its shell configuration with it.

# Ensure uv tool binaries (copier, cruft, etc.) are in PATH
export PATH="$HOME/.local/bin:$PATH"

# Enable completions for uv and uvx - the pack's own uv, at the path this pack
# installs it to, never whatever `uv` the PATH happens to resolve to: the PATH
# carries WSL's Windows directories, and a Windows program evaluated here would
# run at every shell start (the shape the claude pack paid for, 2026-09-29).
if [ -x "$HOME/.local/bin/uv" ]; then
    eval "$("$HOME/.local/bin/uv" generate-shell-completion zsh)"
    eval "$("$HOME/.local/bin/uvx" --generate-shell-completion zsh 2>/dev/null)"
fi
