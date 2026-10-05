import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
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

class _ComposeActionContent extends StatelessWidget {
  const _ComposeActionContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final actions = buildComposeActions(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Начать общение',
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
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: action.id == ComposeActionId.secret
                    ? scheme.errorContainer
                    : (action.id == ComposeActionId.channel
                        ? scheme.tertiaryContainer
                        : scheme.primaryContainer),
                child: Icon(
                  action.icon,
                  size: 20,
                  color: action.id == ComposeActionId.secret
                      ? scheme.onErrorContainer
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
                HapticService.tap();
                Navigator.of(context).pop(action.id);
              },
            );
          }),
        ],
      ),
    );
  }
}
