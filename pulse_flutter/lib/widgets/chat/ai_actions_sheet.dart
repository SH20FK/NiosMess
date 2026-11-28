import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse_flutter/core/ai/ai_action.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';

/// Opens the AI assistant sheet. Resolves with the chosen action and, for
/// translations, the target language, or `null` when dismissed.
Future<(AiAction, String? targetLanguage)?> showAiActionsSheet(
  BuildContext context,
) => AppModal.showSheet<(AiAction, String? targetLanguage)>(
  context: context,
  builder: (BuildContext ctx) => const AiActionsSheet(),
);

class AiActionsSheet extends StatelessWidget {
  const AiActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.chatAiAssistant,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Consumer(
                  builder: (BuildContext context, WidgetRef ref, _) {
                    final usage = ref.watch(
                      authProvider.select((a) => a.profile?.aiUsage),
                    );
                    if (usage == null || !usage.isAvailable) {
                      return const SizedBox.shrink();
                    }
                    final double remainingPercent = usage.remainingPercent;
                    final String pctStr = remainingPercent.toStringAsFixed(
                      remainingPercent.truncateToDouble() == remainingPercent
                          ? 0
                          : 1,
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pctStr% символов',
                            style: tt.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 2-column action cards
            Row(
              children: <Widget>[
                Expanded(
                  child: _AiActionCard(
                    icon: Icons.spellcheck_rounded,
                    label: context.l10n.chatAiFixErrors,
                    scheme: scheme,
                    onTap: () {
                      Navigator.of(context).pop((AiAction.correct, null));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AiActionCard(
                    icon: Icons.business_center_rounded,
                    label: context.l10n.chatAiFormal,
                    scheme: scheme,
                    onTap: () {
                      Navigator.of(context).pop((AiAction.rewriteFormal, null));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.chatAiTranslate,
              style: tt.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ActionChip(
                  label: const Text('🇬🇧 English'),
                  onPressed: () {
                    Navigator.of(context).pop((AiAction.translate, 'en'));
                  },
                ),
                ActionChip(
                  label: const Text('🇪🇸 Español'),
                  onPressed: () {
                    Navigator.of(context).pop((AiAction.translate, 'es'));
                  },
                ),
                ActionChip(
                  label: const Text('🇨🇳 中文'),
                  onPressed: () {
                    Navigator.of(context).pop((AiAction.translate, 'zh'));
                  },
                ),
                ActionChip(
                  label: const Text('🇷🇺 Русский'),
                  onPressed: () {
                    Navigator.of(context).pop((AiAction.translate, 'ru'));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for AI bottom sheet action cards
class _AiActionCard extends StatelessWidget {
  const _AiActionCard({
    required this.icon,
    required this.label,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: <Widget>[
              Icon(icon, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
