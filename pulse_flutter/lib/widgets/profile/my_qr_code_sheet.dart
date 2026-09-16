import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/nios_mark_badge.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Material 3 Expressive bottom sheet displaying the current user's profile QR code
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
  }) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => MyQrCodeSheet(
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthState auth = ref.watch(authProvider);

    final bool isSelf = (username == null || username!.isEmpty)
        ? true
        : (username == auth.session?.username || username == auth.profile?.username);

    final String resolvedUsername = (username != null && username!.isNotEmpty)
        ? username!
        : (auth.session?.username ?? auth.profile?.username ?? '');
    final String resolvedDisplayName = (displayName != null && displayName!.isNotEmpty)
        ? displayName!
        : (isSelf
            ? (auth.session?.displayName ??
                auth.profile?.displayName ??
                (resolvedUsername.isNotEmpty ? resolvedUsername : 'User'))
            : (resolvedUsername.isNotEmpty ? resolvedUsername : 'User'));
    final String? resolvedAvatar = avatarUrl ?? (isSelf ? auth.profile?.avatarUrl : null);

    final String profileUrl = 'https://ni-os.ru/u/$resolvedUsername';
    final String qrData =
        resolvedUsername.isNotEmpty ? profileUrl : 'https://ni-os.ru';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            isSelf ? 'Мой QR-код' : 'QR-код профиля',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Отсканируйте код для быстрого перехода в профиль',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // QR Card Container (tonal container surface, zero boxShadow per M3E)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: <Widget>[
                // QR Code Viewport: pure white background ensures scannability in all themes/lighting
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF000000),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Color(0xFF000000),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // User Info inside QR card
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PulseAvatar(
                      radius: 20,
                      name: resolvedDisplayName,
                      avatarUrl: resolvedAvatar,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            resolvedDisplayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (resolvedUsername.isNotEmpty)
                            Text(
                              '@$resolvedUsername',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    NiosMarkBadge(
                      id: resolvedUsername.isNotEmpty ? resolvedUsername : resolvedDisplayName,
                      name: resolvedDisplayName,
                      size: 38,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: <Widget>[
              // Share button
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.tap();
                    }
                    await SharePlus.instance.share(
                      ShareParams(
                        text: isSelf
                            ? 'Мой профиль в NiosMess: $profileUrl'
                            : 'Профиль $resolvedDisplayName в NiosMess: $profileUrl',
                        subject: 'NiosMess контакт',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(context.l10n.groupProfileShare),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Copy link button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    if (ref.read(uiSettingsProvider).haptics) {
                      HapticService.tap();
                    }
                    await Clipboard.setData(ClipboardData(text: profileUrl));
                    if (!context.mounted) return;
                    AppToast.showSuccess(
                      context,
                      context.l10n.filePreviewLinkCopied,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: Text(context.l10n.botCopied),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
