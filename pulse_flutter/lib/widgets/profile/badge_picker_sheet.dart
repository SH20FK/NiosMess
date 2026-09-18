import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// An expressive Material 3 sheet/dialog for selecting profile badges.
class BadgePickerSheet extends ConsumerStatefulWidget {
  const BadgePickerSheet({
    this.initialSelectedBadgeIds = const <int>[],
    super.key,
  });

  final List<int> initialSelectedBadgeIds;

  static Future<List<int>?> show(
    BuildContext context, {
    List<int> initialSelectedBadgeIds = const <int>[],
  }) {
    final bool isWide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    if (isWide) {
      return AppModal.showDialog<List<int>>(
        context: context,
        maxWidth: 440,
        builder: (BuildContext context) => BadgePickerSheet(
          initialSelectedBadgeIds: initialSelectedBadgeIds,
        ),
      );
    }
    return AppModal.showSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => BadgePickerSheet(
        initialSelectedBadgeIds: initialSelectedBadgeIds,
      ),
    );
  }

  @override
  ConsumerState<BadgePickerSheet> createState() => _BadgePickerSheetState();
}

/// Backward compatibility alias for [BadgePickerSheet].
typedef BadgeSelectorDialog = BadgePickerSheet;

class _BadgePickerSheetState extends ConsumerState<BadgePickerSheet> {
  bool _isLoading = true;
  List<ApiBadge> _availableBadges = const <ApiBadge>[];
  final Set<int> _selectedIds = <int>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedBadgeIds.take(2));
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final List<ApiBadge> badges =
          await ref.read(authRepositoryProvider).getMyBadges();
      if (!mounted) return;
      setState(() {
        _availableBadges = badges;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _toggleBadge(int id) {
    HapticService.tap();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= 2) {
          AppToast.showError(context, 'Можно выбрать не более двух бейджей');
          return;
        }
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    HapticService.tap();
    setState(() => _isSaving = true);
    try {
      final List<int> saved = await ref
          .read(authRepositoryProvider)
          .setVisibleBadges(_selectedIds.toList());
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showError(context, 'Ошибка сохранения бейджей: $e');
    }
  }

  IconData _resolveBadgeIcon(ApiBadge badge) {
    switch (badge.icon.toLowerCase().trim()) {
      case 'star':
        return Icons.star_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'bug':
        return Icons.pest_control_rounded;
      case 'workspace_premium':
      case 'crown':
        return Icons.workspace_premium_rounded;
      case 'verified':
      default:
        return Icons.verified_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Resolve badges that are currently selected
    final List<ApiBadge> selectedBadges = _availableBadges
        .where((ApiBadge b) => _selectedIds.contains(b.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Выбор бейджей',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Выберите до 2 бейджей, которые будут видны в вашем профиле.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Active preview row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadii.mdRadius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  'Выбрано: ${_selectedIds.length}/2',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                for (int slot = 0; slot < 2; slot++) ...<Widget>[
                  if (slot > 0) const SizedBox(width: 8),
                  if (slot < selectedBadges.length)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadii.fullRadius,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _resolveBadgeIcon(selectedBadges[slot]),
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selectedBadges[slot].name,
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: AppRadii.fullRadius,
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        'Слот ${slot + 1}',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content list with fixed height constraints
          SizedBox(
            height: 260,
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : _availableBadges.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.military_tech_outlined,
                              size: 40,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'У вас пока нет доступных бейджей',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _availableBadges.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ApiBadge badge = _availableBadges[index];
                          final bool isSelected =
                              _selectedIds.contains(badge.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                                  : scheme.surfaceContainerLow,
                              borderRadius: AppRadii.mdRadius,
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary.withValues(alpha: 0.60)
                                    : scheme.outlineVariant.withValues(alpha: 0.20),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: AppRadii.mdRadius,
                                onTap: () => _toggleBadge(badge.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? scheme.primary
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _resolveBadgeIcon(badge),
                                          color: isSelected
                                              ? scheme.onPrimary
                                              : scheme.onSurfaceVariant,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              badge.name,
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                            if (badge.description != null &&
                                                badge.description!.isNotEmpty)
                                              Text(
                                                badge.description!,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // M3 Expressive Selection Indicator
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeOutCubic,
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? scheme.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          border: Border.all(
                                            color: isSelected
                                                ? scheme.primary
                                                : scheme.outlineVariant,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: scheme.onPrimary,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),

          // Action buttons footer
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.fullRadius,
                    ),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.fullRadius,
                    ),
                  ),
                  child: _isSaving
                      ? AppLoadingIndicator(size: 16, color: scheme.onPrimary)
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
