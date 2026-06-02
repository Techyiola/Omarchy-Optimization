#!/usr/bin/env bash
# =============================================================================
#  omarchy-setup.sh — Reusable post-install script for Omarchy Linux
#  Run after a fresh Omarchy install:  bash omarchy-setup.sh
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR]${RESET}   $*" >&2; exit 1; }
section() { echo -e "\n${BOLD}━━━  $*  ━━━${RESET}"; }

# ── Must not run as root ──────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && error "Do not run this script as root. Run as your normal user."

# =============================================================================
#  0. CONFIGURATION — edit these to suit your setup
# =============================================================================

GIT_NAME="Your Git name"
GIT_EMAIL="Your git email"

# Packages to install via paru (AUR + official repos)
#AUR_PACKAGES=(
#    brave-bin                   # FIX: was 'brave-origin-beta-bin' (not a real AUR package)
#    catnap                      # CLI system info fetcher
#    linux-wifi-hotspot          # Wi-Fi hotspot manager
#    fish
#    haruna                        # Fish shell
#)
###the above part seems to be broken in most times will fix it in next update 
# Packages to install via pacman (official repos)
PACMAN_PACKAGES=(
    nano
    dnsmasq
    hostapd
)

# Packages to REMOVE (Omarchy defaults you don't want)
REMOVE_PACKAGES=(
    chromium
    claude-code
    signal-desktop
    libreoffice-fresh
    typora
    xournalpp
    1password-cli
    1password-beta
    aether
)

# Kernel + bootloader packages
KERNEL_PACKAGES=(
    linux-cachyos-rt-bore
    linux-cachyos-rt-bore-headers
    limine-mkinitcpio         # limine mkinitcpio preset
)

# =============================================================================
#  1. SYSTEM UPDATE
# =============================================================================
section "System Update"
info "Updating system packages…"
sudo pacman -Syu --noconfirm
success "System up to date."

# =============================================================================
#  2. SETUP PARU (AUR helper)
# =============================================================================
section "AUR Helper — paru"
if command -v paru &>/dev/null; then
    success "paru is already installed, skipping."
else
    info "Installing paru…"
    sudo pacman -S --needed --noconfirm base-devel git

    # FIX: use a subshell instead of pushd/popd so a clone failure doesn't
    #      leave us in a wrong directory
    PARU_TMP=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$PARU_TMP/paru" \
        || error "Failed to clone paru — check your internet connection."
    (
        cd "$PARU_TMP/paru"
        makepkg -si --noconfirm
    )
    rm -rf "$PARU_TMP"
    success "paru installed."
fi

# =============================================================================
#  3. REMOVE UNWANTED PACKAGES
# =============================================================================
section "Removing Unwanted Packages"

for pkg in "${REMOVE_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        info "Removing $pkg…"
        if ! sudo pacman -Rns --noconfirm "$pkg"; then
            warn "Could not remove $pkg (may have dependents — remove manually)."
        fi
    else
        warn "$pkg not found, skipping."
    fi
done
success "Cleanup done."

# =============================================================================
#  4. INSTALL PACMAN PACKAGES
# =============================================================================
section "Installing Official Repo Packages"
sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
success "Official packages installed."

# =============================================================================
#  5. INSTALL AUR PACKAGES
# =============================================================================
section "Installing AUR Packages"

# FIX: guard against paru not being available after Section 2
command -v paru &>/dev/null || error "paru is not available — AUR install in Section 2 may have failed."

paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
success "AUR packages installed."

# =============================================================================
#  6. INSTALL CACHYOS-RT-BORE KERNEL
# =============================================================================
section "CachyOS RT-BORE Kernel"

