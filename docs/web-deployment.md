# Web deployment

`https://ni-os.ru/web/` runs the Flutter Web artifact from the successful main Build & Release workflow. The previous JavaScript client is preserved at `https://ni-os.ru/old/web/` and is not kept in feature parity with Flutter.

The Publish Flutter Web workflow packages an existing successful artifact; it does not rebuild Android or Windows. Manual publication takes the source run ID. It checks that the source commit matches the published application version before uploading `niosmess-web.zip` and `web-version.json` to the latest release. Packaging sets `/web/` as the base path and serves CanvasKit locally. Root `/firebase-messaging-sw.js` points at the Flutter notification worker.

On the host, `/usr/local/lib/nios-web/update.py` runs through `nios-web-update.timer`. It downloads public release assets without a GitHub credential, requires matching native/web versions, verifies SHA256 and ZIP paths, then switches `/var/www/nios-flutter/current` atomically. A public release-info health check restores the previous symlink on failure. Nginx serves only static files; application services and databases are unchanged.

Inspect `systemctl status nios-web-update.timer` and `journalctl -u nios-web-update.service`. Release directories contain `deployment.json`. To roll back, point `current` to the previous verified directory under `/var/www/nios-flutter/releases` and stop the timer until the desired release is published. Initial route configuration backup is under `/var/backups/nios-ai-plus/web-flutter-*`; validate Nginx before reload. The legacy originals remain under `/var/www/nios-web`.

The legacy page uses `/old/web/app.js` and `/old/web/app.css`. `/web` and `/old/web` preserve query arguments when adding their trailing slash, including OAuth callbacks. Missing static Flutter assets return 404 rather than HTML. HTML and bootstrap use revalidation to avoid mixed versions.
