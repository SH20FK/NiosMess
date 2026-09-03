# Complete E2E Suite Generator
import os

with open('test/auth_e2e_flow_test.dart', 'w', encoding='utf-8') as out:
    with open('part1.dart', 'r', encoding='utf-8') as p1:
        out.write(p1.read())
