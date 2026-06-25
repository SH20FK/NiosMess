import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\profile_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("uploadAvatar(file.name, file.bytes!)", "uploadAvatar(file.bytes!, file.name)")

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\profile_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
