import os

def check_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Balance check
    counts = {'(': 0, '{': 0, '[': 0}
    for char in content:
        if char in counts:
            counts[char] += 1
        elif char == ')':
            counts['('] -= 1
        elif char == '}':
            counts['{'] -= 1
        elif char == ']':
            counts['['] -= 1
            
    if counts['('] != 0 or counts['{'] != 0 or counts['['] != 0:
        print(f"Unbalanced braces in {filepath}: {counts}")

for root, _, files in os.walk('/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/pulse_flutter/lib'):
    for file in files:
        if file.endswith('.dart'):
            check_file(os.path.join(root, file))
