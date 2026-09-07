import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';

class AutoDeleteBottomSheet extends ConsumerStatefulWidget {
  const AutoDeleteBottomSheet({
    super.key,
    required this.chatId,
    this.currentAutoDeleteSeconds,
  });

  final int chatId;
  final int? currentAutoDeleteSeconds;

  static Future<int?> show(
    BuildContext context, {
    required int chatId,
    int? currentAutoDeleteSeconds,
  }) {
    return AppBottomSheets.show<int?>(
      context: context,
      builder: (BuildContext ctx) => AutoDeleteBottomSheet(
        chatId: chatId,
        currentAutoDeleteSeconds: currentAutoDeleteSeconds,
      ),
    );
  }

  @override
  ConsumerState<AutoDeleteBottomSheet> createState() =>
      _AutoDeleteBottomSheetState();
}

class _AutoDeleteBottomSheetState extends ConsumerState<AutoDeleteBottomSheet> {
  late int _selectedSeconds;
  bool _isCustom = false;
  double _customDays = 1.0;
  bool _isSaving = false;

  static const List<int> _presetSeconds = <int>[
    0, // Off
    86400, // 24 hours
    604800, // 7 days
    2592000, // 30 days
  ];

  @override
  void initState() {
    super.initState();
    final int initial = widget.currentAutoDeleteSeconds ?? 0;
    _selectedSeconds = initial;
    if (initial > 0 && !_presetSeconds.contains(initial)) {
      _isCustom = true;
      _customDays = (initial / 86400).clamp(1.0, 365.0);
    }
  }

  Future<void> _save() async {
    final int secondsToSave = _isCustom
        ? (_customDays * 86400).round()
        : _selectedSeconds;

    setState(() => _isSaving = true);
    try {
      final ApiChatSummary? updated = await ref
          .read(chatRepositoryProvider)
          .updateChat(
            widget.chatId,
            autoDeleteSeconds: secondsToSave > 0 ? secondsToSave : null,
            clearAutoDelete: secondsToSave <= 0,
          );

      if (updated != null) {
        ref.invalidate(chatsProvider);
        ref.invalidate(chatByIdProvider(widget.chatId));
      }

      if (!mounted) return;
      HapticService.confirm();
      AppToast.showSuccess(context, 'Автоудаление сообщений обновлено');
      Navigator.of(context).pop(secondsToSave > 0 ? secondsToSave : null);
    } catch (e) {
      if (!mounted) return;
      HapticService.destructive();
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_delete_rounded,
                    color: scheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Автоудаление сообщений',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Новые сообщения будут автоматически удаляться через выбранный период',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Presets
            ..._presetSeconds.map((int seconds) {
              final bool isSelected = !_isCustom && _selectedSeconds == seconds;
              final String title = seconds == 0
                  ? 'Отключено'
                  : seconds == 86400
                      ? '24 часа (1 день)'
                      : seconds == 604800
                          ? '7 дней (1 неделя)'
                          : '1 месяц (30 дней)';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer.withValues(alpha: 0.35)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                  onTap: () {
                    HapticService.tap();
                    setState(() {
                      _isCustom = false;
                      _selectedSeconds = seconds;
                    });
                  },
                ),
              );
            }),

            // Custom duration option
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _isCustom
                    ? scheme.primaryContainer.withValues(alpha: 0.35)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isCustom
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.2),
                  width: _isCustom ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: <Widget>[
                  ListTile(
                    title: Text(
                      'Свой срок: ${_customDays.round()} дн.',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: _isCustom ? FontWeight.w700 : FontWeight.w500,
                        color: _isCustom ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                    trailing: _isCustom
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                    onTap: () {
                      HapticService.tap();
                      setState(() => _isCustom = true);
                    },
                  ),
                  if (_isCustom)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: <Widget>[
                          Slider(
                            value: _customDays,
                            min: 1.0,
                            max: 365.0,
                            divisions: 364,
                            label: '${_customDays.round()} дн.',
                            onChanged: (double val) {
                              setState(() => _customDays = val);
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                '1 день',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '365 дней',
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            PulseButton(
              label: 'Сохранить',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
