# ==========================================
# WEB BROWSER CHEATSHEET
# requires: firefox
# ==========================================
# Firefox, which the `web` pack installs (`.\wsl.ps1 add_pack`), and the one
# function the pack adds. The pack is removed the same way; its page is
# packs/web/docs/web.md.
# Offered only while the browser is installed - the header above is what hides
# the sheet when it was removed by hand.

# --- 1. OPEN ---
fox                                            # Open Firefox (the pack's function)
firefox                                        # ... the command itself
fox https://example.com                        # Open a page
fox --private-window                           # A private window
fox --new-window                               # A new window, even if one is open
fox https://example.com/report.pdf             # A URL with a query string, quoted if it has &

# --- 2. WHEN SOMETHING IS WRONG ---
fox --safe-mode                                # Start without extensions or hardware acceleration
fox --version                                  # Which version is installed
MOZ_ENABLE_WAYLAND=0 fox                       # Force X11, when the mouse misbehaves
ls ~/.mozilla/firefox                          # The profiles: bookmarks, passwords, history

# --- 3. FILES ON THIS MACHINE ---
fox "$(wslpath 'C:\Users')"                    # Open a Windows folder through /mnt/c
xdg-open report.pdf                            # Open any file with the default application
