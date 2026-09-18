# ==========================================
# OLLAMA (LOCAL MODELS)
# ==========================================
# requires: ollama
#
# Shown only once the server is installed — before that there is nothing to
# drive. The guide, including how to install it, is docs/ollama.md. The server
# itself runs as a systemd service on port 11434.

# --- 1. MODELS ON THIS MACHINE ---
ollama list                              # The models downloaded here, with their size
ollama pull <model>                      # Download a model (a few GB — start small)
ollama show <model>                      # What a model is: size, parameters, template
ollama rm <model>                        # Delete a downloaded model (frees its space)

# --- 2. RUNNING ONE ---
ollama run <model>                       # Chat with it in the terminal (downloads it if missing)
ollama ps                                # Which models are loaded in memory right now

# --- 3. THE SERVER ---
ollama serve                             # Run it in the foreground (systemd already does it at boot)
systemctl status ollama                  # Is the server up? (systemd is enabled in this distro)
curl -s localhost:11434/api/tags         # What the server answers, as the clients see it
