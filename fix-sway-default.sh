#!/bin/bash
# === Fix Sway as default session ===
# Run: sudo bash "/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/fix-sway-default.sh"
set -e

# Create proper sway.desktop that works with Xsession
cat > /usr/share/xsessions/sway.desktop << 'EOF'
[Desktop Entry]
Name=Sway
Comment=Wayland tiling compositor
Exec=/usr/local/bin/start-sway
Type=Application
DesktopNames=sway
EOF

# Create wrapper script that launches sway properly
cat > /usr/local/bin/start-sway << 'WRAPPER'
#!/bin/bash
# Stop X and start Wayland compositor
if [ -n "$DISPLAY" ]; then
    # Kill X server to start Wayland
    killall Xorg 2>/dev/null || true
    sleep 1
fi
exec sway
WRAPPER
chmod +x /usr/local/bin/start-sway

# Set default session in slimski
sed -i 's/^#default_sessiontype.*/default_sessiontype sway/' /etc/slimski.conf 2>/dev/null || true
if ! grep -q "^default_sessiontype" /etc/slimski.conf; then
    echo "default_sessiontype sway" >> /etc/slimski.conf
fi

# Set default_user
sed -i 's/^#default_user.*/default_user sh20fk/' /etc/slimski.conf 2>/dev/null || true

echo "=== Fixed! ==="
echo "Reboot and Sway should be default."
echo "If it still shows IceWM, press F1 at login screen to switch to Sway."
