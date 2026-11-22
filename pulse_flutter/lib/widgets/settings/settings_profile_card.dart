import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

/// The account at the top of the settings hub: who is signed in, and the way
/// into the Account section. Changing the photo, the QR code and profile
/// editing live inside that section, not on the card.
class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    required this.displayName,
    required this.username,
    required this.onTap,
    this.avatarUrl,
    super.key,
  });

  final String displayName;
  final String username;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground = scheme.onSurface;
    final Color secondary = scheme.onSurfaceVariant;
    return Semantics(
      container: true,
      button: true,
      child: PressableSurface(
        key: const ValueKey<String>('settings-profile-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          SettingsSection.outerRadius(context),
        ),
        color: scheme.surfaceContainerLow,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          label: username.isEmpty ? displayName : '$displayName, @$username',
          excludeSemantics: true,
          child: Row(
            children: <Widget>[
              PulseAvatar(
                name: displayName,
                avatarUrl: avatarUrl,
                radius: 28,
                fallbackColor: scheme.primaryContainer,
                textColor: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (username.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '@$username',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: secondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.chevron_right_rounded, color: secondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
