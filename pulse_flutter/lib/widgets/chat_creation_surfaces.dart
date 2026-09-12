import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/create_chat_wizard_view.dart';

Future<void> showStartDirectChatDialog(BuildContext context) {
  final TextEditingController usernameController = TextEditingController();
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
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
  ).whenComplete(() => usernameController.dispose());
}

/// Compact Material 3 Expressive dialog for desktop/web chat creation
Future<void> showCreateChatDialog(
  BuildContext context, {
  String initialType = 'group',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      final ColorScheme scheme = Theme.of(ctx).colorScheme;
      return Dialog(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.20),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: CreateChatWizardView(
              initialType: initialType,
              isDialog: true,
              onClose: () => Navigator.of(ctx).pop(),
              onChatCreated: (int chatId) {
                Navigator.of(ctx).pop();
                context.push('/chat/$chatId');
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> showCreateChatMenu(BuildContext context) {
  final bool isWide = MediaQuery.sizeOf(context).width >= 720;

  Widget buildContent(BuildContext ctx) {
    final ColorScheme scheme = Theme.of(ctx).colorScheme;
    final TextTheme textTheme = Theme.of(ctx).textTheme;

    Widget actionTile({
      required String value,
      required IconData icon,
      required String title,
      required String subtitle,
      required Color iconContainerColor,
      required Color iconColor,
    }) {
      return _PressableScale(
        onTap: () {
          HapticService.tap();
          Navigator.of(ctx).pop(value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 22),
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
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.50),
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!isWide) ...<Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.maps_ugc_rounded,
                    color: scheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.l10n.groupCreateOrJoin,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Выберите формат для общения или трансляций',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide) ...<Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.commonCancel,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerLow,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            actionTile(
              value: 'group',
              icon: Icons.groups_rounded,
              title: context.l10n.groupNewGroup,
              subtitle: 'Чат для друзей, коллег или сообщества',
              iconContainerColor: scheme.primaryContainer,
              iconColor: scheme.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            actionTile(
              value: 'channel',
              icon: Icons.campaign_rounded,
              title: context.l10n.groupNewChannel,
              subtitle: 'Канал для публикаций, новостей и контента',
              iconContainerColor: scheme.tertiaryContainer,
              iconColor: scheme.onTertiaryContainer,
            ),
            const SizedBox(height: 8),
            actionTile(
              value: 'direct',
              icon: Icons.person_add_alt_1_rounded,
              title: context.l10n.chatCreatePersonal,
              subtitle: 'Начать прямой чат по @username',
              iconContainerColor: scheme.secondaryContainer,
              iconColor: scheme.onSecondaryContainer,
            ),
            const SizedBox(height: 8),
            actionTile(
              value: 'join',
              icon: Icons.link_rounded,
              title: 'Войти по ссылке',
              subtitle: 'Вступить по ссылке-приглашению /u/+TOKEN',
              iconContainerColor: scheme.surfaceContainerHighest,
              iconColor: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  if (isWide) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return Dialog(
          backgroundColor: scheme.surfaceContainerHigh,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: buildContent(ctx),
          ),
        );
      },
    );
  }

  return AppBottomSheets.show<String>(
    context: context,
    builder: buildContent,
  );
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: M3SpringCurves.spatial,
        child: widget.child,
      ),
    );
  }
}
