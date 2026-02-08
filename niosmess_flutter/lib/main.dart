import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: NiosMessApp()));
}

class NiosMessApp extends StatelessWidget {
  const NiosMessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = ref.watch(themeProvider);
        return MaterialApp(
          title: 'NiosMess',
          theme: buildNiosTheme(theme.preset),
          home: const AppRouter(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
