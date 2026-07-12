import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/session_model.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:pulse_flutter/widgets/app_error_banner.dart';

IconData _deviceIcon(String deviceInfo) {
  final String lower = deviceInfo.toLowerCase();
  if (lower.contains('iphone') || lower.contains('ios')) {
    return Icons.phone_iphone_rounded;
  } else if (lower.contains('ipad') || lower.contains('tablet')) {
    return Icons.tablet_rounded;
  } else if (lower.contains('android')) {
    return Icons.phone_android_rounded;
  } else if (lower.contains('macos') || lower.contains('mac os')) {
    return Icons.laptop_mac_rounded;
  } else if (lower.contains('windows') || lower.contains('win32')) {
    return Icons.laptop_windows_rounded;
  } else if (lower.contains('linux')) {
    return Icons.laptop_chromebook_rounded;
  } else if (lower.contains('web') ||
      lower.contains('browser') ||
      lower.contains('chrome') ||
      lower.contains('firefox') ||
      lower.contains('safari') ||
      lower.contains('edge')) {
    return Icons.language_rounded;
  }
  return Icons.devices_rounded;
}

String _deviceOs(String deviceInfo) {
  final String lower = deviceInfo.toLowerCase();
  if (lower.contains('iphone') || lower.contains('ios')) return 'iOS';
  if (lower.contains('ipad')) return 'iPadOS';
  if (lower.contains('android')) return 'Android';
  if (lower.contains('macos') || lower.contains('mac os')) return 'macOS';
  if (lower.contains('windows')) return 'Windows';
  if (lower.contains('linux')) return 'Linux';
  if (lower.contains('web') || lower.contains('browser')) return 'Web';
  return '';
}

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<ApiSession>? _sessions;
  bool _loading = true;
  bool _terminatingAll = false;
  String? _error;
  int? _revokingId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ApiSession> sessions = await ref
          .read(authRepositoryProvider)
          .getSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : '$e';
        _loading = false;
      });
    }
  }

  Future<void> _revokeSession(int sessionId) async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.sessionsRevokeTitle,
      subtitle: context.l10n.sessionsRevokeBody,
      confirmLabel: context.l10n.sessionsRevokeConfirm,
      cancelLabel: context.l10n.sessionsCancel,
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _revokingId = sessionId);
    try {
      await ref.read(authRepositoryProvider).revokeSession(sessionId);
      await _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sessionsRevokedSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  Future<void> _terminateAllOther() async {
    final bool? confirmed = await showAppConfirmDialog(
      context: context,
      title: context.l10n.sessionsTerminateAllConfirmTitle,
      subtitle: context.l10n.sessionsTerminateAllConfirmBody,
      confirmLabel: context.l10n.sessionsRevokeConfirm,
      cancelLabel: context.l10n.sessionsCancel,
      icon: Icons.devices_other_rounded,
      destructive: true,
    );
    if (confirmed != true) return;

    setState(() => _terminatingAll = true);
    try {
      final List<int> otherIds = _sessions!
          .where((ApiSession s) => s.id != null)
          .map((ApiSession s) => s.id)
          .toList();
      for (final int id in otherIds) {
        await ref.read(authRepositoryProvider).revokeSession(id);
      }
      await _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sessionsRevokedSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    } finally {
      if (mounted) setState(() => _terminatingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    // We don't have a reliable way to determine current session id yet
    final int? currentSessionId = null;

    return SettingsScaffold(
      title: context.l10n.sessionsTitle,
      onRefresh: _loadSessions,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.devices_rounded,
          title: context.l10n.sessionsTitle,
          subtitle: context.l10n.sessionsBannerSubtitle,
          iconColor: Colors.blueGrey,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: AppLoadingIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: AppErrorBanner(
              message: _error!,
              variant: AppErrorBannerVariant.centered,
              onRetry: _loadSessions,
            ),
          )
        else if (_sessions == null || _sessions!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(context.l10n.sessionsEmpty)),
          )
        else ...[
          if (_sessions!.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _terminatingAll ? null : _terminateAllOther,
                  icon: _terminatingAll
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.devices_other_rounded, size: 20),
                  label: Text(context.l10n.sessionsTerminateAll),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          SettingsSection(
            children: _sessions!.map((ApiSession session) {
              final bool isCurrent = session.id == currentSessionId;
              final bool isRevoking = session.id == _revokingId;
              final IconData icon = _deviceIcon(session.deviceInfo);
              final String os = _deviceOs(session.deviceInfo);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                color: isCurrent
                    ? scheme.primaryContainer.withValues(alpha: 0.5)
                    : scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: isCurrent
                      ? BorderSide(
                          color: scheme.primary.withValues(alpha: 0.3),
                        )
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onLongPress: () => _revokeSession(session.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon,
                            color: isCurrent
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      session.deviceInfo.isNotEmpty
                                          ? session.deviceInfo
                                          : context.l10n.settingsUserFallback,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.primary,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        context.l10n.sessionsCurrent,
                                        style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
     
                              Row(
                                children: <Widget>[
                                  if (os.isNotEmpty) ...[
                                    Icon(
                                      Icons.circle_rounded,
                                      size: 5,
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      os,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      context.l10n.sessionsActive(
                                        formatRelativeTime(session.lastActive),
                                      ),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.sessionsCreated(
                                  formatFullDateTime(session.createdAt),
                                ),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isRevoking)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        else
                          IconButton(
                            onPressed: () => _revokeSession(session.id),
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            tooltip: context.l10n.sessionsRevokeConfirm,
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.error,
                              backgroundColor:
                                  scheme.error.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
