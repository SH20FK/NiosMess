import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_glass.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  const ChatListHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return AppBar(
      title: AdaptiveGlass(
        borderRadius: BorderRadius.circular(20),
        tierASigma: 10.0,
        tierBSigma: 6.0,
        tintColor: scheme.surface.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(l10n.tabChats),
      ),
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
