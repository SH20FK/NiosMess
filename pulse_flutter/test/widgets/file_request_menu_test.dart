import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/widgets/message_context_menu_sheet.dart';

void main() {
  final message = ApiMessage.fromJson({
    'id': 42,
    'chat_id': 7,
    'sender_id': 8,
    'media_url': '/expired.pdf',
    'media_type': 'application/pdf',
    'media_name': 'document.pdf',
    'sent_at': '2026-10-01T00:00:00Z',
  });

  for (final (mine, secret, channel, expected) in [
    (false, false, false, true),
    (true, false, false, false),
    (false, true, false, false),
    (false, false, true, false),
  ]) {
    testWidgets('file request mine=$mine secret=$secret channel=$channel', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MessageContextMenuSheet(
                message: message,
                isMine: mine,
                isSecret: secret,
                isChannel: channel,
                amAdminOrOwner: false,
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Попросить отправить файл снова'),
        expected ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
