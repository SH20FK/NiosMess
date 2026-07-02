#!/bin/bash
# === SYSTEM OPTIMIZATION FOR LOW-RAM (1.8GB) CODING + TG ===
# Run with: sudo bash optimize-system.sh
set -e

echo "============================================"
echo "  SYSTEM OPTIMIZATION - 1.8GB RAM + HDD"
echo "============================================"

echo ""
echo "=== [1/10] Fix swappiness conflict ==="
# Remove swappiness=100 from sysctl.conf (conflicts with sysctl.d)
sed -i '/^vm\.swappiness\s*=\s*100/d' /etc/sysctl.conf
# Also remove the old dirty_bytes that conflicts
sed -i '/^vm\.dirty_bytes/d' /etc/sysctl.conf
echo "  cleaned /etc/sysctl.conf"

echo ""
echo "=== [2/10] Sysctl optimization ==="
cat > /etc/sysctl.d/99-optimize.conf << 'EOF'
# === OPTIMIZED FOR LOW-RAM CODING ON HDD ===
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.min_free_kbytes=16384
vm.overcommit_memory=0
vm.zone_reclaim_mode=0
kernel.sched_autogroup_enabled=0
kernel.sched_min_granularity_ns=1000000
kernel.sched_wakeup_granularity_ns=1500000
net.core.somaxconn=1024
net.ipv4.tcp_max_syn_backlog=1024
net.core.netdev_max_backlog=1024
EOF
sysctl --system 2>/dev/null
echo "  swappiness=$(cat /proc/sys/vm/swappiness)"

echo ""
echo "=== [3/11] ZRAM (check/enhance) ==="
if zramctl /dev/zram0 2>/dev/null | grep -q zram; then
    echo "  ZRAM already active:"
    zramctl
else
    modprobe zram num_devices=1 2>/dev/null || true
    zramctl /dev/zram0 --algorithm lz4 --size 512M 2>/dev/null || true
    mkswap /dev/zram0 2>/dev/null || true
    swapon /dev/zram0 -p 100 2>/dev/null || true
    echo "  ZRAM started:"
    zramctl
fi

echo ""
echo "=== [4/11] ZRAM auto-setup on boot ==="
cat > /etc/zramswap.conf << 'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF
echo "  /etc/zramswap.conf written"

echo ""
echo "=== [5/11] IO Scheduler for HDD ==="
for dev in /sys/block/sd*/queue/scheduler; do
    echo "mq-deadline" > "$dev" 2>/dev/null && echo "  $dev -> mq-deadline" || true
done
blockdev --setra 4096 /dev/sdb 2>/dev/null || true
echo "  read-ahead=4096 for sdb"

echo ""
echo "=== [6/11] tmpfs for /tmp ==="
if ! mountpoint -q /tmp 2>/dev/null; then
    mount -t tmpfs -o size=256M,mode=1777,nodev,nosuid tmpfs /tmp
    echo "  /tmp -> tmpfs 256M"
else
    echo "  /tmp already special mount, skipped"
fi

echo ""
echo "=== [7/11] Kill unnecessary services ==="
for proc in at-spi2-registryd at-spi-bus-launcher smartd; do
    pkill -9 -f "$proc" 2>/dev/null && echo "  killed $proc" || true
done
if [ -d /etc/runit/runsvdir/default/smartmontools ]; then
    mv /etc/runit/runsvdir/default/smartmontools /etc/runit/runsvdir/default/smartmontools.disabled 2>/dev/null
    echo "  disabled smartmontools"
fi
if [ -d /etc/runit/runsvdir/default/anacron ]; then
    mv /etc/runit/runsvdir/default/anacron /etc/runit/runsvdir/default/anacron.disabled 2>/dev/null
    echo "  disabled anacron"
fi

echo ""
echo "=== [8/11] Disable transparent hugepages ==="
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null && echo "  THP disabled" || echo "  THP: not available"
echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true

echo ""
echo "=== [9/11] CPU governor ==="
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu" 2>/dev/null || true
done
echo "  CPU governor -> performance"

echo ""
echo "=== [10/11] Install earlyoom (OOM killer for low RAM) ==="
if ! which earlyoom >/dev/null 2>&1; then
    apt-get install -y earlyoom 2>/dev/null && echo "  earlyoom installed" || echo "  earlyoom install failed"
else
    echo "  earlyoom already installed"
fi
# Enable and start earlyoom
if which earlyoom >/dev/null 2>&1; then
    # For runit-based systems
    if [ ! -d /etc/runit/runsvdir/default/earlyoom ] && [ -d /etc/runit/runsvdir/default ]; then
        mkdir -p /etc/earlyoom
        cat > /etc/earlyoom/earlyoom.conf << 'EOFC'
# earlyoom config for 1.8GB RAM system
# Kill only when critically low (3% free) - compilation eats a lot
MIN_AVAIL_MEM=3
MIN_AVAIL_SWAP=3
# Don't kill Xorg, kitty, opencode, icewm, Telegram, build processes
IGNORE_LIST="Xorg|kitty|opencode|icewm|Legcord|happ|telegram|java|kotlin|gradle|dart|flutter|dart2native|javac|kotlinc"
EOFC
        # Create runit service
        mkdir -p /etc/runit/runsvdir/default/earlyoom
        cat > /etc/runit/runsvdir/default/earlyoom/run << 'EOFR'
#!/bin/sh
exec earlyoom -v --ignore="^(Xorg|kitty|opencode|icewm|Legcord|happ|telegram|java|kotlin|gradle|dart|flutter|dart2native|javac|kotlinc|fsck)" 2>&1
EOFR
        chmod +x /etc/runit/runsvdir/default/earlyoom/run
        echo "  earlyoom runit service created"
    fi
fi

echo ""
echo "=== [11/11] Drop caches ==="
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && echo "  caches dropped" || echo "  drop_caches: no permission"

echo ""
echo "============================================"
echo "  OPTIMIZATION COMPLETE"
echo "============================================"
echo ""
free -h
echo ""
echo "Summary:"
echo "  swappiness: 100 -> 10 (was conflicting with /etc/sysctl.conf, fixed)"
echo "  ZRAM: $(zramctl --raw --noheadings --output SIZE /dev/zram0 2>/dev/null || echo 'active') compressed swap"
echo "  IO: mq-deadline + 4096 read-ahead"
echo "  /tmp: tmpfs (no disk I/O)"
echo "  Killed: at-spi, smartd"
echo "  Disabled: smartmontools, anacron"
echo "  THP disabled, CPU performance"
echo ""
echo "RECOMMEND: reboot for full effect"
