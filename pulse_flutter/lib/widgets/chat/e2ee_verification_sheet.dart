import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/common/touch_container.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class E2eeVerificationSheet extends ConsumerStatefulWidget {
  const E2eeVerificationSheet({
    required this.chatId,
    this.onInitiateHandshake,
    super.key,
  });

  final int chatId;
  final VoidCallback? onInitiateHandshake;

  @override
  ConsumerState<E2eeVerificationSheet> createState() =>
      _E2eeVerificationSheetState();
}

class _E2eeVerificationSheetState extends ConsumerState<E2eeVerificationSheet> {
  late Future<E2eeSessionInfo> _sessionInfo;

  @override
  void initState() {
    super.initState();
    _refreshSession();
  }

  void _refreshSession() {
    _sessionInfo = ref.read(e2eeServiceProvider).getSessionInfo(widget.chatId);
  }

  Color _semanticColorFor(String name, ColorScheme scheme) {
    switch (name.toLowerCase()) {
      case 'red':
        return scheme.error;
      case 'green':
        return scheme.tertiary;
      case 'yellow':
        return scheme.primary;
      case 'blue':
        return scheme.secondary;
      case 'magenta':
        return scheme.secondaryContainer;
      case 'cyan':
        return scheme.primaryContainer;
      case 'white':
        return scheme.onSurface;
      default:
        return scheme.outline;
    }
  }

  Future<void> _verifyPeer() async {
    HapticService.confirm();
    try {
      final e2ee = ref.read(e2eeServiceProvider);
      await e2ee.verifyPeer(widget.chatId);
      if (!mounted) return;
      AppToast.showSuccess(context, context.l10n.e2eePeerVerified);
      setState(() => _refreshSession());
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, '$e');
    }
  }

  void _copyWords(List<({String color, String word})> words) {
    HapticService.confirm();
    final text = words
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value.word.toUpperCase()}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    AppToast.showSuccess(context, '12 слов скопированы в буфер');
  }

  void _showQrCodeSheet(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    String qrData,
  ) {
    HapticService.tap();
    AppBottomSheets.show<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'QR-код верификации',
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Отсканируйте код на устройстве собеседника для мгновенной сверки ключей.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: scheme.onSurface,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: FutureBuilder<E2eeSessionInfo>(
          future: _sessionInfo,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 140,
                child: Center(child: AppLoadingIndicator(size: 32)),
              );
            }

            final info = snapshot.data!;
            final isSecured = info.status == E2eeSessionStatus.secured;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: info.isVerified
                          ? scheme.tertiary
                          : (isSecured ? scheme.primary : scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.e2eeEncryptionTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Double Ratchet v2',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isSecured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: info.isVerified
                              ? scheme.tertiary.withValues(alpha: 0.15)
                              : scheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          info.isVerified
                              ? l10n.e2eeVerified
                              : l10n.e2eeUnverified,
                          style: textTheme.labelSmall?.copyWith(
                            color: info.isVerified
                                ? scheme.tertiary
                                : scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Animated Switcher for the 4 Session States ───────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: M3SpringCurves.spatial,
                  switchOutCurve: Curves.easeOut,
                  child: _buildStateContent(info, scheme, textTheme, l10n),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStateContent(
    E2eeSessionInfo info,
    ColorScheme scheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    switch (info.status) {
      case E2eeSessionStatus.none:
        return _buildNoneState(scheme, textTheme);
      case E2eeSessionStatus.connecting:
        return _buildConnectingState(scheme, textTheme);
      case E2eeSessionStatus.compromised:
        return _buildCompromisedState(scheme, textTheme, l10n);
      case E2eeSessionStatus.secured:
        return _buildSecuredState(info, scheme, textTheme, l10n);
    }
  }

  Widget _buildNoneState(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      key: const ValueKey('e2ee_none'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Сеанс сквозного шифрования не установлен',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Нажмите «Инициализировать E2EE», чтобы выполнить безопасное рукопожатие с собеседником.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onInitiateHandshake,
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: const Text('Инициализировать E2EE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingState(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      key: const ValueKey('e2ee_connecting'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const AppLoadingIndicator(size: 36),
          const SizedBox(height: 16),
          Text(
            'Установка зашифрованного соединения...',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Ожидание ответа рукопожатия от собеседника.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompromisedState(
    ColorScheme scheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    return Container(
      key: const ValueKey('e2ee_compromised'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Внимание: угроза безопасности!',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.e2eeMitmWarning,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuredState(
    E2eeSessionInfo info,
    ColorScheme scheme,
    TextTheme textTheme,
    dynamic l10n,
  ) {
    final words = info.visualWords ?? const [];
    final qrData = 'niosmess://e2ee/verify?chat=${widget.chatId}&fp=${info.peerFingerprint ?? ""}';

    return Column(
      key: const ValueKey('e2ee_secured'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (words.isNotEmpty) ...[
          Text(
            l10n.e2eeVisualWordsDesc,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // ── 3×4 Structured Safety Words Grid ─────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: <Widget>[
                for (int row = 0; row < (words.length / 3).ceil(); row++) ...<Widget>[
                  if (row > 0) const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      for (int col = 0; col < 3; col++) ...<Widget>[
                        if (col > 0) const SizedBox(width: 8),
                        Expanded(
                          child: (row * 3 + col < words.length)
                              ? Builder(
                                  builder: (context) {
                                    final int i = row * 3 + col;
                                    final item = words[i];
                                    final Color accent =
                                        _semanticColorFor(item.color, scheme);
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '#${i + 1}',
                                            style:
                                                textTheme.labelSmall?.copyWith(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: accent
                                                  .withValues(alpha: 0.75),
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.word.toUpperCase(),
                                            style:
                                                textTheme.labelLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: accent,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick actions for words: Copy & QR Code
          Row(
            children: [
              TouchContainer(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainerHigh,
                onTap: () => _copyWords(words),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Скопировать слова',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TouchContainer(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainerHigh,
                onTap: () => _showQrCodeSheet(context, scheme, textTheme, qrData),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'QR-код',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (info.peerFingerprint != null) ...[
          _fingerprintRow(
            scheme,
            textTheme,
            label: l10n.e2eeYourFingerprint,
            fingerprint: info.ourFingerprint ?? '',
          ),
          const SizedBox(height: 8),
          _fingerprintRow(
            scheme,
            textTheme,
            label: l10n.e2eePeerFingerprint,
            fingerprint: info.peerFingerprint!,
          ),
          const SizedBox(height: 20),
        ],

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: info.isVerified ? null : _verifyPeer,
            icon: Icon(
              info.isVerified ? Icons.verified_rounded : Icons.check_circle_outline_rounded,
              size: 18,
            ),
            label: Text(
              info.isVerified ? 'Ключи верифицированы' : l10n.e2eeVerifyAction,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fingerprintRow(
    ColorScheme scheme,
    TextTheme textTheme, {
    required String label,
    required String fingerprint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            fingerprint,
            style: textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
              letterSpacing: 1.5,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
