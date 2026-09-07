import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/inline_query_model.dart';
import 'package:pulse_flutter/providers/inline_query_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class InlineQueryOverlay extends StatelessWidget {
  const InlineQueryOverlay({
    required this.state,
    required this.onSelectResult,
    required this.onClose,
    super.key,
  });

  final InlineQueryState state;
  final void Function(InlineQueryResult result) onSelectResult;
  final VoidCallback onClose;

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'gif':
        return Icons.gif_box_outlined;
      case 'photo':
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'article':
        return Icons.article_outlined;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260, minHeight: 56),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ── Header Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.smart_toy_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '@${state.botUsername}',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                          if (state.query.isNotEmpty)
                            TextSpan(
                              text: ' • "${state.query}"',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticService.tap();
                      onClose();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Content Area ──
            Flexible(
              child: _buildContent(context, scheme, textTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    if (state.isLoading && state.results.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppLoadingIndicator(size: 22),
              SizedBox(height: 8),
              Text(
                'Поиск вариантов...',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.isLoading && state.results.isEmpty) {
      return SizedBox(
        height: 90,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off_rounded,
                size: 24,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Ничего не найдено',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: state.results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 52,
        endIndent: 12,
        color: scheme.outlineVariant.withValues(alpha: 0.2),
      ),
      itemBuilder: (BuildContext context, int index) {
        final InlineQueryResult result = state.results[index];
        final String? thumb = result.thumbUrl;

        return ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: thumb != null && thumb.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: 36,
                      height: 36,
                      color: scheme.surfaceContainerHighest,
                      child: const Center(child: AppLoadingIndicator(size: 14)),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 36,
                      height: 36,
                      color: scheme.surfaceContainerHighest,
                      child: Icon(_iconForType(result.type),
                          size: 20, color: scheme.primary),
                    ),
                  ),
                )
              : Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconForType(result.type),
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
          title: Text(
            result.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: result.description != null && result.description!.isNotEmpty
              ? Text(
                  result.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Icon(
            Icons.north_west_rounded,
            size: 16,
            color: scheme.primary.withValues(alpha: 0.6),
          ),
          onTap: () {
            HapticService.tap();
            onSelectResult(result);
          },
        );
      },
    );
  }
}
