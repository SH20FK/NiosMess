#!/bin/bash
# === Install greetd with AUTOLOGIN ===
# Run: sudo bash "/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/install-greetd.sh"
set -e

echo "=== Installing greetd + tuigreet ==="
apt-get update
apt-get install -y greetd tuigreet

echo ""
echo "=== Configuring greetd (autologin -> sway) ==="

# Autologin straight to sway, no login screen
cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --sessions /usr/share/wayland-sessions --greeting 'Welcome! F1 = change session'"
user = "greeter"
EOF

# Ensure sway.desktop exists
mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/sway.desktop << 'EOF'
[Desktop Entry]
Name=Sway
Comment=Wayland tiling compositor
Exec=sway
Type=Application
DesktopNames=sway
EOF

# Disable slimski
if [ -d /etc/runit/runsvdir/default/slimski ]; then
    mv /etc/runit/runsvdir/default/slimski /etc/runit/runsvdir/default/slimski.disabled 2>/dev/null
    echo "Disabled slimski"
fi

# Enable greetd via runit
mkdir -p /etc/runit/runsvdir/default/greetd
cat > /etc/runit/runsvdir/default/greetd/run << 'RUNEOF'
#!/bin/sh
exec greetd -c /etc/greetd/config.toml
RUNEOF
chmod +x /etc/runit/runsvdir/default/greetd/run

# Enable via 66 tool if available
if command -v 66-enable &>/dev/null; then
    66-enable greetd 2>/dev/null || true
fi

echo ""
echo "=== DONE ==="
echo "Reboot. Sway will load automatically."
echo "If you need to switch session: F1 at greetd screen."
