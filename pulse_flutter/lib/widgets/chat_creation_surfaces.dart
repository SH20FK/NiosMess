import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/search_models.dart';
import 'package:pulse_flutter/widgets/common/user_search_picker_sheet.dart';
import 'package:pulse_flutter/widgets/create_chat_wizard_view.dart';

Future<void> showStartDirectChatDialog(BuildContext context) async {
  final ApiSearchUser? user = await showUserSearchPickerSheet(
    context,
    title: context.l10n.chatCreatePersonalPrompt,
    subtitle: context.l10n.chatCreatePersonalSubtitle,
    hintText: context.l10n.chatCreatePersonalUsernameHint,
    allowCustomUsername: true,
  );
  if (user != null && context.mounted && user.username.isNotEmpty) {
    context.push('/chat/dm/${Uri.encodeComponent(user.username)}');
  }
}

/// Adaptive modal for Group / Channel creation:
/// - Mobile / narrow screens (< 720dp): Material 3 Expressive Bottom Sheet modal.
/// - Desktop / wide screens (>= 720dp): Centered Material 3 Expressive Dialog card.
Future<void> showCreateChatModal(
  BuildContext context, {
  required String chatType,
}) {
  final bool isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    return showCreateChatDialog(context, initialType: chatType);
  }

  return AppBottomSheets.show<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: CreateChatWizardView(
          initialType: chatType,
          isDialog: true,
          lockType: true,
          onClose: () => Navigator.of(ctx).pop(),
          onChatCreated: (int chatId) {
            Navigator.of(ctx).pop();
            context.push('/chat/$chatId');
          },
        ),
      );
    },
  );
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
              lockType: true,
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
            const SizedBox(height: 10),
            actionTile(
              value: 'channel',
              icon: Icons.campaign_rounded,
              title: context.l10n.groupNewChannel,
              subtitle: 'Канал для публикаций, новостей и контента',
              iconContainerColor: scheme.tertiaryContainer,
              iconColor: scheme.onTertiaryContainer,
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
