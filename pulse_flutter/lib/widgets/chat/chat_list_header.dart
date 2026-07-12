import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({
    this.onJoinTap,
    this.onDirectTap,
    super.key,
  });

  final VoidCallback? onJoinTap;
  final VoidCallback? onDirectTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final optimize = settings.optimizeForWeakDevices;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return AppBar(
      title: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: optimize
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: scheme.surface.withValues(alpha: 0.95),
                child: Text(l10n.tabChats),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: scheme.surface.withValues(alpha: 0.6),
                  child: Text(l10n.tabChats),
                ),
              ),
      ),
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      actions: <Widget>[
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: l10n.groupCreateOrJoin,
          onSelected: (String value) {
            if (value == 'join') onJoinTap?.call();
            if (value == 'direct') onDirectTap?.call();
          },
          itemBuilder: (BuildContext ctx) {
            final TextTheme textTheme = Theme.of(ctx).textTheme;
            final ColorScheme cs = Theme.of(ctx).colorScheme;
            return <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'join',
                child: SizedBox(
                  width: 200,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.link_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.groupJoinByInvite, style: textTheme.labelLarge),
                          Text(l10n.groupJoinByInviteSubtitle, style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: 'direct',
                child: SizedBox(
                  width: 200,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.person_add_alt_1_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(l10n.chatCreatePersonal, style: textTheme.labelLarge),
                          Text(l10n.chatCreatePersonalSubtitle, style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
