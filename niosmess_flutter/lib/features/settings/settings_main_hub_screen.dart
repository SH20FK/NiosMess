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
  int _selectedThemeIndex = 0;

  @override
  Widget build(BuildContext context) {
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

                  // Quick Theme Switch Section
                  const SectionLabel('Quick Theme Switch'),
                  const SizedBox(height: 12),

                  // Theme Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ThemePreviewCard(
                          label: 'Aurora Glass',
                          isSelected: _selectedThemeIndex == 0,
                          topBarColor: NiosPalette.surfaceAlt,
                          bubbleLeftColor: NiosPalette.surfaceAlt,
                          bubbleRightColor: NiosPalette.accent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedThemeIndex = 0);
                          },
                        ),
                        const SizedBox(width: 12),
                        ThemePreviewCard(
                          label: 'Violet Pulse',
                          isSelected: _selectedThemeIndex == 1,
                          topBarColor: const Color(0xFF2E1B44),
                          bubbleLeftColor: const Color(0xFF3A2356),
                          bubbleRightColor: const Color(0xFFC084FC),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedThemeIndex = 1);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Settings List
                  const SectionLabel('Settings'),
                  const SizedBox(height: 12),

                    // Row 1: Appearance
                    SettingsRow(
                      gradient: NiosGradients.gradientBlue,
                      icon: Icons.palette,
                      title: 'Appearance',
                      subtitle: 'Dark Blue Theme',
                      onTap: widget.onOpenAppearance,
                    ),

                    // Row 2: Notifications
                    SettingsRow(
                      gradient: NiosGradients.gradientOrange,
                      icon: Icons.notifications,
                      title: 'Notifications',
                      subtitle: 'All notifications enabled',
                      onTap: widget.onOpenNotifications,
                    ),

                    // Row 3: Privacy & Security
                    SettingsRow(
                      gradient: NiosGradients.gradientPurple,
                      icon: Icons.shield,
                      title: 'Privacy & Security',
                      subtitle: 'Ghost Mode, Read Receipts',
                      onTap: widget.onOpenPrivacy,
                    ),

                    // Row 4: Data & Storage
                    SettingsRow(
                      gradient: NiosGradients.gradientGreen,
                      icon: Icons.pie_chart,
                      title: 'Data & Storage',
                      subtitle: '2.4 GB used',
                      onTap: widget.onOpenData,
                    ),

                    // Row 5: Chat Settings
                    SettingsRow(
                      gradient: NiosGradients.gradientBlue,
                      icon: Icons.forum,
                      title: 'Chat Settings',
                      subtitle: 'Bubbles, Text Size',
                      onTap: widget.onOpenChatSettings,
                    ),

                    // Row 6: Network & Data
                    SettingsRow(
                      gradient: NiosGradients.gradientPink,
                      icon: Icons.wifi,
                      title: 'Network & Data',
                      subtitle: 'Auto-download, Proxy',
                      onTap: widget.onOpenNetwork,
                    ),

                    // Row 7: Passcode Lock
                    SettingsRow(
                      gradient: NiosGradients.gradientRed,
                      icon: Icons.lock,
                      title: 'Passcode Lock',
                      subtitle: 'Disabled',
                      onTap: widget.onOpenPasscode,
                    ),

                    // Row 8: Active Sessions
                    SettingsRow(
                      gradient: NiosGradients.gradientPurple,
                      icon: Icons.devices,
                      title: 'Active Sessions',
                      subtitle: '3 devices',
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
