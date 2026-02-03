import sys
import os
import ctypes
import winreg
from PyQt5.QtWidgets import QApplication
from login import AuthWindow

APP_NAME = "NiosMess"
AUTOSTART_REG = r"Software\Microsoft\Windows\CurrentVersion\Run"


def add_to_autostart():
    if getattr(sys, "frozen", False):  # проверяем, что это .exe через PyInstaller
        exe_path = sys.executable
        try:
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, AUTOSTART_REG, 0, winreg.KEY_SET_VALUE)
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, exe_path)
            winreg.CloseKey(key)
            print(f"[+] Добавлено в автозагрузку: {exe_path}")
        except Exception as e:
            print(f"[!] Ошибка автозапуска: {e}")


def hide_console():
    if sys.platform == "win32":
        ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)


def main():
    hide_console()
    add_to_autostart()
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    if "--nogui" not in sys.argv:
        w = AuthWindow()
        w.show()

    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
