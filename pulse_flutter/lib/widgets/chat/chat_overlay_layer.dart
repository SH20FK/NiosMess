import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/widgets/offline_banner.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_status_card.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Presentation layer that isolates top banners (offline status, E2EE security status,
/// and pagination spinner) from the root chat screen build pass.
class ChatTopBannerLayer extends StatelessWidget {
  const ChatTopBannerLayer({
    required this.chatId,
    required this.isSecret,
    required this.loadingOlderNotifier,
    required this.onE2eeTap,
    super.key,
  });

  final int chatId;
  final bool isSecret;
  final ValueNotifier<bool> loadingOlderNotifier;
  final VoidCallback onE2eeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            final bool isOffline =
                !(ref.watch(connectivityProvider).value ?? true);
            return OfflineBanner(isOffline: isOffline);
          },
        ),
        if (isSecret)
          E2eeStatusCard(
            chatId: chatId,
            onTap: onE2eeTap,
          ),
        ValueListenableBuilder<bool>(
          valueListenable: loadingOlderNotifier,
          builder: (BuildContext context, bool isLoading, _) => AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Center(child: AppLoadingIndicator(size: 24)),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
