import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pulse_flutter/core/constants/build_info.dart';
import 'package:pulse_flutter/core/constants/team.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

class AboutVersionChip extends StatelessWidget {
  const AboutVersionChip({
    required this.packageInfoFuture,
    required this.onCopy,
    super.key,
  });
  final Future<PackageInfo> packageInfoFuture;
  final ValueChanged<String> onCopy;
  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
    future: packageInfoFuture,
    builder: (context, snapshot) {
      final version = snapshot.data == null
          ? BuildInfo.fullVersion
          : 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}';
      return TextButton.icon(
        onPressed: () => onCopy(version),
        icon: const Icon(Icons.copy_outlined, size: 18),
        label: Text(version, textAlign: TextAlign.center),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      );
    },
  );
}

class AboutTeamMemberTile extends StatelessWidget {
  const AboutTeamMemberTile({
    required this.member,
    required this.onOpen,
    super.key,
  });
  final TeamMember member;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => SettingsListItem(
    icon: member.fallbackIcon,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        member.assetPath,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(member.fallbackIcon),
      ),
    ),
    title: member.name,
    subtitle: '${member.roleResolver(context)}\n@${member.handle}',
    trailing: Icon(
      Icons.open_in_new_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    onTap: onOpen,
    onLongPress: () async {
      await Clipboard.setData(ClipboardData(text: '@${member.handle}'));
      if (context.mounted) {
        AppToast.showSuccess(context, context.l10n.noticeCopied);
      }
    },
  );
}
