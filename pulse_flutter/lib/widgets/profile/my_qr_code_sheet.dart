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
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

/// Material 3 Expressive bottom sheet displaying the current user's profile QR code
class MyQrCodeSheet extends ConsumerWidget {
  const MyQrCodeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => const MyQrCodeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthState auth = ref.watch(authProvider);

    final String username = auth.session?.username ?? auth.profile?.username ?? '';
    final String displayName = auth.session?.displayName ??
        auth.profile?.displayName ??
        (username.isNotEmpty ? username : 'User');
    final String? avatarUrl = auth.profile?.avatarUrl;

    final String profileUrl = 'https://ni-os.ru/u/@$username';
    final String qrData = username.isNotEmpty ? profileUrl : 'https://ni-os.ru';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            'Мой QR-код',
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

          // QR Card Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                // QR Code
                SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: scheme.onSurface,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: scheme.onSurface,
                    ),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                const SizedBox(height: 16),

                // User Info inside QR card
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PulseAvatar(
                      radius: 20,
                      name: displayName,
                      avatarUrl: avatarUrl,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          if (username.isNotEmpty)
                            Text(
                              '@$username',
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
                        text: 'Мой профиль в NiosMess: $profileUrl',
                        subject: 'NiosMess контакт',
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Поделиться'),
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
                    AppToast.showSuccess(context, 'Ссылка скопирована');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('Копировать'),
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
