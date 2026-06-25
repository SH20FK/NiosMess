import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\widgets\settings_ui.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';", "import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';\nimport 'package:pulse_flutter/widgets/jelly_switch.dart';")
content = content.replace("trailing: Switch(\n        value: value,\n        onChanged: onChanged,\n      ),", "trailing: JellySwitch(\n        value: value,\n        onChanged: onChanged,\n      ),")

# Also let's make SettingsSection blocks glassmorphic!
# The user wants settings blocks to be glassmorphic with BackdropFilter.
# We will do this inside SettingsSection.
