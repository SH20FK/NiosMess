import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\contacts_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

badges_old = """                                  if (badges.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: <Widget>[
                                          ...badges.map(
                                            (badge) => BadgeChip(
                                              id: badge.id,
                                              name: badge.name,
                                              icon: badge.icon,
                                              color: badge.color,
                                              interactive: false,
                                            ),
                                          ),
                                          if (hiddenBadgeCount > 0)
                                            BadgeOverflowChip(
                                              count: hiddenBadgeCount,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],"""

badges_new = """                                  if (badges.isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: <Widget>[
                                          ...badges.map(
                                            (badge) => BadgeChip(
                                              id: badge.id,
                                              name: badge.name,
                                              icon: badge.icon,
                                              color: badge.color,
                                              interactive: false,
                                              mode: BadgeResolver.isStatusBadge(badge) ? BadgeDisplayMode.statusIcon : BadgeDisplayMode.infoLabel,
                                            ),
                                          ),
                                          if (hiddenBadgeCount > 0)
                                            BadgeOverflowChip(
                                              count: hiddenBadgeCount,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],"""

content = content.replace(badges_old, badges_new)

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\contacts_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
