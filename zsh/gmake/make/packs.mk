# ==============================================================================
# THE PACKS THIS INSTANCE CARRIES
# ==============================================================================
# A pack is installed when its folder is in ~/.config/packs - the folder IS the
# state, here as everywhere else. This module reads those folders and says what
# they are, which is the question you would otherwise answer by opening the
# cheatsheet picker and hunting for a command.
#
# One line per pack, and only what this can know: the name and the description
# from the pack's own pack.conf. What a pack brings is what `gmake help` and the
# picker are for; repeating any of it here would be a second list to keep in
# step, and a line that says "look in the picker" says nothing at all when the
# picker holds hundreds of commands.
#
# It lists what the user CHOSE, not everything the folder holds: a pack marked
# PACK_VISIBLE := no is a shared dependency of the packs that require it - the
# engine several models share, which is not a car and is not listed with them.
# So the list answers "what did I ask for?".
#
# It can come out empty while a pack is installed, and that is not the same
# thing as an instance with no pack: an invisible one is left alone only if the
# removal that should have taken it away stopped half way. The command says
# which of the two it is rather than print a header over nothing.
#
# What it cannot say is what is AVAILABLE: that is what the checkout on Windows
# carries, and an instance does not know which checkout fed it. `.\wsl.ps1
# add_pack` lists those, and it and `.\wsl.ps1 manage_packs` are where a pack
# arrives or leaves.
#
# It names no pack and tests no binary, for the reason the menu does not either:
# the folder is the whole switch.

packs_list: ## List the packs this instance carries
	@if [ ! -d "$(PACKS_DIR)" ] || [ -z "$$(ls -A "$(PACKS_DIR)" 2>/dev/null)" ]; then \
		echo ""; \
		echo "No pack is installed in this instance."; \
		echo ""; \
		echo "A pack is added from Windows:  .\wsl.ps1 add_pack"; \
	else \
		echo ""; \
		echo "Packs installed in this instance:"; \
		echo ""; \
		chosen=0; \
		for dir in "$(PACKS_DIR)"/*/; do \
			[ -f "$${dir}pack.conf" ] || continue; \
			visible=$$(sed -n 's/^PACK_VISIBLE *:=[[:space:]]*//p' "$${dir}pack.conf"); \
			[ "$$visible" = "no" ] && continue; \
			name=$$(basename "$$dir"); \
			desc=$$(sed -n 's/^PACK_DESCRIPTION *:=[[:space:]]*//p' "$${dir}pack.conf"); \
			printf "  \033[36m%-10s\033[0m %s\n" "$$name" "$$desc"; \
			chosen=$$((chosen + 1)); \
		done; \
		if [ $$chosen -eq 0 ]; then \
			echo "  Nothing you chose: what is left is a pack another one required,"; \
			echo "  and the pack that required it is gone."; \
		fi; \
		echo ""; \
		echo "A pack is added or removed from Windows:  .\wsl.ps1 add_pack  /  .\wsl.ps1 manage_packs"; \
	fi
