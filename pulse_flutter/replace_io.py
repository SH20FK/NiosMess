import os

directory = r'E:\Niosmess V2\pulse_flutter\lib'
count = 0
for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            if "import 'dart:io';" in content:
                content = content.replace("import 'dart:io';", "import 'package:universal_io/io.dart';")
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                count += 1
print(f'Replaced in {count} files.')
