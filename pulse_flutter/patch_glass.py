import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\widgets\settings_ui.dart", "r", encoding="utf-8") as f:
    content = f.read()

old_material = """          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildSeparatedChildren(scheme, children),
            ),
          ),"""

new_material = """          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Material(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildSeparatedChildren(scheme, children),
                ),
              ),
            ),
          ),"""

content = content.replace(old_material, new_material)

if "import 'dart:ui';" not in content:
    content = "import 'dart:ui';\n" + content

with open(r"E:\Niosmess V2\pulse_flutter\lib\widgets\settings_ui.dart", "w", encoding="utf-8") as f:
    f.write(content)
