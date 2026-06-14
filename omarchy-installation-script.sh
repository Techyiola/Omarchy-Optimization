#!/bin/bash
# Basic Arch install script for quality of life improvements

# Update system
sudo pacman -Syu
yay

# Remove common junk (edit this list)
yay -S fish nano catnap linux-wifi-hotspot hostapd dnsmasq pacman-contrib zen-browser-bin yazi pacman-contrib-git 

# Remove orphans
sudo pacman -Rns $(pacman -Qdtq)

# Install a darker theme for omarchy
# omarchy-theme-install https://github.com/atif-1402/omarchy-latchdark-theme.git


# Delete the crap 
rm -rf ~/.cache/*
paccache -rk0

# Done
echo "Done."
