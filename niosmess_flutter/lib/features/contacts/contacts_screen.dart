import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/repositories/api_repository.dart';
import '../../core/session_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> with AutomaticKeepAliveClientMixin {
  final api = ApiRepository();
  final SearchController _searchController = SearchController();
  Timer? _debounce;

  bool _phoneLoading = true;
  bool _phoneDenied = false;
  List<Contact> _phoneContacts = [];

  bool _niosLoading = false;
  List<Map<String, dynamic>> _niosContacts = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadPhoneContacts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchNios();
      setState(() {});
    });
  }

  Future<void> _loadPhoneContacts() async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _phoneDenied = true;
        _phoneLoading = false;
      });
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true, withThumbnail: false);
    if (!mounted) return;
    setState(() {
      _phoneContacts = contacts;
      _phoneLoading = false;
      _phoneDenied = false;
    });
  }

  Future<void> _searchNios() async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthed) return;
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() => _niosContacts = []);
      return;
    }
    setState(() => _niosLoading = true);
    try {
      final res = await api.searchUsers(query, session.username!, session.token!);
      if (!mounted) return;
      setState(() {
        _niosContacts = res;
        _niosLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _niosLoading = false);
    }
  }

  void _openChat(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: username,
          chatUsername: username,
          chatType: 'user',
          title: username,
          status: '',
          onBack: () => Navigator.of(context).pop(),
          onOpenProfile: (u) => _openProfile(u),
        ),
      ),
    );
  }

  void _openProfile(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          targetUsername: username,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final session = ref.watch(sessionProvider);
    final query = _searchController.text.trim().toLowerCase();
    final filteredPhone = query.isEmpty
        ? _phoneContacts
        : _phoneContacts
            .where((c) => c.displayName.toLowerCase().contains(query))
            .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Контакты'),
          actions: [
            SearchAnchor(
              searchController: _searchController,
              builder: (context, controller) => IconButton(
                onPressed: () => controller.openView(),
                icon: const Icon(Icons.search),
                tooltip: 'Поиск',
              ),
              suggestionsBuilder: (context, controller) {
                final q = controller.text.trim().toLowerCase();
                if (q.isEmpty) return const [];
                final suggestions = _phoneContacts
                    .where((c) => c.displayName.toLowerCase().contains(q))
                    .take(8)
                    .toList();
                return suggestions.map((c) {
                  return ListTile(
                    leading: const Icon(Icons.contacts_outlined),
                    title: Text(c.displayName),
                    onTap: () => controller.closeView(c.displayName),
                  );
                }).toList();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'NiosMess'),
              Tab(text: 'Телефон'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            if (!session.isAuthed)
              const Center(child: Text('Войдите в аккаунт'))
            else if (_niosLoading)
              const Center(child: CircularProgressIndicator())
            else if (_niosContacts.isEmpty)
              const Center(child: Text('Введите запрос для поиска'))
            else
              ListView.separated(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                cacheExtent: 1200,
                physics: const BouncingScrollPhysics(),
                itemCount: _niosContacts.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.4),
                ),
                itemBuilder: (_, i) {
                  final item = _niosContacts[i];
                  final username = item['username']?.toString() ?? '';
                  final name = item['name']?.toString() ?? username;
                  return RepaintBoundary(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(name),
                      subtitle: Text(username),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () => _openChat(username),
                      ),
                      onTap: () => _openProfile(username),
                    ),
                  );
                },
              ),
            _buildPhoneTab(filteredPhone),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneTab(List<Contact> contacts) {
    if (_phoneLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_phoneDenied) {
      return Center(
        child: FilledButton(
          onPressed: _loadPhoneContacts,
          child: const Text('Разрешить доступ к контактам'),
        ),
      );
    }
    if (contacts.isEmpty) {
      return const Center(child: Text('Нет контактов'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      cacheExtent: 1200,
      physics: const BouncingScrollPhysics(),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        endIndent: 16,
        color:
            Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
      ),
      itemBuilder: (_, i) {
        final c = contacts[i];
        final subtitle = c.phones.isNotEmpty
            ? c.phones.first.number
            : c.emails.isNotEmpty
                ? c.emails.first.address
                : '—';
        return RepaintBoundary(
          child: ListTile(
            leading: const Icon(Icons.contacts_outlined),
            title: Text(c.displayName),
            subtitle: Text(subtitle),
            trailing: IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                final text = 'Присоединяйся к NiosMess! Контакт: ${c.displayName}';
                Share.share(text);
              },
            ),
          ),
        );
      },
    );
  }
  @override
  bool get wantKeepAlive => true;
}
