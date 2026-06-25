import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\profile_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("FilePicker.platform.pickFiles", "FilePicker.platform.pickFiles")

# Wait, why didn't `FilePicker.platform` work? 
# Maybe I need to import file_picker.dart!
