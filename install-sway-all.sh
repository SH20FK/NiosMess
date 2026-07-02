#!/bin/bash
# === ALL-IN-ONE: Install Sway + Wayland + configs ===
# Run: sudo bash "/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/install-sway-all.sh"
set -e

echo "=== Installing Sway + Wayland stack ==="

apt-get update
apt-get install -y \
    sway swaybg swaylock swayidle \
    waybar wofi foot \
    wl-clipboard grim slurp mako-notifier \
    xdg-desktop-portal-wlr xwayland \
    brightnessctl mate-polkit \
    fonts-jetbrains-mono fonts-firacode \
    pipewire wireplumber pipewire-pulse \
    arc-theme papirus-icon-theme

echo ""
echo "=== Installing fonts ==="
apt-get install -y fonts-noto fonts-noto-color-emoji || true

echo ""
echo "=== All done! ==="
echo ""
echo "To launch sway:"
echo "  1. Logout from IceWM"
echo "  2. On TTY type: sway"
echo ""
echo "Keybinds:"
echo "  Super+Enter    = Terminal"
echo "  Super+D        = App launcher"
echo "  Super+Shift+Q  = Close window"
echo "  Super+Shift+E  = Exit sway"
echo "  Super+1-9      = Switch workspace"
echo "  Super+HJKL     = Move focus (vim)"
