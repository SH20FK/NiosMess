import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_service.dart';
import '../core/session_provider.dart';
import '../features/chats/chat_list_screen.dart';
import '../features/calls/calls_screen.dart';
import '../features/contacts/contacts_screen.dart';
import '../features/onboarding/onboarding_flow_screen.dart';
import '../features/settings/settings_main_screen.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );
  ProviderSubscription? _sessionSub;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _sessionSub = ref.listenManual(sessionProvider, (previous, next) {
      if (!mounted) return;
      if (!next.isAuthed) {
        _resetNavigation();
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.close();
    super.dispose();
  }

  void _resetNavigation() {
    for (final key in _navigatorKeys) {
      key.currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _currentIndex = 0);
  }

  Future<bool> _handleBack() async {
    final navigator = _navigatorKeys[_currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    return true;
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    if (_currentIndex == 3) {
      _navigatorKeys[3].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() => _currentIndex = index);
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (!session.isAuthed) {
      return const OnboardingFlowScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const ChatListScreen()),
            _buildTabNavigator(1, const CallsScreen()),
            _buildTabNavigator(2, const ContactsScreen()),
            _buildTabNavigator(3, const SettingsMainScreen()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Чаты',
            ),
            NavigationDestination(
              icon: Icon(Icons.phone_outlined),
              selectedIcon: Icon(Icons.phone),
              label: 'Звонки',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Контакты',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
