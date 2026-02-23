import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/nios_ui.dart';
import '../../ui/widgets/nios_design_widgets.dart';

/// Settings Main Hub Screen - Main settings screen with profile card,
/// quick theme switch, and settings list
class SettingsMainHubScreen extends ConsumerStatefulWidget {
  const SettingsMainHubScreen({
    super.key,
    required this.onBack,
    required this.onOpenAppearance,
    required this.onOpenNotifications,
    required this.onOpenPrivacy,
    required this.onOpenData,
    required this.onOpenChatSettings,
    required this.onOpenNetwork,
    required this.onOpenPasscode,
    required this.onOpenSessions,
    required this.onOpenProfile,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenData;
  final VoidCallback onOpenChatSettings;
  final VoidCallback onOpenNetwork;
  final VoidCallback onOpenPasscode;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenProfile;

  @override
  ConsumerState<SettingsMainHubScreen> createState() => _SettingsMainHubScreenState();
}

class _SettingsMainHubScreenState extends ConsumerState<SettingsMainHubScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NiosScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ProfileHeader(
              name: 'John Anderson',
              username: '@johndoe',
              phone: '+1 (555) 123-4567',
              avatarSize: 100,
              isLarge: false,
              onAvatarTap: widget.onOpenProfile,
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Settings List
                  const SectionLabel('Настройки'),
                  const SizedBox(height: 12),

                  SettingsRow(
                    leadingColor: scheme.primaryContainer,
                    icon: Icons.palette,
                    title: 'Внешний вид',
                    subtitle: 'Тема, цвета, размеры',
                    onTap: widget.onOpenAppearance,
                  ),
                  SettingsRow(
                    leadingColor: scheme.secondaryContainer,
                    icon: Icons.notifications,
                    title: 'Уведомления',
                    subtitle: 'Звук, показ, тишина',
                    onTap: widget.onOpenNotifications,
                  ),
                  SettingsRow(
                    leadingColor: scheme.tertiaryContainer,
                    icon: Icons.shield,
                    title: 'Приватность и безопасность',
                    subtitle: 'Статус, чтение, защита',
                    onTap: widget.onOpenPrivacy,
                  ),
                  SettingsRow(
                    leadingColor: scheme.primaryContainer,
                    icon: Icons.pie_chart,
                    title: 'Данные и хранилище',
                    subtitle: 'Кэш, медиа, авто‑загрузка',
                    onTap: widget.onOpenData,
                  ),
                  SettingsRow(
                    leadingColor: scheme.secondaryContainer,
                    icon: Icons.forum,
                    title: 'Чаты',
                    subtitle: 'Пузыри, текст, поведение',
                    onTap: widget.onOpenChatSettings,
                  ),
                  SettingsRow(
                    leadingColor: scheme.tertiaryContainer,
                    icon: Icons.wifi,
                    title: 'Сеть',
                    subtitle: 'Прокси, трафик, фон',
                    onTap: widget.onOpenNetwork,
                  ),
                  SettingsRow(
                    leadingColor: scheme.primaryContainer,
                    icon: Icons.lock,
                    title: 'Код‑пароль',
                    subtitle: 'Блокировка приложения',
                    onTap: widget.onOpenPasscode,
                  ),
                  SettingsRow(
                    leadingColor: scheme.secondaryContainer,
                    icon: Icons.devices,
                    title: 'Активные сессии',
                    subtitle: 'Устройства и доступы',
                    onTap: widget.onOpenSessions,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Floating Bottom Navigation
          FloatingBottomNav(
            currentIndex: 3,
            onTap: (index) {
              HapticFeedback.selectionClick();
              if (index == 0) {
                widget.onBack();
              }
            },
          ),
        ],
      ),
    );
  }
}
