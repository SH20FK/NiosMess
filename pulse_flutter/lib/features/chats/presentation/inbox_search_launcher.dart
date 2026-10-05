import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class InboxSearchLauncher extends ConsumerWidget {
  const InboxSearchLauncher({
    this.hintText,
    this.onTap,
    super.key,
  });

  final String? hintText;
  final VoidCallback? onTap;

  void _openSearch(BuildContext context) {
    HapticService.tap();
    if (onTap != null) {
      onTap!();
    } else {
      context.push('/chats/search');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final avatarUrl = ref.watch(authProvider.select((a) => a.profile?.avatarUrl));
    final displayName = ref.watch(
      authProvider.select(
        (a) => a.profile?.displayName ?? a.session?.displayName ?? 'Me',
      ),
    );

    final bool isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _openSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _openSearch(context),
      },
      child: Focus(
        autofocus: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openSearch(context),
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: Ink(
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(AppRadii.full),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hintText ?? 'Поиск по чатам и сообщениям...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isDesktop || kIsWeb)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadii.xs),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isDesktop &&
                                  defaultTargetPlatform == TargetPlatform.macOS
                              ? '⌘ K'
                              : 'Ctrl K',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      PulseAvatar(
                        avatarUrl: avatarUrl,
                        name: displayName,
                        radius: 14,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
