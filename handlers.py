import os
import sys
import json
import requests
import threading
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *


SERVER_URL = "http://144.31.1.79:27580"
SESSION_FILE = os.path.join(os.path.expanduser("~"), "niosmess_session.json")
DOWNLOAD_DIR = os.path.join(os.path.expanduser("~"), "Downloads", "NiosMess")
if not os.path.exists(DOWNLOAD_DIR):
    os.makedirs(DOWNLOAD_DIR)

CORE_STYLE = """
QMainWindow { background-color: #1e1e1e; }
QWidget { background-color: #1e1e1e; color: #ffffff; font-family: 'Segoe UI', sans-serif; }
QLineEdit { background-color: #2b2b2b; border: 1px solid #3c3c3c; padding: 12px; border-radius: 10px; color: #ffffff; font-size: 16px; }
QListWidget { border: none; background: transparent; outline: none; }
QListWidget::item { padding: 18px; border-bottom: 1px solid #2d2d2d; font-size: 18px; font-weight: bold; }
QListWidget::item:selected { background-color: #37373d; border-left: 5px solid #00aaff; }
#SidePanel { background-color: #252526; border-right: 1px solid #333; }
#ProfilePanel { background-color: #1e1e1e; border-left: 1px solid #333; }
#Header { background-color: #252526; border-bottom: 1px solid #333; font-size: 18px; font-weight: bold; padding-left: 20px; color: #00aaff; text-align: left; border: none; }
#SendBtn { background-color: #00aaff; border-radius: 22px; color: white; font-weight: bold; font-size: 20px; border: none; }
#AttachBtn { background-color: #333333; border-radius: 22px; color: #aaa; font-size: 20px; border: none; }
#ErrorBar { background-color: #ff3333; color: white; font-weight: bold; border-bottom-left-radius: 10px; border-bottom-right-radius: 10px; }
"""

def get_my_token():
    try:
        if os.path.exists(SESSION_FILE):
            with open(SESSION_FILE, "r") as f:
                return json.load(f).get("token")
    except:
        pass
    return None


class AvatarLabel(QLabel):
    def __init__(self, size, parent=None):
        super().__init__(parent)
        self.setFixedSize(size, size)
        self.text = ""

    def set_letter(self, name):
        self.text = name[0].upper() if name else "?"
        self.update()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setBrush(QColor("#00aaff"))
        p.setPen(Qt.NoPen)
        p.drawEllipse(self.rect())
        p.setPen(QColor("white"))
        p.setFont(QFont("Segoe UI", 32, QFont.Bold))
        p.drawText(self.rect(), Qt.AlignCenter, self.text)


class ErrorNotify(QLabel):
    def __init__(self, parent):
        super().__init__(parent)
        self.setObjectName("ErrorBar")
        self.setFixedHeight(40)
        self.move(0, -40)
        self.setAlignment(Qt.AlignCenter)

    def show_err(self, t):
        self.setText(t)
        self.setFixedWidth(self.parent().width())
        self.raise_()
        self.anim = QPropertyAnimation(self, b"pos")
        self.anim.setDuration(200)
        self.anim.setStartValue(QPoint(0, -40))
        self.anim.setEndValue(QPoint(0, 0))
        self.anim.start()
        QTimer.singleShot(3000, lambda: self.move(0, -40))

class UploadWorker(QThread):
    finished = pyqtSignal(bool, str)

    def __init__(self, p, s, r, t):
        super().__init__()
        self.p, self.s, self.r, self.t = p, s, r, t

    def run(self):
        try:
            with open(self.p, 'rb') as f:
                r = requests.post(f"{SERVER_URL}/upload", files={'file': f},
                                  data={'sender': self.s, 'receiver': self.r, 'token': self.t})
                self.finished.emit(r.status_code == 200, "Ошибка сервера")
        except:
            self.finished.emit(False, "Нет связи")


