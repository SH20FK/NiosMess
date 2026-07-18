import os
import re

def remove_arg(content, arg_name):
    # This removes `arg_name: ... ,` safely up to the next comma, assuming no nested commas for these specific args.
    # For `shape: RoundedRectangleBorder(...)`, it's harder. Let's just find `arg_name:` and remove up to `,` or `\n`.
    pass

# Actually, I'll just use my previous ast parser technique to find the bounds of the function call `AppBottomSheets.show` and clean its arguments.
def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    # For shape with nested parens, we can use a small parser
    # But since there are only a few files, let's just find them and patch them directly.
    pass
