import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_service.dart';
import '../core/session_provider.dart';
import '../core/models/chat_item.dart';
import '../features/chats/chat_list_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/groups/create_group_screen.dart';
import '../features/onboarding/onboarding_flow_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/profile/profile_screen.dart';

class AppRouter extends ConsumerStatefulWidget {
  const AppRouter({super.key});

  @override
  ConsumerState<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<AppRouter> {
  String screen = 'main';
  ChatItem? currentChat;
  String? profileTarget;
  ProviderSubscription? _sessionSub;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _sessionSub = ref.listenManual(sessionProvider, (previous, next) {
      if (!mounted) return;
      if (next.isAuthed) {
        setState(() => screen = 'main');
      } else {
        setState(() {
          screen = 'main';
          currentChat = null;
          profileTarget = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (!session.isAuthed) {
      return const OnboardingFlowScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentChat != null) {
          setState(() => currentChat = null);
          return;
        }
        if (screen != 'main') {
          setState(() => screen = 'main');
        }
      },
      child: Navigator(
        pages: [
          MaterialPage(
            child: ChatListScreen(
              onOpenChat: (chat) {
                setState(() => currentChat = chat);
              },
              onOpenSettings: () => setState(() => screen = 'settings'),
              onOpenProfile: (username) {
                setState(() {
                  profileTarget = username;
                  screen = 'profile';
                });
              },
              onCreateGroup: () => setState(() => screen = 'createGroup'),
            ),
          ),
          if (screen == 'createGroup')
            MaterialPage(
              child: CreateGroupScreen(
                onBack: () => setState(() => screen = 'main'),
              ),
            ),
          if (screen == 'settings')
            MaterialPage(
              child: SettingsScreen(
                onBack: () => setState(() => screen = 'main'),
              ),
            ),
          if (screen == 'profile')
            MaterialPage(
              child: ProfileScreen(
                targetUsername: profileTarget,
                onBack: () => setState(() {
                  screen = 'main';
                  profileTarget = null;
                }),
              ),
            ),
          if (currentChat != null && screen == 'main')
            MaterialPage(
              child: ChatScreen(
                chatId: currentChat!.id,
                chatUsername: currentChat!.username,
                chatType: currentChat!.type,
                title: currentChat!.name,
                status: currentChat!.isOnline == true
                    ? 'в сети'
                    : currentChat!.lastSeenText ?? 'не в сети',
                badgeText: currentChat!.badgeText ?? currentChat!.badgeTitle,
                badgeIcon: currentChat!.badgeIcon,
                onBack: () => setState(() => currentChat = null),
                onOpenProfile: (username) => setState(() {
                  profileTarget = username;
                  screen = 'profile';
                }),
              ),
            ),
        ],
        onDidRemovePage: (page) {
          if (currentChat != null) setState(() => currentChat = null);
          if (screen == 'settings' || screen == 'profile' || screen == 'createGroup') {
            setState(() {
              screen = 'main';
              profileTarget = null;
            });
          }
        },
      ),
    );
  }
}

