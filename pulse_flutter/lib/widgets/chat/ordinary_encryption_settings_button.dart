import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/chat/inline_keyboard_view.dart';
import 'package:pulse_flutter/services/ordinary_e2ee/ordinary_e2ee_codec.dart';

bool needsOrdinaryEncryptionSettings(ApiMessage message) =>
    message.id > 0 &&
    message.isE2ee &&
    !message.isDecrypted &&
    !message.isDeleted &&
    !message.isSending &&
    message.e2eeContent != null &&
    OrdinaryCodec.recognises(message.e2eeContent!);

class OrdinaryEncryptionSettingsButton extends StatelessWidget {
  const OrdinaryEncryptionSettingsButton({this.isMine = false, super.key});
  final bool isMine;
  @override
  Widget build(BuildContext context) => InlineKeyboardView(
    isMine: isMine,
    maxLabelLines: 2,
    replyMarkup: const InlineKeyboardMarkup(
      inlineKeyboard: [
        [
          InlineKeyboardButton(
            text: 'Перейти к настройкам чатов',
            callbackData: 'local_settings',
          ),
        ],
      ],
    ),
    // This is a client-owned action, never a callback sent to a bot/server.
    onCallbackQuery: (_) => context.push('/settings/e2ee'),
  );
}
