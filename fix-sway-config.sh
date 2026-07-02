#!/bin/bash
# Copy user sway config to system location
set -e
cp /etc/sway/config /etc/sway/config.bak
cp /home/sh20fk/.config/sway/config /etc/sway/config
echo "Done! sway will now use your config by default."