class ChatBubble(QWidget):
    def __init__(self, text, is_me, is_file=False):
        super().__init__()
        self.is_file = is_file
        if is_file:
            raw = text.replace("FILE:", "").strip()
            if "." in raw:
                name_p, ext_p = raw.rsplit(".", 1)
                display_text = f"📄 {name_p[:5]}...{ext_p}"
            else:
                display_text = f"📄 {raw[:5]}..."
        else:
            display_text = text

        self.final_text = self.hard_wrap(display_text)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 3, 8, 3)

        self.frame = QFrame()
        self.frame.setStyleSheet(f"background-color: {'#00aaff' if is_me else '#333333'}; border-radius: 3px;")

        v = QVBoxLayout(self.frame)
        lbl = QLabel(self.final_text)
        lbl.setWordWrap(True)
        lbl.setStyleSheet("background:transparent; color: white; font-size: 14px;")
        v.addWidget(lbl)

        self.frame.setMaximumWidth(900)
        h = QHBoxLayout()
        if is_me:
            h.addStretch()
            h.addWidget(self.frame)
        else:
            h.addWidget(self.frame)
            h.addStretch()
        layout.addLayout(h)

    def hard_wrap(self, text, limit=40):
        if not text:
            return ""

        final_lines = []
        user_lines = text.split(" ^ ")

        for uline in user_lines:
            words = uline.split()
            current_line = []
            current_length = 0

            for word in words:
                if current_length + len(word) + (1 if current_line else 0) > limit:
                    final_lines.append(" ".join(current_line))
                    current_line = [word]
                    current_length = len(word)
                else:
                    if current_line:
                        current_line.append(word)
                        current_length += len(word) + 1
                    else:
                        current_line.append(word)
                        current_length = len(word)

            if current_line:
                final_lines.append(" ".join(current_line))
        print(" ^ ".join(final_lines))
        return " \n ".join(final_lines)

    def get_height(self):
        lines = 1 + self.final_text.count(' \n ')
        print(lines)
        add = 3
        if lines < 3:
            print(f"{lines}<3")
            return 70 + (lines * 26)
        else:
            print(lines)
            return 70 + (lines * 24)

class PhotoBubble(QWidget):
    def __init__(self, text, is_me):
        super().__init__()
        self.raw_text = text.replace("FILE:", "").strip()
        self.ext = self.raw_text.lower().split('.')[-1]
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 5, 10, 5)
        self.frame = QFrame()
        self.frame.setStyleSheet(f"background-color: {'#00aaff' if is_me else '#444444'}; border-radius: 12px;")
        v = QVBoxLayout(self.frame)
        self.preview = QLabel()
        self.preview.setAlignment(Qt.AlignCenter)
        self.preview.setMinimumSize(240, 180)
        self.preview.setStyleSheet("background: #000; border-radius: 8px;")

        if self.ext in ['jpg', 'jpeg', 'png', 'ico', 'bmp', 'gif']:
            self.preview.setText("Загрузка...")
            threading.Thread(target=self.load_image, daemon=True).start()
        else:
            self.preview.setText(f"🎵 АУДИО\n{self.raw_text[:15]}...")
            self.preview.setStyleSheet("font-size: 16px; color: #00aaff; background: #111; border-radius: 8px;")

        self.name_lbl = QLabel(self.raw_text)
        self.name_lbl.setStyleSheet("font-size: 10px; color: #ccc; background: transparent;")
        self.name_lbl.setAlignment(Qt.AlignCenter)
        v.addWidget(self.preview)
        v.addWidget(self.name_lbl)
        self.frame.setFixedWidth(270)
        h = QHBoxLayout()
        if is_me:
            h.addStretch()
            h.addWidget(self.frame)
        else:
            h.addWidget(self.frame)
            h.addStretch()
        layout.addLayout(h)

    def load_image(self):
        try:
            url = f"{SERVER_URL}/download/{self.raw_text}"
            data = requests.get(url, timeout=5).content
            px = QPixmap()
            px.loadFromData(data)
            scaled = px.scaled(250, 250, Qt.KeepAspectRatio, Qt.SmoothTransformation)
            QMetaObject.invokeMethod(self.preview, "setPixmap", Qt.QueuedConnection, Q_ARG(QPixmap, scaled))
        except:
            QMetaObject.invokeMethod(self.preview, "setText", Qt.QueuedConnection, Q_ARG(str, "Ошибка"))

    def get_height(self):
        return 310
