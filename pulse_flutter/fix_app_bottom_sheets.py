import os
import re

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove `showDragHandle: ...,`
    content = re.sub(r'\bshowDragHandle\s*:\s*(true|false)\s*,', '', content)
    
    # 2. Remove `barrierColor: ...,`
    content = re.sub(r'\bbarrierColor\s*:\s*[^,]+,', '', content)
    
    # 3. Remove `useSafeArea: ...,`
    content = re.sub(r'\buseSafeArea\s*:\s*(true|false)\s*,', '', content)
    
    # 4. Remove dangling `),` that appear on their own line right before `builder:`
    content = re.sub(r'\),\s*builder:', 'builder:', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

for root, _, files in os.walk('/media/sh20fk/sdb2-usb-TOSHIBA_HDWD110_/Niosmess V2/pulse_flutter/lib'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
