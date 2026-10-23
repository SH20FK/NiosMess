import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/features/chats/domain/compose_action.dart';

Future<void> openComposeActions(BuildContext context) async {
  final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

  final ComposeActionId? selectedAction = isWide
      ? await AppModal.showDialog<ComposeActionId>(
          context: context,
          maxWidth: 440,
          builder: (dialogContext) => const _ComposeActionContent(),
        )
      : await AppModal.showSheet<ComposeActionId>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) => const _ComposeActionContent(),
        );

  if (selectedAction == null || !context.mounted) return;

  switch (selectedAction) {
    case ComposeActionId.message:
      context.push('/new-message');
    case ComposeActionId.group:
      context.push('/new-group/members');
    case ComposeActionId.channel:
      context.push('/new-channel');
    case ComposeActionId.secret:
      context.push('/new-message?mode=secret');
    case ComposeActionId.joinLink:
      context.push('/join');
  }
}

class _ComposeActionContent extends ConsumerWidget {
  const _ComposeActionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final actions = buildComposeActions(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              context.l10n.inboxComposeTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...actions.map((action) {
            return ListTile(
              enabled: action.available,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: action.id == ComposeActionId.secret
                      ? scheme.secondaryContainer
                      : (action.id == ComposeActionId.channel
                            ? scheme.tertiaryContainer
                            : scheme.primaryContainer),
                ),
                child: Icon(
                  action.icon,
                  size: 20,
                  color: action.id == ComposeActionId.secret
                      ? scheme.onSecondaryContainer
                      : (action.id == ComposeActionId.channel
                            ? scheme.onTertiaryContainer
                            : scheme.onPrimaryContainer),
                ),
              ),
              title: Text(
                action.title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                action.subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                if (ref.read(uiSettingsProvider.select((s) => s.haptics))) {
                  HapticService.tap();
                }
                Navigator.of(context).pop(action.id);
              },
            );
          }),
        ],
      ),
    );
  }
}
