import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nios_admin_flutter/core/localization/l10n.dart';
import 'package:nios_admin_flutter/core/theme/admin_theme.dart';
import 'package:nios_admin_flutter/l10n/app_localizations.dart';
import 'package:nios_admin_flutter/providers/admin_session_provider.dart';
import 'package:nios_admin_flutter/screens/admin_badges_screen.dart';
import 'package:nios_admin_flutter/screens/admin_chats_screen.dart';
import 'package:nios_admin_flutter/screens/admin_dashboard_screen.dart';
import 'package:nios_admin_flutter/screens/admin_unlock_screen.dart';
import 'package:nios_admin_flutter/screens/admin_users_screen.dart';
import 'package:nios_admin_flutter/widgets/admin_shell_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) => context.l10n.appName,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AdminTheme.themed(Brightness.light),
      darkTheme: AdminTheme.themed(Brightness.dark),
      themeMode: ThemeMode.system,
      home: ref.watch(adminSessionProvider).unlocked
          ? const _AdminHome()
          : const AdminUnlockScreen(),
    );
  }
}

class _AdminHome extends StatefulWidget {
  const _AdminHome();

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      AdminDashboardScreen(onOpenSection: _openSection),
      const AdminUsersScreen(),
      const AdminChatsScreen(),
      const AdminBadgesScreen(),
    ];

    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        return AdminShellScaffold(
          currentIndex: _index,
          onSelectIndex: _openSection,
          onLogout: () => ref.read(adminSessionProvider.notifier).logout(),
          child: IndexedStack(index: _index, children: pages),
        );
      },
    );
  }

  void _openSection(int index) {
    setState(() => _index = index);
  }
}
