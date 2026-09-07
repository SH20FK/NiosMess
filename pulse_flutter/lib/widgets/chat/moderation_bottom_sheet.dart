import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/utils/app_bottom_sheets.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/chat_member_model.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';

class ModerationBottomSheet extends ConsumerStatefulWidget {
  const ModerationBottomSheet({
    super.key,
    required this.chatId,
    required this.member,
    this.callerRole = 'member',
  });

  final int chatId;
  final ApiChatMember member;
  final String callerRole; // 'owner', 'admin', or 'member'

  static Future<void> show(
    BuildContext context, {
    required int chatId,
    required ApiChatMember member,
    String callerRole = 'member',
  }) {
    return AppBottomSheets.show<void>(
      context: context,
      builder: (BuildContext ctx) => ModerationBottomSheet(
        chatId: chatId,
        member: member,
        callerRole: callerRole,
      ),
    );
  }

  @override
  ConsumerState<ModerationBottomSheet> createState() =>
      _ModerationBottomSheetState();
}

class _ModerationBottomSheetState extends ConsumerState<ModerationBottomSheet> {
  final TextEditingController _reasonController = TextEditingController();
  int _selectedDurationSeconds = 3600; // default: 1 hour
  bool _isActionLoading = false;

  static const List<Map<String, dynamic>> _durations = <Map<String, dynamic>>[
    <String, dynamic>{'label': '1 час', 'seconds': 3600},
    <String, dynamic>{'label': '24 часа', 'seconds': 86400},
    <String, dynamic>{'label': '7 дней', 'seconds': 604800},
    <String, dynamic>{'label': 'Навсегда', 'seconds': 0},
  ];

  static const List<String> _quickReasons = <String>[
    'Спам',
    'Оскорбления',
    'Флуд',
    'Нарушение правил',
    'Реклама',
  ];

  bool get _isSupportUser {
    final String u = widget.member.username.toLowerCase();
    return widget.member.userId == 1 || u == 'support';
  }

  bool get _isOwnerProtected => widget.member.isOwner;

  bool get _isAdminProtected {
    // If caller is admin (not owner) and target is admin or owner
    final bool callerIsAdmin = widget.callerRole == 'admin';
    final bool callerIsOwner = widget.callerRole == 'owner';
    if (!callerIsOwner && callerIsAdmin) {
      return widget.member.isAdmin || widget.member.isOwner;
    }
    return false;
  }

  String? get _restrictionError {
    if (_isSupportUser) {
      return 'Пользователь Support защищён от модерации';
    }
    if (_isOwnerProtected) {
      return 'Создатель группы защищён от модерации';
    }
    if (_isAdminProtected) {
      return 'Администратор не может применить санкции к равному администратору';
    }
    return null;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _executeMute(bool mute) async {
    final String reason = _reasonController.text.trim();
    setState(() => _isActionLoading = true);
    try {
      await ref.read(chatRepositoryProvider).muteUser(
            widget.chatId,
            widget.member.userId,
            mute,
            durationSeconds: mute && _selectedDurationSeconds > 0
                ? _selectedDurationSeconds
                : null,
            reason: reason.isNotEmpty ? reason : null,
          );
      if (!mounted) return;
      HapticService.confirm();
      AppToast.showSuccess(
        context,
        mute ? 'Участник заглушен' : 'Ограничение снято',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticService.destructive();
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _executeBan(bool ban) async {
    final String reason = _reasonController.text.trim();
    setState(() => _isActionLoading = true);
    try {
      await ref.read(chatRepositoryProvider).banUser(
            widget.chatId,
            widget.member.userId,
            ban,
            durationSeconds: ban && _selectedDurationSeconds > 0
                ? _selectedDurationSeconds
                : null,
            reason: reason.isNotEmpty ? reason : null,
          );
      if (!mounted) return;
      HapticService.confirm();
      AppToast.showSuccess(
        context,
        ban ? 'Участник заблокирован в группе' : 'Участник разблокирован',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticService.destructive();
      AppToast.showError(context, e);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? errorText = _restrictionError;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
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

              // Header: member info
              Row(
                children: <Widget>[
                  PulseAvatar(
                    name: widget.member.displayName.isNotEmpty
                        ? widget.member.displayName
                        : widget.member.username,
                    avatarUrl: widget.member.avatarUrl,
                    radius: 26,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.member.displayName.isNotEmpty
                              ? widget.member.displayName
                              : widget.member.username,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${widget.member.username}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.member.isOwner)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Владелец',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (widget.member.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Администратор',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              if (errorText != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.shield_outlined,
                          color: scheme.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorText,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const SizedBox(height: 20),

                // Duration presets
                Text(
                  'Длительность ограничения',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _durations.map((Map<String, dynamic> item) {
                    final int sec = item['seconds'] as int;
                    final bool isSelected = _selectedDurationSeconds == sec;
                    return ChoiceChip(
                      label: Text(item['label'] as String),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        if (selected) {
                          HapticService.tap();
                          setState(() => _selectedDurationSeconds = sec);
                        }
                      },
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 16),

                // Reason Field
                Text(
                  'Причина ограничения',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons.map((String reason) {
                    return ActionChip(
                      label: Text(reason),
                      onPressed: () {
                        HapticService.tap();
                        setState(() {
                          _reasonController.text = reason;
                        });
                      },
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    hintText: 'Укажите причину (необязательно)...',
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Actions: Mute / Unmute & Ban / Unban
                Row(
                  children: <Widget>[
                    Expanded(
                      child: widget.member.isMuted
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.volume_up_rounded),
                              label: const Text('Снять мут'),
                              onPressed: _isActionLoading
                                  ? null
                                  : () => _executeMute(false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : FilledButton.tonalIcon(
                              icon: const Icon(Icons.volume_off_rounded),
                              label: const Text('Заглушить'),
                              onPressed: _isActionLoading
                                  ? null
                                  : () => _executeMute(true),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: widget.member.isBanned
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.lock_open_rounded),
                              label: const Text('Разбанить'),
                              onPressed: _isActionLoading
                                  ? null
                                  : () => _executeBan(false),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            )
                          : FilledButton.icon(
                              icon: const Icon(Icons.block_rounded),
                              label: const Text('Заблокировать'),
                              onPressed: _isActionLoading
                                  ? null
                                  : () => _executeBan(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.error,
                                foregroundColor: scheme.onError,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