if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    info "Adding CachyOS repo and signing key…"

    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47

    # FIX: use a subshell instead of pushd/popd; also resolve package filenames
    #      dynamically so hardcoded version numbers don't break on future releases
    CACHY_TMP=$(mktemp -d)
    (
        cd "$CACHY_TMP"
        BASE_URL="https://mirror.cachyos.org/repo/x86_64/cachyos"

        # FIX: resolve current filenames from the repo index rather than hardcoding versions
        for pkg in cachyos-keyring cachyos-mirrorlist cachyos-v3-mirrorlist; do
            filename=$(curl -s "$BASE_URL/" \
                | grep -oP "href=\"\K${pkg}-[^\"]+\.pkg\.tar\.zst(?=\")" \
                | sort -V | tail -1)
            [[ -z "$filename" ]] && error "Could not find package $pkg in CachyOS repo."
            curl -O "$BASE_URL/$filename"
        done

        sudo pacman -U --noconfirm ./*.pkg.tar.zst
    )
    rm -rf "$CACHY_TMP"

    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# CachyOS repos
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF

    sudo pacman -Sy
    success "CachyOS repo added."
else
    success "CachyOS repo already present."
fi

info "Installing CachyOS RT-BORE kernel and headers…"
sudo pacman -S --needed --noconfirm "${KERNEL_PACKAGES[@]}"
success "Kernel installed."

# =============================================================================
#  7. FISH SHELL — set as default + pull end-4 fish configs
# =============================================================================
section "Fish Shell"

# FIX: check fish is actually available after AUR install
FISH_PATH=$(command -v fish 2>/dev/null || true)
[[ -z "$FISH_PATH" ]] && error "fish not found after install — Section 5 (AUR install) may have failed."

if ! grep -qx "$FISH_PATH" /etc/shells; then
    info "Adding $FISH_PATH to /etc/shells…"
    echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
fi

if [[ "$SHELL" != "$FISH_PATH" ]]; then
    info "Changing default shell to fish for $USER…"
    chsh -s "$FISH_PATH"
    success "Default shell set to fish. Takes effect on next login."
else
    success "Fish is already the default shell."
fi

# ── Pull fish configs from end-4/dots-hyprland (sparse clone) ────────────────
FISH_CONF_DIR="$HOME/.config/fish"
FISH_REPO_URL="https://github.com/end-4/dots-hyprland.git"

# FIX: use a subshell instead of pushd/popd
FISH_SPARSE_TMP=$(mktemp -d)
info "Sparse-cloning fish configs from end-4/dots-hyprland…"
(
    git clone \
        --depth=1 \
        --filter=blob:none \
        --sparse \
        "$FISH_REPO_URL" \
        "$FISH_SPARSE_TMP/dots-hyprland" \
        || error "Failed to clone dots-hyprland — check your internet connection."
    cd "$FISH_SPARSE_TMP/dots-hyprland"
    git sparse-checkout set "dots/.config/fish"
)

mkdir -p "$FISH_CONF_DIR"
cp -r "$FISH_SPARSE_TMP/dots-hyprland/dots/.config/fish/." "$FISH_CONF_DIR/"
rm -rf "$FISH_SPARSE_TMP"
success "Fish configs installed to $FISH_CONF_DIR"

# =============================================================================
#  8. ALACRITTY — set background opacity to 0.6
# =============================================================================
section "Alacritty Transparency"
ALACRITTY_CONF="$HOME/.config/alacritty/alacritty.toml"

if [[ -f "$ALACRITTY_CONF" ]]; then
    if grep -q "^\[window\]" "$ALACRITTY_CONF"; then
        if sed -n '/^\[window\]/,/^\[/p' "$ALACRITTY_CONF" | grep -q "^[[:space:]]*opacity"; then
            # FIX: scope the replacement to only lines between [window] and the next section
            #      to avoid clobbering opacity keys in other sections
            awk '
                /^\[window\]/ { in_window=1 }
                /^\[/ && !/^\[window\]/ { in_window=0 }
                in_window && /^[[:space:]]*opacity[[:space:]]*=/ { sub(/=.*/, "= 0.6") }
                { print }
            ' "$ALACRITTY_CONF" > "${ALACRITTY_CONF}.tmp" \
                && mv "${ALACRITTY_CONF}.tmp" "$ALACRITTY_CONF"
            info "Updated existing opacity value under [window]."
        else
            sed -i '/^\[window\]/a opacity = 0.6' "$ALACRITTY_CONF"
            info "Inserted opacity under [window]."
        fi
    else
        printf '\n[window]\nopacity = 0.6\n' >> "$ALACRITTY_CONF"
        info "Appended [window] section with opacity."
    fi
    success "Alacritty opacity set to 0.6."
else
    mkdir -p "$(dirname "$ALACRITTY_CONF")"
    cat > "$ALACRITTY_CONF" <<'EOF'
[window]
opacity = 0.6
EOF
    success "Created alacritty.toml with opacity = 0.6."
fi

# =============================================================================
#  9. GIT CONFIGURATION
# =============================================================================
section "Git Config"
git config --global user.name  "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
success "Git configured for $GIT_NAME <$GIT_EMAIL>."

# =============================================================================
#  10. REGENERATE INITRAMFS (after kernel install)
# =============================================================================
section "Regenerate Initramfs"
info "Running mkinitcpio for all presets…"
sudo limine-mkinitcpio -P
success "Initramfs regenerated."

# =============================================================================
#  11. DONE
# =============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗"
echo -e "║   Setup complete! Reboot recommended.    ║"
echo -e "╚══════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}Next steps:${RESET}"
echo -e "  • Fish configs from end-4/dots-hyprland are live in ${BOLD}~/.config/fish/${RESET}"
echo -e "  • Alacritty opacity is set to ${BOLD}0.6${RESET} in ~/.config/alacritty/alacritty.toml"
echo -e "  • Reboot to boot into the CachyOS RT-BORE kernel"
echo ""
