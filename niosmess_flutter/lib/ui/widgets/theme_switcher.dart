import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../nios_ui.dart';

/// Theme switcher with live preview cards
class ThemeSwitcher extends ConsumerStatefulWidget {
  const ThemeSwitcher({super.key});

  @override
  ConsumerState<ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends ConsumerState<ThemeSwitcher> {
  String selectedTheme = 'dark';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тема',
            style: TextStyle(
              color: NiosColors.textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildThemeCard(
                'Тёмная',
                'dark',
                NiosColors.bgPrimary,
                NiosColors.bgSurface,
                NiosColors.accentBlue,
              ),
              const SizedBox(width: 12),
              _buildThemeCard(
                'Синяя',
                'blue',
                const Color(0xFF1E293B),
                const Color(0xFF334155),
                const Color(0xFF3B82F6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    String label,
    String themeId,
    Color bgColor,
    Color surfaceColor,
    Color accentColor,
  ) {
    final isSelected = selectedTheme == themeId;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTheme = themeId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : NiosColors.textMuted.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Mini chat preview
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      // Header bar
                      Container(
                        height: 4,
                        color: surfaceColor.withOpacity(0.8),
                        margin: const EdgeInsets.only(bottom: 6),
                      ),
                      // Message bubbles
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 8,
                            decoration: BoxDecoration(
                              color: surfaceColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 24,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? accentColor : NiosColors.textGrey,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
