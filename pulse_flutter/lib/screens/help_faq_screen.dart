import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// Dedicated Help & FAQ Screen with real-time query filtering and support actions.
class HelpFaqScreen extends ConsumerStatefulWidget {
  const HelpFaqScreen({
    this.isEmbedded = false,
    super.key,
  });

  final bool isEmbedded;

  @override
  ConsumerState<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends ConsumerState<HelpFaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final String text = _searchController.text.trim().toLowerCase();
      if (_searchQuery != text) {
        setState(() {
          _searchQuery = text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<(String, String)> allFaqs = <(String, String)>[
      (context.l10n.aboutFaqQ1, context.l10n.aboutFaqA1),
      (context.l10n.aboutFaqQ2, context.l10n.aboutFaqA2),
      (context.l10n.aboutFaqQ3, context.l10n.aboutFaqA3),
      (context.l10n.aboutFaqQ4, context.l10n.aboutFaqA4),
      (context.l10n.aboutFaqQ5, context.l10n.aboutFaqA5),
      (context.l10n.aboutFaqQ6, context.l10n.aboutFaqA6),
      (context.l10n.aboutFaqQ7, context.l10n.aboutFaqA7),
      (context.l10n.aboutFaqQ8, context.l10n.aboutFaqA8),
      (context.l10n.aboutFaqQ9, context.l10n.aboutFaqA9),
      (context.l10n.aboutFaqQ10, context.l10n.aboutFaqA10),
    ];

    final List<(String, String)> filteredFaqs = _searchQuery.isEmpty
        ? allFaqs
        : allFaqs.where(((String, String) item) {
            final String q = item.$1.toLowerCase();
            final String a = item.$2.toLowerCase();
            return q.contains(_searchQuery) || a.contains(_searchQuery);
          }).toList();

    return SettingsShell(
      title: context.l10n.aboutFaqAction,
      isEmbedded: widget.isEmbedded,
      children: <Widget>[
        // 1. Search Bar
        _buildSearchBar(context, scheme, textTheme),
        const SizedBox(height: 16),

        // 2. FAQ List or Empty State
        if (filteredFaqs.isEmpty)
          _buildEmptyState(context, scheme, textTheme)
        else
          _buildFaqList(context, scheme, textTheme, filteredFaqs),
        const SizedBox(height: 20),

        // 3. Support Card
        _buildSupportCard(context, scheme, textTheme),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(Icons.search_rounded, color: scheme.onSurfaceVariant, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.aboutSearchFaqHint,
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: scheme.onSurfaceVariant,
              onPressed: () {
                _searchController.clear();
                HapticService.tap();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFaqList(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
    List<(String, String)> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final int index = entry.key;
          final (String q, String a) = entry.value;
          final bool isLast = index == items.length - 1;

          return Column(
            children: <Widget>[
              _ExpandableFaqTile(
                question: q,
                answer: a,
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.15),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.aboutNoFaqResults,
            style: textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: scheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.aboutContactSupportAction,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.settingsHelpSupportSubtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              HapticService.tap();
              context.push('/chat/direct/support');
            },
            child: Text(context.l10n.commonContinue),
          ),
        ],
      ),
    );
  }
}

class _ExpandableFaqTile extends StatefulWidget {
  const _ExpandableFaqTile({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  State<_ExpandableFaqTile> createState() => _ExpandableFaqTileState();
}

class _ExpandableFaqTileState extends State<_ExpandableFaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        HapticService.selection();
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.question,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: M3SpringCurves.spatial,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  widget.answer,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              firstCurve: M3SpringCurves.spatial,
              secondCurve: M3SpringCurves.spatial,
            ),
          ],
        ),
      ),
    );
  }
}
