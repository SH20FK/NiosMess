#!/bin/bash
# === FINAL FIX: Make Sway appear in slimski login ===
# Run: sudo bash "/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/fix-sway-login.sh"
set -e

# Copy sway.desktop to xsessions (so slimski shows it)
cp /usr/share/wayland-sessions/sway.desktop /usr/share/xsessions/sway.desktop

# Ensure wayland-sessions also has it
mkdir -p /usr/share/wayland-sessions
cp /usr/share/xsessions/sway.desktop /usr/share/wayland-sessions/sway.desktop

echo "=== DONE ==="
echo "Reboot now."
echo "At login screen, press F1 to switch session to 'Sway'"
echo "Then login. Sway will start."
