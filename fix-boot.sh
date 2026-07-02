#!/bin/bash
# === NUCLEAR FIX: Kill slimski, configure greetd properly ===
# Run: sudo bash "/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/fix-boot.sh"
set -e

echo "=== [1/4] Killing slimski + Xorg ==="
pkill -9 slimski 2>/dev/null || true
pkill -9 Xorg 2>/dev/null || true
pkill -9 -f "runsv.*slimski" 2>/dev/null || true

echo "=== [2/4] Removing slimski symlink ==="
# MUST remove symlink, not just rename
rm -f /etc/runit/runsvdir/default/slimski.disabled
rm -f /etc/runit/runsvdir/default/slimski
echo "  slimski symlink removed"

echo "=== [3/4] Fix greetd config ==="
cat > /etc/greetd/config.toml << 'EOF'
[terminal]
vt = 7

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --sessions /usr/share/wayland-sessions --greeting 'Welcome! F1 = change session'"
user = "greeter"
EOF

echo "=== [4/4] Restart greetd ==="
pkill -9 greetd 2>/dev/null || true
sleep 1
# runit will auto-restart greetd

echo ""
echo "=== DONE ==="
echo "Switch to TTY7: Ctrl+Alt+F7"
echo "You should see tuigreet login screen there."
