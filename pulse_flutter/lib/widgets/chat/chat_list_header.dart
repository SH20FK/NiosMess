import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  /// Vertical breathing room around the scaled page title.
  static const double _titleVerticalPadding = 8;

  /// Toolbar height that fits the title at the current text scale.
  ///
  /// [PreferredSizeWidget.preferredSize] cannot read the widget tree, so the
  /// screen wraps this header in a [PreferredSize] built from this value.
  static double heightFor(BuildContext context) {
    final TextStyle? titleStyle = Theme.of(context).textTheme.headlineSmall;
    final double fontSize = titleStyle?.fontSize ?? 24;
    final double lineHeight = (titleStyle?.height ?? 1.33) * fontSize;
    final double scaledTitle = MediaQuery.textScalerOf(
      context,
    ).scale(lineHeight);
    return math.max(kToolbarHeight, scaledTitle + _titleVerticalPadding * 2);
  }

  static double _heightForTextScale(double textScaleFactor) {
    // headlineSmall is 24/32 in the app typography; 32 is the scaled line box.
    return math.max(
      kToolbarHeight,
      32 * textScaleFactor + _titleVerticalPadding * 2,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    final profile = ref.watch(authProvider.select((s) => s.profile));
    final sessionName = ref.watch(
      authProvider.select((s) => s.session?.displayName),
    );

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: heightFor(context),
      title: Text(
        l10n.tabChats,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onSurface),
      ),
      centerTitle: false,
      actions: <Widget>[
        IconButton(
          tooltip: l10n.chatListSearchMessagesHint,
          onPressed: () => context.push('/chats/search'),
          icon: const Icon(Icons.search_rounded),
        ),
        IconButton(
          key: const ValueKey('inbox-profile-settings'),
          tooltip: l10n.tabSettings,
          onPressed: () => context.go('/main/settings'),
          icon: PulseAvatar(
            avatarUrl: profile?.avatarUrl,
            name: profile?.displayName ?? sessionName ?? '',
            radius: 16,
          ),
        ),
        const SizedBox(width: 4),
      ],
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    _heightForTextScale(
      WidgetsBinding.instance.platformDispatcher.textScaleFactor,
    ),
  );
}
