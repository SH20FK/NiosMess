import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pulse_flutter/core/network/ws_media_fetcher.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';

final unavailableChatMediaProvider = StreamProvider<Set<String>>((ref) async* {
  final account = ref.watch(
    authProvider.select(
      (state) => (state.session?.userId, state.session?.accessToken),
    ),
  );
  if (account.$1 == null) {
    yield const {};
    return;
  }
  final missing = <String>{};
  yield Set<String>.of(missing);
  await for (final (path, available) in WsMediaFetcher.availabilityChanges) {
    if (available) {
      missing.remove(path);
    } else {
      missing.add(path);
    }
    while (missing.length > 500) {
      missing.remove(missing.first);
    }
    yield Set<String>.of(missing);
  }
});

Future<void> requestChatFile(WidgetRef ref, ApiMessage message) async {
  final account = ref.read(authProvider).session;
  final chat = ref.read(chatByIdProvider(message.chatId));
  if (account == null ||
      chat == null ||
      chat.isSecret ||
      chat.isBotChat ||
      (chat.chatType != 'direct' && chat.chatType != 'group') ||
      message.isDeleted ||
      !message.hasMedia ||
      message.id <= 0 ||
      message.senderId == account.userId) {
    throw StateError('Нельзя запросить это вложение');
  }
  // The remote peer receives a reply to this exact message, never a local path.
  await ref
      .read(chatMessagesProvider(message.chatId).notifier)
      .sendAcknowledged(
        'Пожалуйста, отправь этот файл ещё раз, если он у тебя сохранился.',
        replyToId: message.id,
        requireE2ee: message.isE2ee,
      );
}

class FileRequestAction extends ConsumerStatefulWidget {
  const FileRequestAction({required this.message, super.key});
  final ApiMessage message;
  @override
  ConsumerState<FileRequestAction> createState() => _FileRequestActionState();
}

class _FileRequestActionState extends ConsumerState<FileRequestAction> {
  bool _sending = false, _sent = false;
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final missing =
        ref.watch(unavailableChatMediaProvider).value ?? const <String>{};
    final own = ref.watch(
      authProvider.select((state) => state.session?.userId),
    );
    final chat = ref.watch(chatByIdProvider(message.chatId));
    if (own == null ||
        own == message.senderId ||
        chat == null ||
        chat.isSecret ||
        chat.isBotChat ||
        message.id <= 0 ||
        !missing.contains(WsMediaFetcher.mediaIdentity(message.mediaUrl ?? ''))) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: _sending || _sent
          ? null
          : () async {
              setState(() => _sending = true);
              try {
                await requestChatFile(ref, message);
                if (mounted) setState(() => _sent = true);
              } catch (e) {
                if (context.mounted) AppToast.showError(context, e);
              } finally {
                if (mounted) setState(() => _sending = false);
              }
            },
      icon: SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 3v6h-6"/></svg>',
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      ),
      label: Text(
        _sent
            ? 'Запрос отправлен'
            : _sending
            ? 'Отправляю…'
            : 'Запросить файл',
      ),
    );
  }
}
