import re

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\public_profile_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace Avatar
avatar_old = """                            Hero(
                              tag: 'user-avatar-${profile.username}',
                              child: PulseAvatar(
                                name: profile.displayName,
                                avatarUrl: profile.avatarUrl,
                                radius: 44,
                                fallbackColor: scheme.primaryContainer,
                                textColor: scheme.onPrimaryContainer,
                              ),
                            ),"""

avatar_new = """                            Hero(
                              tag: 'user-avatar-${profile.username}',
                              child: Stack(
                                children: [
                                  PulseAvatar(
                                    name: profile.displayName,
                                    avatarUrl: profile.avatarUrl,
                                    radius: 44,
                                    fallbackColor: scheme.primaryContainer,
                                    textColor: scheme.onPrimaryContainer,
                                  ),
                                  if (profile.badges.isNotEmpty)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: BadgeChip(
                                        id: profile.badges.first.id,
                                        name: profile.badges.first.name,
                                        icon: profile.badges.first.icon,
                                        color: profile.badges.first.color,
                                        mode: BadgeDisplayMode.avatarBadge,
                                      ),
                                    ),
                                ],
                              ),
                            ),"""

content = content.replace(avatar_old, avatar_new)

# Replace Name
name_old = """                            Text(
                              profile.displayName,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),"""

name_new = """                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    profile.displayName,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.badges.where((b) => BadgeResolver.isStatusBadge(b)).isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  ...profile.badges.where((b) => BadgeResolver.isStatusBadge(b)).map((b) => Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: BadgeChip(
                                      id: b.id, name: b.name, icon: b.icon, color: b.color,
                                      mode: BadgeDisplayMode.statusIcon,
                                    ),
                                  )),
                                ],
                              ],
                            ),"""

content = content.replace(name_old, name_new)

# Replace Old Badges
badges_old = """                            if (profile.badges.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.center,
                                children: profile.badges
                                    .map(
                                      (badge) => BadgeChip(
                                        id: badge.id,
                                        name: badge.name,
                                        icon: badge.icon,
                                        color: badge.color,
                                        showName: true,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],"""

badges_new = """                            if (profile.badges.where((b) => !BadgeResolver.isStatusBadge(b)).isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                alignment: WrapAlignment.center,
                                children: profile.badges.where((b) => !BadgeResolver.isStatusBadge(b))
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

content = content.replace(badges_old, badges_new)

with open(r"E:\Niosmess V2\pulse_flutter\lib\screens\public_profile_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
