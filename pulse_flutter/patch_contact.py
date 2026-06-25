import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\contact_detail_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

avatar_old = """                        Hero(
                          tag: 'user-avatar-${_profile!.username}',
                          child: PulseAvatar(
                            name: _profile!.displayName,
                            avatarUrl: _profile!.avatarUrl,
                            radius: 58,
                            fallbackColor: scheme.primaryContainer,
                            textColor: scheme.onPrimaryContainer,
                          ),
                        ),"""

avatar_new = """                        Hero(
                          tag: 'user-avatar-${_profile!.username}',
                          child: Stack(
                            children: [
                              PulseAvatar(
                                name: _profile!.displayName,
                                avatarUrl: _profile!.avatarUrl,
                                radius: 58,
                                fallbackColor: scheme.primaryContainer,
                                textColor: scheme.onPrimaryContainer,
                              ),
                              if (_profile!.badges.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: BadgeChip(
                                    id: _profile!.badges.first.id,
                                    name: _profile!.badges.first.name,
                                    icon: _profile!.badges.first.icon,
                                    color: _profile!.badges.first.color,
                                    mode: BadgeDisplayMode.avatarBadge,
                                  ),
                                ),
                            ],
                          ),
                        ),"""

name_old = """                        Text(
                          _profile!.displayName,
                          style: textTheme.headlineSmall,
                        ),"""

name_new = """                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _profile!.displayName,
                                style: textTheme.headlineSmall,
                              ),
                            ),
                            if (_profile!.badges.where((b) => BadgeResolver.isStatusBadge(b)).isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ..._profile!.badges.where((b) => BadgeResolver.isStatusBadge(b)).map((b) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: BadgeChip(
                                  id: b.id, name: b.name, icon: b.icon, color: b.color,
                                  mode: BadgeDisplayMode.statusIcon,
                                ),
                              )),
                            ],
                          ],
                        ),"""

badges_old = """                        if (_profile!.badges.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: _profile!.badges
                                .map(
                                  (badge) => BadgeChip(
                                    id: badge.id,
                                    name: badge.name,
                                    icon: badge.icon,
                                    color: badge.color,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],"""

badges_new = """                        if (_profile!.badges.where((b) => !BadgeResolver.isStatusBadge(b)).isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: _profile!.badges.where((b) => !BadgeResolver.isStatusBadge(b))
                                .map(
                                  (badge) => BadgeChip(
                                    id: badge.id,
                                    name: badge.name,
                                    icon: badge.icon,
                                    color: badge.color,
                                    showName: true,
                                    mode: BadgeDisplayMode.infoLabel,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],"""

content = content.replace(avatar_old, avatar_new)
content = content.replace(name_old, name_new)
content = content.replace(badges_old, badges_new)

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\contact_detail_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
