import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';

Future<void> showStartDirectChatDialog(BuildContext context) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final TextEditingController usernameController = TextEditingController();
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          String? errorText;

          void submit() {
            String username = usernameController.text.trim();
            if (username.startsWith('@')) {
              username = username.substring(1);
            }
            if (username.isEmpty) {
              setState(() {
                errorText = context.l10n.chatCreatePersonalErrorEmpty;
              });
              return;
            }
            Navigator.of(ctx).pop();
            context.push('/chat/dm/${Uri.encodeComponent(username)}');
          }

          return AppDialog(
            title: context.l10n.chatCreatePersonalPrompt,
            subtitle: context.l10n.chatCreatePersonalSubtitle,
            icon: Icons.person_add_alt_1_rounded,
            actions: <AppDialogAction>[
              AppDialogAction(
                label: context.l10n.commonCancel,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              AppDialogAction(
                label: context.l10n.chatCreatePersonalStart,
                icon: Icons.arrow_forward_rounded,
                isPrimary: true,
                onPressed: submit,
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppTextFieldDialogContent(
                  controller: usernameController,
                  label: context.l10n.chatCreatePersonalUsernameLabel,
                  hint: context.l10n.chatCreatePersonalUsernameHint,
                  prefixIcon: Icons.alternate_email_rounded,
                ),
                if (errorText != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Future<String?> showCreateChatMenu(BuildContext context) {
  return AppBottomSheets.show<String>(
    context: context,
    
    builder: (BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      final TextTheme textTheme = Theme.of(ctx).textTheme;

      Widget actionTile({
        required String value,
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
        return InkWell(
          onTap: () => Navigator.of(ctx).pop(value),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Material(
              color: scheme.surfaceContainerHigh,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            context.l10n.groupCreateOrJoin,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actionTile(
                    value: 'group',
                    icon: Icons.groups_rounded,
                    title: context.l10n.groupNewGroup,
                    subtitle: context.l10n.groupCreateSharedSubtitle,
                  ),
                  Divider(height: 1, indent: 76, color: scheme.outlineVariant.withValues(alpha: 0.18)),
                  actionTile(
                    value: 'channel',
                    icon: Icons.campaign_rounded,
                    title: context.l10n.groupNewChannel,
                    subtitle: context.l10n.groupCreateBroadcastSubtitle,
                  ),
                  Divider(height: 1, indent: 76, color: scheme.outlineVariant.withValues(alpha: 0.18)),
                  actionTile(
                    value: 'join',
                    icon: Icons.link_rounded,
                    title: context.l10n.groupJoinByInvite,
                    subtitle: context.l10n.groupJoinByInviteSubtitle,
                  ),
                  Divider(height: 1, indent: 76, color: scheme.outlineVariant.withValues(alpha: 0.18)),
                  actionTile(
                    value: 'direct',
                    icon: Icons.person_add_alt_1_rounded,
                    title: context.l10n.chatCreatePersonal,
                    subtitle: context.l10n.chatCreatePersonalSubtitle,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
