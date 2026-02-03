import os
import sys
import json
import requests
from PyQt5.QtWidgets import *
from PyQt5.QtCore import *
from PyQt5.QtGui import *
from handlers import SESSION_FILE, SERVER_URL
from messenger import MessengerWindow


class AuthWorker(QThread):
    result_signal = pyqtSignal(dict)
    error_signal = pyqtSignal(str, int)

    def __init__(self, mode, payload):
        super().__init__()
        self.mode = mode
        self.payload = payload

    def run(self):
        try:
            url = f"{SERVER_URL}/{self.mode}"
            r = requests.post(url, json=self.payload, timeout=10)
            if r.status_code == 200:
                self.result_signal.emit(r.json())
            else:
                try:
                    res = r.json()
                except:
                    res = {}
                err_msg = res.get('detail', res.get('error', 'Ошибка сервера'))
                self.error_signal.emit(err_msg, r.status_code)
        except Exception as e:
            self.error_signal.emit(str(e), 0)


class AuthWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("NiosMess - Liquid Glass Auth")
        self.setFixedSize(450, 700)
        self.reg = False
        self.init_ui()
        QTimer.singleShot(100, self.auto_login)

    def init_ui(self):
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setStyleSheet("""
            QWidget {
                font-family: 'Segoe UI', sans-serif;
                color: white;
            }
            #MainFrame {
                background: rgba(40, 40, 45, 180);
                border: 1px solid rgba(255, 255, 255, 30);
                border-radius: 25px;
            }
            QLabel#Title {
                font-size: 32px;
                font-weight: bold;
                color: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #00aaff, stop:1 #ffffff);
                margin-bottom: 10px;
            }
            QLineEdit {
                background: rgba(255, 255, 255, 12);
                border: 1px solid rgba(255, 255, 255, 20);
                border-radius: 12px;
                padding: 14px;
                font-size: 16px;
                color: white;
            }
            QLineEdit:focus {
                background: rgba(255, 255, 255, 20);
                border: 1px solid rgba(0, 170, 255, 150);
            }
        
            .valid { border: 2px solid rgba(46, 204, 113, 180); background: rgba(46, 204, 113, 15); }
            .invalid { border: 2px solid rgba(231, 76, 60, 180); background: rgba(231, 76, 60, 15); }

            QPushButton#AuthBtn {
                background: rgba(0, 170, 255, 40);
                border: 1px solid rgba(0, 170, 255, 80);
                border-radius: 15px;
                font-size: 18px;
                font-weight: bold;
                color: #00aaff;
            }
            QPushButton#AuthBtn:hover {
                background: rgba(0, 170, 255, 60);
                border: 1px solid #00aaff;
                color: white;
            }
            QPushButton#LinkBtn {
                color: rgba(255, 255, 255, 100);
                background: transparent;
                border: none;
                font-size: 14px;
                text-decoration: none;
            }
            QPushButton#LinkBtn:hover {
                color: #00aaff;
            }
            QProgressBar {
                background: rgba(255, 255, 255, 10);
                border-radius: 2px;
                height: 4px;
                text-align: center;
            }
            QProgressBar::chunk {
                background: #00aaff;
                border-radius: 2px;
            }
        """)
        layout = QVBoxLayout(self)
        self.frame = QFrame()
        self.frame.setObjectName("MainFrame")
        layout.addWidget(self.frame)
        v = QVBoxLayout(self.frame)
        v.setContentsMargins(45, 50, 45, 50)
        v.setSpacing(18)
        self.t = QLabel("Вход")
        self.t.setObjectName("Title")
        self.t.setAlignment(Qt.AlignCenter)
        self.e = QLineEdit();
        self.e.setPlaceholderText("Электронная почта")
        self.u = QLineEdit();
        self.u.setPlaceholderText("Имя пользователя");
        self.u.hide()
        self.n = QLineEdit();
        self.n.setPlaceholderText("Ваше имя");
        self.n.hide()
        self.p = QLineEdit();
        self.p.setPlaceholderText("Пароль")
        self.p.setEchoMode(QLineEdit.Password)
        self.p2 = QLineEdit();
        self.p2.setPlaceholderText("Повторите пароль")
        self.p2.setEchoMode(QLineEdit.Password);
        self.p2.hide()
        self.c = QLineEdit();
        self.c.setPlaceholderText("Код из письма");
        self.c.hide()
        self.b = QPushButton("ВОЙТИ")
        self.b.setObjectName("AuthBtn")
        self.b.setFixedHeight(55)
        self.b.setCursor(Qt.PointingHandCursor)
        self.b.clicked.connect(self.start_auth_process)
        self.s = QPushButton("Создать новый аккаунт")
        self.s.setObjectName("LinkBtn")
        self.s.setCursor(Qt.PointingHandCursor)
        self.s.clicked.connect(self.sw)
        self.loading = QProgressBar()
        self.loading.hide()
        for w in [self.t, self.e, self.u, self.n, self.p, self.p2, self.c, self.b, self.loading, self.s]:
            v.addWidget(w)
        v.addStretch()
        self.p.textChanged.connect(self.validate_passwords)
        self.p2.textChanged.connect(self.validate_passwords)

    def validate_passwords(self):
        if not self.reg: return
        match = self.p.text() == self.p2.text() and len(self.p.text()) > 0
        self.p2.setProperty("class", "valid" if match else "invalid")
        self.p2.style().unpolish(self.p2);
        self.p2.style().polish(self.p2)
    def sw(self):
        self.reg = not self.reg
        self.u.setVisible(self.reg)
        self.n.setVisible(self.reg)
        self.p2.setVisible(self.reg)
        self.c.hide()
        self.t.setText("Регистрация" if self.reg else "Вход")
        self.b.setText("ПРОДОЛЖИТЬ" if self.reg else "ВОЙТИ")
        self.s.setText("Уже есть аккаунт? Войти" if self.reg else "Создать новый аккаунт")
    def auto_login(self):
        if os.path.exists(SESSION_FILE):
            try:
                with open(SESSION_FILE, "r") as f:
                    d = json.load(f)
                self.start_auth_process(auto=True, data=d)
            except:
                pass
    def start_auth_process(self, auto=False, data=None):
        self.b.setEnabled(False)
        self.loading.show()
        self.loading.setRange(0, 0)

        if auto:
            mode = "check_session"
            payload = {"token": data.get("token"), "username": data.get("username")}
            self.temp_username = data.get("username")  # Запоминаем для входа
        else:
            mode = 'register' if self.reg else 'login'
            payload = {
                "email": self.e.text().strip(),
                "password": self.p.text().strip(),
                "username": self.u.text().strip(),
                "name": self.n.text().strip(),
                "code": self.c.text().strip() if self.c.isVisible() else None
            }

        self.worker = AuthWorker(mode, payload)
        self.worker.result_signal.connect(self.on_auth_success)
        self.worker.error_signal.connect(self.on_auth_error)
        self.worker.finished.connect(lambda: (self.b.setEnabled(True), self.loading.hide()))
        self.worker.start()
    def on_auth_success(self, res):
        if res.get("status") == "wait_code":
            self.c.show();
            self.c.setFocus()
            self.b.setText("ПОДТВЕРДИТЬ")
            return
        if res.get("token"):
            with open(SESSION_FILE, "w") as f:
                json.dump(res, f)
            self.go(res['username'])
        elif res.get("status") == "ok":
            self.go(res.get("username", getattr(self, "temp_username", "User")))
    def on_auth_error(self, msg, status_code):
        target = None
        if "mail" in msg.lower():
            target = self.e
        elif "user" in msg.lower():
            target = self.u
        elif "pass" in msg.lower():
            target = self.p
        elif "код" in msg.lower():
            target = self.c
        if target:
            target.setProperty("class", "invalid")
            target.style().unpolish(target);
            target.style().polish(target)
        QMessageBox.warning(self, "Ошибка", msg)
    def go(self, u):
        self.m = MessengerWindow(u)
        self.m.show()
        self.close()
if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    w = AuthWindow()
    w.show()
    sys.exit(app.exec_())