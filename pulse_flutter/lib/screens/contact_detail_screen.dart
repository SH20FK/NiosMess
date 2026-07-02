import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/constants/app_constants.dart';
import 'package:pulse_flutter/models/api/profile_model.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/badge_chip.dart';
import 'package:pulse_flutter/widgets/glass_card.dart';
import 'package:pulse_flutter/widgets/pulse_avatar.dart';
import 'package:pulse_flutter/widgets/pulse_button.dart';
import 'package:pulse_flutter/widgets/pulse_page_header.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/widgets/pulse_scaffold_body.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  ApiProfile? _profile;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ApiProfile profile = await ref
          .read(authRepositoryProvider)
          .getPublicProfile(widget.username);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.contactDetailTitle)),
      body: PulseScaffoldBody(
        maxWidth: 1120,
        child: _loading
            ? const PulseLoadingIndicator()
            : _profile == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.person_search_rounded,
                        size: 56,
                        color: scheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error ?? 'Contact not found',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.screenHorizontalPadding,
                  vertical: 12,
                ),
                children: <Widget>[
                  PulsePageHeader(
                    title: _profile!.displayName,
                    subtitle: '@${_profile!.username}',
                    icon: Icons.person_pin_circle_outlined,
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: <Widget>[
                        Hero(
                          tag: 'user-avatar-${_profile!.username}',
                          child: Stack(
                            children: [
                              PulseAvatar(
                                name: _profile!.displayName,
                                avatarUrl: _profile!.avatarUrl,
                                radius: 58,
                                fallbackColor: scheme.primaryContainer,
                                textColor: scheme.onPrimaryContainer,
                              ),
                              if (_profile!.badges.isNotEmpty)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: BadgeChip(
                                    id: _profile!.badges.first.id,
                                    name: _profile!.badges.first.name,
                                    icon: _profile!.badges.first.icon,
                                    color: _profile!.badges.first.color,
                                    mode: BadgeDisplayMode.avatarBadge,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _profile!.displayName,
                                style: textTheme.headlineSmall,
                              ),
                            ),
                            if (_profile!.badges.where((b) => BadgeResolver.isStatusBadge(b)).isNotEmpty) ...[
                              const SizedBox(width: 6),
                              ..._profile!.badges.where((b) => BadgeResolver.isStatusBadge(b)).map((b) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: BadgeChip(
                                  id: b.id, name: b.name, icon: b.icon, color: b.color,
                                  mode: BadgeDisplayMode.statusIcon,
                                ),
                              )),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${_profile!.username}',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (_profile!.badges.where((b) => !BadgeResolver.isStatusBadge(b)).isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: _profile!.badges.where((b) => !BadgeResolver.isStatusBadge(b))
                                .map(
                                  (badge) => BadgeChip(
                                    id: badge.id,
                                    name: badge.name,
                                    icon: badge.icon,
                                    color: badge.color,
                                    showName: true,
                                    mode: BadgeDisplayMode.infoLabel,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                        if (_profile!.bio.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Text(
                            _profile!.bio,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 170,
                              child: PulseButton(
                                label: context.l10n.contactsMessage,
                                icon: Icons.chat_rounded,
                                onPressed: () => context.push(
                                  '/chat/dm/${_profile!.username}',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 170,
                              child: PulseButton(
                                label: context.l10n.settingsSecretChatsButton,
                                icon: Icons.lock_rounded,
                                onPressed: () => context.push(
                                  '/chat/dm/${_profile!.username}?isSecret=1',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool stacked = constraints.maxWidth < 760;
                      final Widget infoContent = GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.contactDetailOverview,
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            _infoRow(
                              context,
                              Icons.alternate_email_rounded,
                              context.l10n.contactDetailUsername,
                              '@${_profile!.username}',
                            ),
                            const SizedBox(height: 10),
                            _infoRow(
                              context,
                              Icons.info_outline_rounded,
                              context.l10n.contactDetailBio,
                              _profile!.bio.isEmpty
                                  ? context.l10n.contactDetailNoBio
                                  : _profile!.bio,
                            ),
                          ],
                        ),
                      );
                      final Widget groupsContent = GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.contactDetailSharedContext,
                              style: textTheme.titleLarge,
                            ),
                            Text(
                              context.l10n.contactDetailSharedContextDesc,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                      return stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                infoContent,
                                const SizedBox(height: 12),
                                groupsContent,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: infoContent),
                                const SizedBox(width: 12),
                                Expanded(child: groupsContent),
                              ],
                            );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
