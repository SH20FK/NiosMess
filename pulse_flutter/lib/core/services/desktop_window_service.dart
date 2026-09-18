import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

/// Manages desktop window lifecycle, system tray, and taskbar alerts.
class DesktopWindowService with WindowListener, TrayListener {
  DesktopWindowService._();

  static final DesktopWindowService instance = DesktopWindowService._();

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  bool _initialized = false;
  bool _isFlashing = false;

  /// Initializes window bounds, constraints, system tray, and taskbar integration.
  Future<void> initialize() async {
    if (!isDesktop || _initialized) return;
    _initialized = true;

    try {
      await windowManager.ensureInitialized();

      const WindowOptions windowOptions = WindowOptions(
        size: Size(1100, 750),
        minimumSize: Size(680, 520),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'NiosMess',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // Prevent closing directly so we can minimize to tray
      await windowManager.setPreventClose(true);
      windowManager.addListener(this);

      await _setupSystemTray();
    } catch (e) {
      debugPrint('[DesktopWindowService] Window initialization failed: $e');
    }
  }

  Future<void> _setupSystemTray() async {
    try {
      trayManager.addListener(this);

      // Extract ico to temp directory for reliable native Windows loading
      String? iconPath;
      if (isWindows) {
        try {
          final ByteData data = await rootBundle.load('assets/app_icon.ico');
          final Directory tempDir = await getTemporaryDirectory();
          final File iconFile = File('${tempDir.path}/niosmess_tray.ico');
          await iconFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
          iconPath = iconFile.path;
        } catch (_) {
          // Fallback to relative path if bundle loading failed
          iconPath = 'windows/runner/resources/app_icon.ico';
        }
      } else {
        iconPath = 'assets/NiosMess_icon.png';
      }

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('NiosMess');

      final Menu menu = Menu(
        items: <MenuItem>[
          MenuItem(
            key: 'show_window',
            label: 'Открыть NiosMess',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit_app',
            label: 'Выйти',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('[DesktopWindowService] Tray setup failed: $e');
    }
  }

  /// Brings window to front and focuses it.
  Future<void> showWindow() async {
    if (!isDesktop) return;
    try {
      final bool isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      stopTaskbarFlashing();
    } catch (_) {}
  }

  /// Hides window to system tray.
  Future<void> hideWindow() async {
    if (!isDesktop) return;
    try {
      await windowManager.hide();
    } catch (_) {}
  }

  /// Quits application completely.
  Future<void> quitApp() async {
    if (!isDesktop) return;
    try {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      await windowManager.destroy();
    } catch (_) {
      exit(0);
    }
  }

  /// Flashes the taskbar icon to alert user of an incoming message.
  Future<void> flashTaskbar() async {
    if (!isWindows || _isFlashing) return;
    try {
      final bool isFocused = await windowManager.isFocused();
      if (isFocused) return;

      _isFlashing = true;
      await WindowsTaskbar.setFlashTaskbarAppIcon(
        mode: TaskbarFlashMode.all | TaskbarFlashMode.timernofg,
        flashCount: 5,
        timeout: const Duration(milliseconds: 500),
      );
    } catch (_) {}
  }

  /// Resets taskbar flashing once user returns or focuses the window.
  Future<void> stopTaskbarFlashing() async {
    if (!isWindows) return;
    try {
      _isFlashing = false;
      await WindowsTaskbar.resetFlashTaskbarAppIcon();
    } catch (_) {}
  }

  // ── WindowListener Callbacks ──────────────────────────────────────────────

  @override
  void onWindowClose() async {
    // Default behavior on desktop: minimize to tray on X
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await hideWindow();
    }
  }

  @override
  void onWindowFocus() {
    stopTaskbarFlashing();
  }

  // ── TrayListener Callbacks ────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      showWindow();
    } else if (menuItem.key == 'exit_app') {
      quitApp();
    }
  }
}
