import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/datetime_helpers.dart';
import 'package:pulse_flutter/models/api/session_model.dart';
import 'package:pulse_flutter/repositories/auth_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<ApiSession>? _sessions;
  bool _loading = true;
  String? _error;

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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => SettingsConfirmDialog(
        title: context.l10n.sessionsRevokeTitle,
        body: 'This device will be logged out if it\'s the current session.', // Keeping original description or we could use l10n
        confirmLabel: context.l10n.sessionsRevokeConfirm,
        cancelLabel: context.l10n.sessionsCancel,
        destructive: true,
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).revokeSession(sessionId);
      await _loadSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.sessionsRevokedSuccess)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : '$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // We don't have a reliable way to determine current session id from AuthSession yet
    final int? currentSessionId = null;

    return SettingsScaffold(
      title: context.l10n.sessionsTitle,
      children: <Widget>[
        SettingsNavBanner(
          icon: Icons.devices_rounded,
          title: context.l10n.sessionsTitle,
          subtitle: 'Manage your active devices and sessions.',
          iconColor: Colors.blueGrey,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: PulseLoadingIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(_error!, style: TextStyle(color: scheme.error)),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadSessions,
                    child: Text(context.l10n.sessionsRetry),
                  ),
                ],
              ),
            ),
          )
        else if (_sessions == null || _sessions!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text(context.l10n.sessionsEmpty)),
          )
        else
          SettingsSection(
            children: _sessions!.map((ApiSession session) {
              final bool isCurrent = session.id == currentSessionId;
              return SettingsSessionTile(
                icon: Icons.smartphone_rounded,
                title: session.deviceInfo,
                subtitle: 'Active: ${formatRelativeTime(session.lastActive)}',
                ip: 'Created: ${formatFullDateTime(session.createdAt)}',
                isCurrent: isCurrent,
                currentLabel: 'Current', // Hardcode fallback or l10n
                onRevoke: () => _revokeSession(session.id),
              );
            }).toList(),
          ),
      ],
    );
  }
}
