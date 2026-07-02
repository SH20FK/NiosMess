import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/repositories/admin_repository.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';
import 'package:pulse_flutter/core/network/api_exception.dart';
import 'package:pulse_flutter/widgets/empty_feed_widget.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

enum _AdminTab { users, chats }

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final TextEditingController _passwordController = TextEditingController();
  String? _adminPassword;
  bool _loading = false;
  _AdminTab _tab = _AdminTab.users;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _chats = [];
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _adminPassword = password;
    });

    try {
      final users = await ref.read(adminRepositoryProvider).listUsers(password);
      final chats = await ref.read(adminRepositoryProvider).listChats(password);
      if (!mounted) return;
      setState(() {
        _users = users;
        _chats = chats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : '$e';
        _adminPassword = null;
      });
    }
  }

  Future<void> _banUser(int userId) async {
    if (_adminPassword == null) return;
    try {
      await ref.read(adminRepositoryProvider).banUser(_adminPassword!, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.adminUserBanned(userId))));
      _authenticate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  Future<void> _unbanUser(int userId) async {
    if (_adminPassword == null) return;
    try {
      await ref.read(adminRepositoryProvider).unbanUser(_adminPassword!, userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.adminUserUnbanned(userId))));
      _authenticate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  Future<void> _freezeUser(int userId, bool freeze) async {
    if (_adminPassword == null) return;
    try {
      await ref.read(adminRepositoryProvider).freezeUser(_adminPassword!, userId, freeze);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(freeze ? context.l10n.adminUserFrozen(userId) : context.l10n.adminUserUnfrozen(userId))));
      _authenticate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  Future<void> _toggleSpamBlock(int userId, bool block) async {
    if (_adminPassword == null) return;
    try {
      await ref.read(adminRepositoryProvider).spamBlock(_adminPassword!, userId, block);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block ? context.l10n.adminSpamBlockEnabled(userId) : context.l10n.adminSpamBlockDisabled(userId))));
      _authenticate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  Future<void> _banChat(int chatId, bool ban) async {
    if (_adminPassword == null) return;
    try {
      await ref.read(adminRepositoryProvider).banChat(_adminPassword!, chatId, ban);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ban ? context.l10n.adminChatBanned(chatId) : context.l10n.adminChatUnbanned(chatId))));
      _authenticate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SettingsScaffold(
      title: context.l10n.adminPanelTitle,
      onRefresh: _authenticate,
      children: [
        SettingsNavBanner(
          icon: Icons.admin_panel_settings_rounded,
          title: context.l10n.adminPanelTitle,
          subtitle: context.l10n.adminPanelSubtitle,
          iconColor: Colors.red,
        ),
        if (_adminPassword == null)
          SettingsSection(
            title: context.l10n.adminAuthentication,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.adminPasswordLabel,
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _loading ? null : _authenticate,
                  icon: _loading
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator( strokeWidth: 2))
                      : Icon(Icons.login_rounded),
                  label: Text(_loading ? context.l10n.adminConnecting : context.l10n.adminConnect),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                ),
            ],
          ),
        if (_adminPassword != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_AdminTab>(
                    segments: [
                      ButtonSegment(value: _AdminTab.users, label: Text(context.l10n.adminTabUsers(_users.length))),
                      ButtonSegment(value: _AdminTab.chats, label: Text(context.l10n.adminTabChats(_chats.length))),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (v) => setState(() => _tab = v.first),
                  ),
                ),
              ],
            ),
          ),
          if (_tab == _AdminTab.users)
            ..._users.map((user) => _UserCard(
              user: user,
              onBan: () => _banUser(user['id'] as int),
              onUnban: () => _unbanUser(user['id'] as int),
              onFreeze: (freeze) => _freezeUser(user['id'] as int, freeze),
              onSpamBlock: (block) => _toggleSpamBlock(user['id'] as int, block),
            )),
          if (_tab == _AdminTab.chats)
            ..._chats.map((chat) => _ChatCard(
              chat: chat,
              onBan: (ban) => _banChat(chat['id'] as int, ban),
            )),
          if ((_tab == _AdminTab.users && _users.isEmpty) ||
              (_tab == _AdminTab.chats && _chats.isEmpty))
            EmptyFeedWidget(
              title: context.l10n.emptyStateNoItems,
              description: context.l10n.emptyStateNoItemsDesc,
            ),
        ],
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onBan, required this.onUnban, required this.onFreeze, required this.onSpamBlock});
  final Map<String, dynamic> user;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final ValueChanged<bool> onFreeze;
  final ValueChanged<bool> onSpamBlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final id = user['id'] as int? ?? 0;
    final username = user['username'] as String? ?? '';
    final displayName = user['display_name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final isBanned = user['is_banned'] == true;
    final isFrozen = user['is_frozen'] == true;
    final spamBlock = user['spam_block'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text('$id', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text('@$username • $email', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _StatusChip(label: isBanned ? context.l10n.adminStatusBanned : context.l10n.adminStatusActive, active: !isBanned, activeColor: Colors.green, inactiveColor: Colors.red),
                  if (isFrozen) _StatusChip(label: context.l10n.adminStatusFrozen, active: false, activeColor: Colors.blue, inactiveColor: Colors.blue),
                  if (spamBlock) _StatusChip(label: context.l10n.adminStatusSpamBlock, active: false, activeColor: Colors.orange, inactiveColor: Colors.orange),
                  if (isBanned)
                    ActionChip(label: Text(context.l10n.adminActionUnban), onPressed: onUnban)
                  else
                    ActionChip(label: Text(context.l10n.adminActionBan), onPressed: onBan),
                   ActionChip(
                    label: Text(isFrozen ? context.l10n.adminActionUnfreeze : context.l10n.adminActionFreeze),
                    onPressed: () => onFreeze(!isFrozen),
                  ),
                  ActionChip(
                    label: Text(spamBlock ? context.l10n.adminActionUnblockSpam : context.l10n.adminActionSpamBlock),
                    onPressed: () => onSpamBlock(!spamBlock),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active, required this.activeColor, required this.inactiveColor});
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? activeColor : inactiveColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? activeColor : inactiveColor)),
    );
  }
}

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.chat, required this.onBan});
  final Map<String, dynamic> chat;
  final ValueChanged<bool> onBan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final id = chat['id'] as int? ?? 0;
    final name = chat['name'] as String? ?? '';
    final chatType = chat['chat_type'] as String? ?? '';
    final isBanned = chat['is_banned'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: chatType == 'channel' ? Colors.orange.withValues(alpha: 0.12) : scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(chatType == 'channel' ? Icons.campaign_rounded : Icons.group_rounded, size: 20, color: chatType == 'channel' ? Colors.orange : scheme.onPrimaryContainer),
          ),
          title: Text(name, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Text('ID: $id • $chatType', style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          trailing: ActionChip(
            label: Text(isBanned ? context.l10n.adminChatUnban : context.l10n.adminChatBan),
            onPressed: () => onBan(!isBanned),
          ),
        ),
      ),
    );
  }
}
