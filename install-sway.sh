#!/bin/bash
# === INSTALL SWAY + WAYLAND STACK ===
# Run with: sudo bash install-sway.sh
set -e

echo "=== Installing Sway + Wayland ==="

# Core Wayland
apt-get install -y \
    sway \
    swaybg \
    swaylock \
    swayidle \
    waybar \
    wofi \
    wl-clipboard \
    grim \
    slurp \
    mako \
    xdg-desktop-portal-wlr \
    xwayland

echo ""
echo "=== Installing utilities ==="
apt-get install -y \
    foot \
    brightnessctl \
    polkit-gnome \
    gtk3-nocsd \
    fonts-jetbrains-mono \
    fonts-firacode \
    pipewire \
    wireplumber \
    pipewire-pulse

echo ""
echo "=== Installing GTK themes ==="
apt-get install -y \
    arc-theme \
    papirus-icon-theme \
    oxygen-cursors

echo ""
echo "=== Sway + Wayland installed! ==="
echo ""
echo "How to launch:"
echo "  1. Logout from IceWM (Ctrl+Alt+Backspace or exit)"
echo "  2. On TTY login, type: sway"
echo "  3. Or add to ~/.xinitrc: exec sway"
echo ""
echo "Key bindings in sway:"
echo "  Super+Enter    -> Terminal (foot)"
echo "  Super+D        -> Launcher (wofi)"
echo "  Super+Shift+Q  -> Close window"
echo "  Super+Shift+E  -> Exit sway"
echo "  Super+1-9      -> Switch workspace"
echo "  Super+Shift+1-9 -> Move window to workspace"
