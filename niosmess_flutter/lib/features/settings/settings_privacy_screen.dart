import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/settings_provider.dart';
import '../../core/ghost_mode_provider.dart';
import '../../core/app_lock_provider.dart';
import '../../ui/widgets/animated_list_item.dart';
import '../../ui/widgets/animated_toggle_switch.dart';

class SettingsPrivacyScreen extends ConsumerWidget {
  const SettingsPrivacyScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ghostMode = ref.watch(ghostModeProvider);
    final lockState = ref.watch(appLockProvider);
    final whoCanWrite = (settings['who_can_write'] as String?) ?? 'all';
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
          'Конфиденциальность',
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
                title: 'Видимость',
                icon: Icons.visibility_outlined,
                children: [
                  _buildOptionTile(
                    context,
                    title: 'Последнее посещение',
                    value: (settings['last_seen_visibility'] as String?) ?? 'Все',
                    icon: Icons.access_time_outlined,
                    onTap: () => _selectOption(
                      context,
                      ref,
                      key: 'last_seen_visibility',
                      title: 'Последнее посещение',
                      options: const ['Все', 'Контакты', 'Никто'],
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    context,
                    title: 'Фото профиля',
                    value: (settings['photo_visibility'] as String?) ?? 'Все',
                    icon: Icons.photo_outlined,
                    onTap: () => _selectOption(
                      context,
                      ref,
                      key: 'photo_visibility',
                      title: 'Фото профиля',
                      options: const ['Все', 'Контакты', 'Никто'],
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Индикатор набора',
                    subtitle: 'Показывать, когда вы печатаете',
                    icon: Icons.keyboard_outlined,
                    value: settings['show_typing'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('show_typing', v),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Отчёты о прочтении',
                    subtitle: 'Показывать отметки «прочитано»',
                    icon: Icons.done_all_outlined,
                    value: settings['read_receipts'] ?? true,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setSetting('read_receipts', v),
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
                title: 'Контакты',
                icon: Icons.contacts_outlined,
                children: [
                  _buildOptionTile(
                    context,
                    title: 'Кто может писать мне',
                    value: _formatWhoCanWrite(whoCanWrite),
                    icon: Icons.message_outlined,
                    onTap: () => _selectOption(
                      context,
                      ref,
                      key: 'who_can_write',
                      title: 'Кто может писать мне',
                      options: const ['all', 'contacts', 'nobody'],
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildOptionTile(
                    context,
                    title: 'Кто может звонить мне',
                    value: (settings['call_privacy'] as String?) ?? 'Все',
                    icon: Icons.phone_outlined,
                    onTap: () => _selectOption(
                      context,
                      ref,
                      key: 'call_privacy',
                      title: 'Кто может звонить мне',
                      options: const ['Все', 'Контакты', 'Никто'],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 2,
              child: _buildGhostModeSection(context, ref, ghostMode),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedListItem(
              index: 3,
              child: _buildSecuritySection(context, ref, lockState),
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

  Widget _buildGhostModeSection(BuildContext context, WidgetRef ref, ghostMode) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = ghostMode.isActive;
    
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
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ghost Mode',
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
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: isActive
                    ? Border.all(
                        color: colorScheme.tertiary.withOpacity(0.5),
                        width: 2,
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: colorScheme.tertiary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colorScheme.tertiaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: colorScheme.tertiary.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        size: 24,
                        color: isActive
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      'Скрытый режим',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Чтение без отметки «прочитано»',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: AnimatedToggleSwitch(
                      value: isActive,
                      onChanged: (v) {
                        if (v) {
                          ref.read(ghostModeProvider.notifier).activate();
                        } else {
                          ref.read(ghostModeProvider.notifier).deactivate();
                        }
                        ref.read(settingsProvider.notifier).setSetting('ghost_mode', v);
                      },
                      activeColor: colorScheme.tertiary,
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ваши собеседники не будут видеть, что вы прочитали их сообщения',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, WidgetRef ref, lockState) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    
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
                  Icons.security_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Безопасность',
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
                _buildAnimatedSwitch(
                  context,
                  title: 'Блокировка паролем',
                  subtitle: 'Запрашивать PIN при входе',
                  icon: Icons.lock_outline,
                  value: lockState.isEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final pin = await _promptNewPin(context);
                      if (pin == null) return;
                      await ref.read(appLockProvider.notifier).enable(pin);
                      ref.read(settingsProvider.notifier).setSetting('passcode_lock', true);
                    } else {
                      final ok = await _promptPinVerify(context, ref);
                      if (!ok) return;
                      await ref.read(appLockProvider.notifier).disable();
                      ref.read(settingsProvider.notifier).setSetting('passcode_lock', false);
                    }
                  },
                ),
                if (lockState.isEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  _buildAnimatedSwitch(
                    context,
                    title: 'Вход по биометрии',
                    subtitle: lockState.biometricAvailable ? 'Face ID / Touch ID' : 'Биометрия недоступна',
                    icon: Icons.fingerprint_outlined,
                    value: lockState.biometricEnabled,
                    onChanged: lockState.biometricAvailable
                        ? (v) => ref.read(appLockProvider.notifier).setBiometricEnabled(v)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
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

  Widget _buildAnimatedSwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
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

  String _formatWhoCanWrite(String value) {
    switch (value) {
      case 'contacts':
        return 'Контакты';
      case 'nobody':
        return 'Никто';
      case 'all':
      default:
        return 'Все';
    }
  }

  Future<void> _selectOption(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required List<String> options,
  }) async {
    final current = ref.read(settingsProvider)[key] as String?;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...options.map((opt) => RadioListTile<String>(
                  value: opt,
                  groupValue: current ?? options.first,
                  onChanged: (value) => Navigator.pop(context, value),
                  title: Text(key == 'who_can_write' ? _formatWhoCanWrite(opt) : opt),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(settingsProvider.notifier).setSetting(key, selected);
    }
  }

  Future<String?> _promptNewPin(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _PinSetupDialog(),
    );
  }

  Future<bool> _promptPinVerify(BuildContext context, WidgetRef ref) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinVerifyDialog(),
    );
    if (pin == null || pin.isEmpty) return false;
    final ok = await ref.read(appLockProvider.notifier).verifyPin(pin);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный PIN')),
      );
    }
    return ok;
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создайте PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _first,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
          ),
          TextField(
            controller: _second,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Повторите PIN', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final p1 = _first.text.trim();
            final p2 = _second.text.trim();
            if (p1.length < 4 || p2.length < 4) {
              setState(() => _error = 'Введите 4 цифры');
              return;
            }
            if (p1 != p2) {
              setState(() => _error = 'PIN не совпадает');
              return;
            }
            Navigator.pop(context, p1);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Введите PIN'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        decoration: const InputDecoration(counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Продолжить'),
        ),
      ],
    );
  }
}
