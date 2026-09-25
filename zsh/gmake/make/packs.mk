# ==============================================================================
# THE PACKS THIS INSTANCE CARRIES
# ==============================================================================
# A pack is installed when its folder is in ~/.config/packs - the folder IS the
# state, here as everywhere else. This module reads those folders and says what
# they are, which is the question you would otherwise answer by opening the
# cheatsheet picker and looking for a command.
#
# What it cannot say is what is AVAILABLE: that is what the checkout on Windows
# carries, and an instance does not know which checkout fed it. `.\wsl.ps1
# add_pack` lists those, and it and `.\wsl.ps1 manage_packs` are where a pack
# arrives or leaves.
#
# It names no pack and tests no binary, for the reason the menu does not either:
# the folder is the whole switch.

packs_list: ## List the packs this instance carries, and what each brings
	@if [ ! -d "$(PACKS_DIR)" ] || [ -z "$$(ls -A "$(PACKS_DIR)" 2>/dev/null)" ]; then \
		echo ""; \
		echo "No pack is installed in this instance."; \
		echo ""; \
		echo "A pack is added from Windows:  .\wsl.ps1 add_pack"; \
	else \
		echo ""; \
		echo "Packs installed in this instance:"; \
		for dir in "$(PACKS_DIR)"/*/; do \
			[ -f "$${dir}pack.conf" ] || continue; \
			name=$$(basename "$$dir"); \
			desc=$$(sed -n 's/^PACK_DESCRIPTION *:=[[:space:]]*//p' "$${dir}pack.conf"); \
			printf "\n  \033[36m%-10s\033[0m %s\n" "$$name" "$$desc"; \
			count=$$(grep -hoE '^[a-zA-Z_-]+:.*##' "$${dir}make/"*.mk 2>/dev/null | sort -u | wc -l); \
			if [ "$$count" -gt 0 ]; then \
				label=targets; [ "$$count" -eq 1 ] && label=target; \
				echo "             gmake: $$count $$label, listed by gmake help"; \
			elif [ -d "$${dir}cheatsheets" ]; then \
				echo "             its commands are in the cheatsheet picker (fcheat)"; \
			fi; \
		done; \
		echo ""; \
		echo "Their commands: gmake help, or the cheatsheet picker (fcheat)."; \
		echo "A pack is added or removed from Windows:  .\wsl.ps1 add_pack  /  .\wsl.ps1 manage_packs"; \
	fi
