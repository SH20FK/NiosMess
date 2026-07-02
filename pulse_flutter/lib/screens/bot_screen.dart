import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/bot_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/widgets/pulse_skeleton.dart';

class BotScreen extends ConsumerStatefulWidget {
  const BotScreen({super.key});

  @override
  ConsumerState<BotScreen> createState() => _BotScreenState();
}

class _BotScreenState extends ConsumerState<BotScreen> {
  bool _loading = false;
  bool _creating = false;
  List<Map<String, dynamic>>? _updates;
  String? _botToken;
  String? _error;

  Future<void> _createBot() async {
    final nameCtl = TextEditingController();
    final usernameCtl = TextEditingController();
    final descCtl = TextEditingController();

    final result = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: context.l10n.botCreateTitle,
        icon: Icons.smart_toy_rounded,
        actions: [
          AppDialogAction(label: context.l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop(false)),
          AppDialogAction(label: context.l10n.botCreateTitle, isPrimary: true, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
        child: AppDialogFormContent(
          fields: [
            AppDialogField(controller: nameCtl, label: context.l10n.botFieldName),
            AppDialogField(controller: usernameCtl, label: context.l10n.botFieldUsername),
            AppDialogField(controller: descCtl, label: context.l10n.botFieldDescription, maxLines: 2),
          ],
        ),
      ),
    );

    if (result != true) {
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      return;
    }

    setState(() { _creating = true; _error = null; });
    try {
      final response = await ref.read(botRepositoryProvider).createBot(
        name: nameCtl.text.trim(),
        username: usernameCtl.text.trim(),
        description: descCtl.text.trim().isNotEmpty ? descCtl.text.trim() : null,
      );
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      final token = response['token'] as String?;
      if (!mounted) return;
      setState(() {
        _creating = false;
        _botToken = token;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.botCreated)));
    } catch (e) {
      nameCtl.dispose(); usernameCtl.dispose(); descCtl.dispose();
      if (!mounted) return;
      setState(() { _creating = false; _error = '$e'; });
    }
  }

  Future<void> _getUpdates() async {
    if (_botToken == null || _botToken!.isEmpty) {
      final tokenCtl = TextEditingController();
      final tokenResult = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AppDialog(
          title: context.l10n.botBotToken,
          icon: Icons.vpn_key_rounded,
          actions: [
            AppDialogAction(label: context.l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop()),
            AppDialogAction(label: context.l10n.botActionUse, isPrimary: true, onPressed: () => Navigator.of(ctx).pop(tokenCtl.text.trim())),
          ],
          child: AppTextFieldDialogContent(
            controller: tokenCtl,
            label: context.l10n.botFieldToken,
          ),
        ),
      );
      tokenCtl.dispose();
      if (tokenResult == null || tokenResult.isEmpty) return;
      _botToken = tokenResult;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final updates = await ref.read(botRepositoryProvider).getBotUpdates(_botToken!);
      if (!mounted) return;
      setState(() { _updates = updates; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SettingsScaffold(
      title: context.l10n.botSectionTitle,
      onRefresh: _getUpdates,
      children: [
        SettingsNavBanner(
          icon: Icons.smart_toy_rounded,
          title: context.l10n.botSectionTitle,
          subtitle: context.l10n.botSectionSubtitle,
          iconColor: Colors.cyan,
        ),
        SettingsSection(
          title: context.l10n.botCreateTitle,
          children: [
            SettingsTile(
              icon: Icons.add_circle_rounded,
              title: context.l10n.botCreateSubtitle,
              subtitle: context.l10n.botCreateDescription,
              iconColor: Colors.cyan,
              onTap: _creating ? () {} : _createBot,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
              ),
            if (_creating)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PulseSkeleton(width: 180, height: 14),
                      const SizedBox(height: 8),
                      PulseSkeleton(width: 120, height: 10, borderRadius: 5),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_botToken != null)
          SettingsSection(
            title: context.l10n.botBotToken,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_botToken!, style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                        onPressed: () {
                        Clipboard.setData(ClipboardData(text: _botToken ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.botCopied)));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          SettingsSection(
            title: context.l10n.botUpdatesTitle,
            children: [
              SettingsTile(
                icon: Icons.refresh_rounded,
                title: context.l10n.botGetUpdates,
                subtitle: context.l10n.botPollSubtitle,
              iconColor: Colors.teal,
              onTap: _loading ? () {} : _getUpdates,
            ),
            if (_loading)
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: List<Widget>.generate(3, (int i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        PulseSkeleton(width: 40, height: 40, borderRadius: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              PulseSkeleton(width: 160, height: 12),
                              const SizedBox(height: 6),
                              PulseSkeleton(width: 100, height: 10, borderRadius: 5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ),
              ),
            if (_updates != null && _updates!.isEmpty)
              EmptyFeedWidget(
                title: context.l10n.emptyStateNoItems,
                description: context.l10n.emptyStateNoItemsDesc,
              ),
            if (_updates != null)
              ..._updates!.map((update) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Icon(Icons.notifications_rounded, size: 18, color: scheme.onTertiaryContainer),
                ),
                title: Text(update['update_type'] as String? ?? 'unknown', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('${update['data']}', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              )),
          ],
        ),
      ],
    );
  }
}
