import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\chat_members_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace(
    "color: b.color,",
    "color: b.color, mode: BadgeResolver.isStatusBadge(b) ? BadgeDisplayMode.statusIcon : BadgeDisplayMode.infoLabel,"
)
content = content.replace(
    "color: badge.color,",
    "color: badge.color, mode: BadgeResolver.isStatusBadge(badge) ? BadgeDisplayMode.statusIcon : BadgeDisplayMode.infoLabel,"
)

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\chat_members_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
