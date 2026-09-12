import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/widgets/create_chat_wizard_view.dart';

class CreateChatScreen extends ConsumerWidget {
  const CreateChatScreen({this.initialType, super.key});

  final String? initialType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isWide = MediaQuery.sizeOf(context).width >= 720;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    void handleClose() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/main/chats');
      }
    }

    void handleChatCreated(int chatId) {
      context.replace('/chat/$chatId');
    }

    if (isWide) {
      // Desktop / Web: Centered M3 Expressive Card Window
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        body: Stack(
          children: <Widget>[
            // Soft ambient depth gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.2,
                    colors: <Color>[
                      scheme.primary.withValues(alpha: 0.07),
                      scheme.surfaceContainerLowest,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.20),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.22),
                          blurRadius: 36,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: CreateChatWizardView(
                        initialType: initialType,
                        isDialog: true,
                        onClose: handleClose,
                        onChatCreated: handleChatCreated,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile: Full screen layout with safe area
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: CreateChatWizardView(
          initialType: initialType,
          isDialog: false,
          onClose: handleClose,
          onChatCreated: handleChatCreated,
        ),
      ),
    );
  }
}
