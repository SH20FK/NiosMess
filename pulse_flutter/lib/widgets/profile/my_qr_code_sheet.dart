import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/profile/profile_sheet_layout.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// A readable contact code; its light surface preserves scanner contrast in
/// either app theme. Profile decoration never becomes a chat wallpaper action.
class MyQrCodeSheet extends ConsumerWidget {
  const MyQrCodeSheet({
    this.username,
    this.displayName,
    this.avatarUrl,
    super.key,
  });
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  static Future<void> show(
    BuildContext context, {
    String? username,
    String? displayName,
    String? avatarUrl,
  }) => ProfileSheetLayout.show<void>(
    context,
    isDismissible: true,
    builder: (_) => MyQrCodeSheet(
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final ownUsername = auth.profile?.username ?? auth.session?.username ?? '';
    final resolvedUsername = username?.isNotEmpty == true
        ? username!
        : ownUsername;
    final isSelf = resolvedUsername == ownUsername;
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : isSelf
        ? auth.profile?.displayName ??
              auth.session?.displayName ??
              resolvedUsername
        : resolvedUsername;
    final avatar = avatarUrl ?? (isSelf ? auth.profile?.avatarUrl : null);
    final url = resolvedUsername.isEmpty
        ? 'https://ni-os.ru'
        : Uri.https('ni-os.ru', '/u/$resolvedUsername').toString();
    final qrScheme = ColorScheme.fromSeed(
      seedColor: scheme.primary,
      brightness: Brightness.light,
    );

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        AppToast.showSuccess(context, context.l10n.settingsQrCopied);
      }
    }

    return ProfileSheetLayout(
      title: isSelf
          ? context.l10n.settingsQrTitle
          : context.l10n.settingsQrProfileTitle,
      onClose: () => Navigator.of(context).pop(),
      actionLabel: context.l10n.settingsQrCopy,
      onSubmit: copy,
      secondaryAction: TextButton.icon(
        onPressed: () => SharePlus.instance.share(ShareParams(text: url)),
        icon: const Icon(Icons.share_outlined),
        label: Text(
          context.l10n.groupProfileShare,
          textAlign: TextAlign.center,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PulseAvatar(
                name: name,
                avatarUrl: avatar,
                radius: 24,
                fallbackColor: scheme.primaryContainer,
                textColor: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (resolvedUsername.isNotEmpty)
                      Text(
                        '@$resolvedUsername',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: qrScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Semantics(
                    image: true,
                    label: url,
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: QrImageView(
                          data: url,
                          backgroundColor: qrScheme.surface,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: qrScheme.onSurface,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: qrScheme.onSurface,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.settingsQrHint,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
