# ==========================================
# CLAUDE CODE CHEATSHEET
# requires: claude
# ==========================================
# The `claude` pack: Anthropic's agentic CLI, in the instance. It is a terminal
# program and nothing else, and it installs itself under ~/.local - no apt
# package, no root, no Node. The pack installs from Windows
# (`.\wsl.ps1 add_pack`), its page is packs/claude/docs/claude.md, and the
# module behind these targets is make/claude.mk.
# Offered only while the program is on the PATH - the header above hides the
# sheet when it was removed by hand.

# --- 1. WHAT THIS INSTANCE HAS ---
gmake claude_status                            # Version, versions kept, the login
claude --version                               # The version alone
claude auth status                             # loggedIn, authMethod, apiProvider (JSON)
claude doctor                                  # The CLI's own check-up

# --- 2. WHAT TAKES THE SPACE ---
du -sh ~/.local/share/claude                   # Every version ever installed
ls -l ~/.local/share/claude/versions/          # ... one file per version
claude project purge --dry-run                 # What one project's history takes

# --- 3. THE FIRST RUN, AND WHEN SOMETHING IS STUCK ---
claude                                         # Open a session here (it asks you to log in once)
claude auth logout                             # Forget the login of this instance
claude update                                  # Update now (it also updates itself at startup)
bash ~/.config/packs/claude/install.sh         # Put the program back when it was removed by hand
