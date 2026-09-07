import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Semantic color resolved for an [InlineKeyboardButtonStyle] under Material 3 Expressive.
class InlineButtonColors {
  const InlineButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.ripple,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final Color ripple;

  static InlineButtonColors resolve(InlineKeyboardButtonStyle style, ColorScheme scheme) {
    final bool isDark = scheme.brightness == Brightness.dark;

    switch (style) {
      case InlineKeyboardButtonStyle.primary:
        return InlineButtonColors(
          background: scheme.primaryContainer.withValues(alpha: isDark ? 0.85 : 0.95),
          foreground: scheme.onPrimaryContainer,
          border: scheme.primary.withValues(alpha: 0.35),
          ripple: scheme.primary.withValues(alpha: 0.15),
        );

      case InlineKeyboardButtonStyle.success:
        const Color successBase = Color(0xFF2E8A7A);
        return InlineButtonColors(
          background: isDark
              ? Color.alphaBlend(successBase.withValues(alpha: 0.22), scheme.surfaceContainerHigh)
              : Color.alphaBlend(successBase.withValues(alpha: 0.14), scheme.surfaceContainerHigh),
          foreground: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
          border: successBase.withValues(alpha: isDark ? 0.45 : 0.35),
          ripple: successBase.withValues(alpha: 0.15),
        );

      case InlineKeyboardButtonStyle.warning:
        const Color warningBase = Color(0xFFD97706);
        return InlineButtonColors(
          background: isDark
              ? Color.alphaBlend(warningBase.withValues(alpha: 0.22), scheme.surfaceContainerHigh)
              : Color.alphaBlend(warningBase.withValues(alpha: 0.14), scheme.surfaceContainerHigh),
          foreground: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
          border: warningBase.withValues(alpha: isDark ? 0.45 : 0.35),
          ripple: warningBase.withValues(alpha: 0.15),
        );

      case InlineKeyboardButtonStyle.danger:
        return InlineButtonColors(
          background: scheme.errorContainer.withValues(alpha: isDark ? 0.85 : 0.92),
          foreground: scheme.onErrorContainer,
          border: scheme.error.withValues(alpha: 0.35),
          ripple: scheme.error.withValues(alpha: 0.15),
        );

      case InlineKeyboardButtonStyle.defaultStyle:
        return InlineButtonColors(
          background: scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.70 : 0.85),
          foreground: scheme.onSurface,
          border: scheme.outlineVariant.withValues(alpha: 0.40),
          ripple: scheme.onSurface.withValues(alpha: 0.12),
        );
    }
  }
}

/// Renders Telegram-style inline keyboard rows with Material 3 Expressive 5-style buttons.
class InlineKeyboardView extends StatelessWidget {
  const InlineKeyboardView({
    required this.replyMarkup,
    this.isMine = false,
    this.onCallbackQuery,
    super.key,
  });

  final InlineKeyboardMarkup replyMarkup;
  final bool isMine;
  final ValueChanged<String>? onCallbackQuery;

  @override
  Widget build(BuildContext context) {
    if (replyMarkup.inlineKeyboard.isEmpty) {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final double maxBubbleWidth = MediaQuery.sizeOf(context).width > 600
        ? 520.0
        : MediaQuery.sizeOf(context).width * 0.78;

    return Container(
      constraints: BoxConstraints(
        minWidth: 80.0,
        maxWidth: maxBubbleWidth,
      ),
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: replyMarkup.inlineKeyboard.map((List<InlineKeyboardButton> row) {
          if (row.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: row.map((InlineKeyboardButton btn) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: _InlineButton(
                      button: btn,
                      scheme: scheme,
                      textTheme: textTheme,
                      onCallbackQuery: onCallbackQuery,
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _InlineButton extends StatelessWidget {
  const _InlineButton({
    required this.button,
    required this.scheme,
    required this.textTheme,
    required this.onCallbackQuery,
  });

  final InlineKeyboardButton button;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final ValueChanged<String>? onCallbackQuery;

  Future<void> _handlePress(BuildContext context) async {
    HapticService.tap();

    if (button.isUrl) {
      final String rawUrl = button.url!.trim();
      final Uri? uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        if (context.mounted) AppToast.showError(context, 'Неверная ссылка');
        return;
      }

      if (rawUrl.startsWith('niosmess://')) {
        final String deepPath = rawUrl.substring('niosmess://'.length);
        final String route = deepPath.startsWith('/') ? deepPath : '/$deepPath';
        if (context.mounted) {
          context.push(route);
        }
        return;
      }

      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.showError(context, 'Не удалось открыть ссылку: $rawUrl');
      }
    } else if (button.isCallback) {
      onCallbackQuery?.call(button.callbackData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InlineButtonColors colors = InlineButtonColors.resolve(button.buttonStyle, scheme);

    return Tooltip(
      message: button.text,
      waitDuration: const Duration(milliseconds: 700),
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handlePress(context),
          splashColor: colors.ripple,
          highlightColor: colors.ripple.withValues(alpha: 0.5),
          child: Container(
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    button.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                if (button.isUrl) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 13,
                    color: colors.foreground.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
