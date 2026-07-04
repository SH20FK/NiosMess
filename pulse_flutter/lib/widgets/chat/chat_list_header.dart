import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({
    required this.onCreatePressed,
    super.key,
  });

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(uiSettingsProvider);
    final optimize = settings.optimizeForWeakDevices;
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      title: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: optimize
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: scheme.surface.withValues(alpha: 0.95),
                child: Text(context.l10n.tabChats),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: scheme.surface.withValues(alpha: 0.6),
                  child: Text(context.l10n.tabChats),
                ),
              ),
      ),
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      actions: <Widget>[
        IconButton(
          onPressed: onCreatePressed,
          tooltip: context.l10n.groupCreateOrJoin,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
