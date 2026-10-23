#!/usr/bin/env bash
set -euo pipefail
# Test-only devices: the browser must never open a runner's real camera or mic.
chrome_binary="$(command -v google-chrome || command -v chromium || command -v chromium-browser)"
exec "$chrome_binary" --use-fake-device-for-media-stream --use-fake-ui-for-media-stream "$@"
