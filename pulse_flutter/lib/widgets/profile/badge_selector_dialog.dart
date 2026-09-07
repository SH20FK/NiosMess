import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/models/api/badge_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';

class BadgeSelectorDialog extends ConsumerStatefulWidget {
  const BadgeSelectorDialog({
    this.initialSelectedBadgeIds = const <int>[],
    super.key,
  });

  final List<int> initialSelectedBadgeIds;

  static Future<List<int>?> show(
    BuildContext context, {
    List<int> initialSelectedBadgeIds = const <int>[],
  }) {
    return showDialog<List<int>>(
      context: context,
      builder: (BuildContext context) => BadgeSelectorDialog(
        initialSelectedBadgeIds: initialSelectedBadgeIds,
      ),
    );
  }

  @override
  ConsumerState<BadgeSelectorDialog> createState() =>
      _BadgeSelectorDialogState();
}

class _BadgeSelectorDialogState extends ConsumerState<BadgeSelectorDialog> {
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
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Можно выбрать не более двух бейджей'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _save() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения бейджей: $e')),
      );
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Выбор бейджей',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Выберите до 2 бейджей, которые будут видны в вашем профиле.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _availableBadges.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.military_tech_outlined,
                                    size: 48,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'У вас пока нет доступных бейджей',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableBadges.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ApiBadge badge = _availableBadges[index];
                              final bool isSelected =
                                  _selectedIds.contains(badge.id);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? scheme.primaryContainer.withValues(alpha: 0.4)
                                      : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? scheme.primary
                                        : scheme.outlineVariant.withValues(alpha: 0.4),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? scheme.primary
                                          : scheme.primaryContainer,
                                      child: Icon(
                                        _resolveBadgeIcon(badge),
                                        color: isSelected
                                            ? scheme.onPrimary
                                            : scheme.onPrimaryContainer,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      badge.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      badge.description != null &&
                                              badge.description!.isNotEmpty
                                          ? badge.description!
                                          : 'Цвет: ${badge.color}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),

                                    trailing: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleBadge(badge.id),
                                    ),
                                    onTap: () => _toggleBadge(badge.id),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
