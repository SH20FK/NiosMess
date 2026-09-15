import 'package:flutter/widgets.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

/// Representation of a core NiosMess contributor.
class TeamMember {
  const TeamMember({
    required this.name,
    required this.handle,
    required this.roleResolver,
    required this.assetPath,
    this.fallbackIcon = const IconData(0xe853, fontFamily: 'MaterialIcons'),
    this.shapeIndex = 0,
    this.profilePath,
  });

  /// Contributor display name.
  final String name;

  /// Telegram handle without leading '@'.
  final String handle;

  /// Localization resolver for contributor's role.
  final String Function(BuildContext context) roleResolver;

  /// Asset path to contributor's illustration.
  final String assetPath;

  /// Fallback icon if asset fails to load.
  final IconData fallbackIcon;

  /// Index of brand mark shape profile to draw around avatar.
  final int shapeIndex;

  /// Optional in-app profile route.
  final String? profilePath;
}

/// Core team members list for About screen.
final List<TeamMember> kTeamMembers = <TeamMember>[
  TeamMember(
    name: 'sanlsan',
    handle: 'hello_sanlsan',
    roleResolver: (BuildContext context) => context.l10n.aboutFounderRole,
    assetPath: 'assets/developers/Sanlsan_clean.png',
    fallbackIcon: const IconData(0xf68b, fontFamily: 'MaterialIcons'), // dns_rounded
    shapeIndex: 0, // cookie
  ),
  TeamMember(
    name: 'SH20FK',
    handle: 'Door0S',
    roleResolver: (BuildContext context) => context.l10n.aboutLeadDevRole,
    assetPath: 'assets/developers/SH20FK_clean.png',
    fallbackIcon: const IconData(0xf00b2, fontFamily: 'MaterialIcons'), // phone_iphone_rounded
    shapeIndex: 1, // gem
  ),
];
