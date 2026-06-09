#!/bin/bash
# Basic Arch bloat removal

# Remove orphans
sudo pacman -Rns $(pacman -Qdtq)

# Clean cache
sudo pacman -Scc

# Remove common junk (edit this list)
sudo pacman -Rns chromium libreoffice-fresh signal-desktop spotify typora xournalpp kdenlive obsidian 1password-beta 1password-cli aether pinta

# Done
echo "Done."
