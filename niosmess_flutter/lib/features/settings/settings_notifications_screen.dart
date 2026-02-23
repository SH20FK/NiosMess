import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';
import '../../ui/widgets/animated_list_item.dart';

class SettingsNotificationsScreen extends ConsumerWidget {
  const SettingsNotificationsScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
  }) async {
    final currentRaw = ref.read(settingsProvider)[key] as String?;
    final now = TimeOfDay.now();
    TimeOfDay initial = now;
    if (currentRaw != null && currentRaw.contains(':')) {
      final parts = currentRaw.split(':');
      final h = int.tryParse(parts.first) ?? now.hour;
      final m = int.tryParse(parts.last) ?? now.minute;
      initial = TimeOfDay(hour: h, minute: m);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: title,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final formatted = picked.hour.toString().padLeft(2, '0') +
        ':' +
        picked.minute.toString().padLeft(2, '0');
    ref.read(settingsProvider.notifier).setSetting(key, formatted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: onBack,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
        ),
        title: Text(
          'Уведомления',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 0,
              child: _buildSection(
                context,
                title: 'Сообщения',
                icon: Icons.message_outlined,
                children: [
                  _buildAnimatedSwitch(
                    context,
                    title: 'Звуки',
                    subtitle: 'Проигрывать звук при новом сообщении',
                    icon: Icons.volume_up_outlined,
                    value: settings['notify_sound'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_sound', v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Вибрация',
                    subtitle: 'Вибрировать при уведомлении',
                    icon: Icons.vibration_outlined,
                    value: settings['notify_vibrate'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_vibrate', v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Предпросмотр текста',
                    subtitle: 'Показывать текст в уведомлениях',
                    icon: Icons.preview_outlined,
                    value: settings['notify_preview'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_preview', v),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 1,
              child: _buildSection(
                context,
                title: 'Группы и каналы',
                icon: Icons.groups_outlined,
                children: [
                  _buildAnimatedSwitch(
                    context,
                    title: 'Уведомления из групп',
                    subtitle: 'Получать уведомления из групповых чатов',
                    icon: Icons.group_outlined,
                    value: settings['notify_group'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_group', v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Упоминания',
                    subtitle: 'Уведомлять при @упоминании',
                    icon: Icons.alternate_email_outlined,
                    value: settings['notify_mentions'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_mentions', v),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 2,
              child: _buildSection(
                context,
                title: 'Звонки и реакции',
                icon: Icons.call_outlined,
                children: [
                  _buildAnimatedSwitch(
                    context,
                    title: 'Звонки',
                    subtitle: 'Показывать уведомления о звонках',
                    icon: Icons.phone_outlined,
                    value: settings['notify_calls'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_calls', v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Реакции',
                    subtitle: 'Уведомлять о реакциях на сообщения',
                    icon: Icons.emoji_emotions_outlined,
                    value: settings['notify_reactions'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('notify_reactions', v),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 3,
              child: _buildQuietHoursSection(context, ref, settings),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: value 
              ? colorScheme.primaryContainer 
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: value 
              ? colorScheme.onPrimaryContainer 
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildQuietHoursSection(BuildContext context, WidgetRef ref, Map<String, dynamic> settings) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = settings['quiet_hours_enabled'] ?? false;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.nights_stay_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Тихие часы',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Включить тихие часы',
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Отключать уведомления в указанное время',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isEnabled,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('quiet_hours_enabled', v),
                ),
                if (isEnabled) ...[
                  const Divider(height: 1),
                  _buildTimeTile(
                    context,
                    icon: Icons.nightlight_outlined,
                    title: 'Начало',
                    value: settings['quiet_hours_start']?.toString() ?? '22:00',
                    onTap: () => _pickTime(
                      context,
                      ref,
                      key: 'quiet_hours_start',
                      title: 'Начало тихого периода',
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildTimeTile(
                    context,
                    icon: Icons.wb_sunny_outlined,
                    title: 'Конец',
                    value: settings['quiet_hours_end']?.toString() ?? '08:00',
                    onTap: () => _pickTime(
                      context,
                      ref,
                      key: 'quiet_hours_end',
                      title: 'Конец тихого периода',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
