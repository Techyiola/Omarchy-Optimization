#!/bin/bash
# Basic Arch install script for quality of life improvements

# Update system
sudo pacman -Syu
yay

# Remove common junk (edit this list)
yay -S fish nano catnap linux-wifi-hotspot hostapd dnsmasq pacman-contrib zen-browser-bin yazi 
# Remove orphans
sudo pacman -Rns $(pacman -Qdtq)

# Install a darker theme for omarchy
# omarchy-theme-install https://github.com/atif-1402/omarchy-latchdark-theme.git

# Waybar theme from HANCORE-linux project 2.9b theme
git clone https://github.com/HANCORE-linux/waybar-themes.git /tmp/repo && cp -rf /tmp/repo/config/V2.9b/. ~/.config/waybar && rm -rf /tmp/repo && omarchy-restart-waybar


# Delete the crap 
rm -rf ~/.cache/*
paccache -rk0

# Done
echo "Done."
