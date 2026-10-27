import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/chat_summary_model.dart';
import 'package:pulse_flutter/models/api/message_model.dart';
import 'package:pulse_flutter/models/live_location.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/backend_chat_provider.dart';
import 'package:pulse_flutter/providers/live_location_provider.dart';
import 'package:pulse_flutter/widgets/chat/file_request_action.dart';
import 'package:pulse_flutter/widgets/chat/live_location_card.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 2,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
}

void main() {
  for (final (secret, own, missing) in [
    (false, false, true),
    (true, false, true),
    (false, true, true),
    (false, false, false),
  ]) {
    testWidgets('request button secret=$secret own=$own missing=$missing', (
      tester,
    ) async {
      final message = ApiMessage.fromJson({
        'id': 42,
        'chat_id': 7,
        'sender_id': own ? 2 : 1,
        'media_url': 'https://ni-os.ru/api/media/test.pdf',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            chatByIdProvider(7).overrideWith(
              (ref) => ApiChatSummary(
                id: 7,
                chatType: 'direct',
                name: 'Fixture',
                unreadCount: 0,
                membersCount: 2,
                isSecret: secret,
              ),
            ),
            unavailableChatMediaProvider.overrideWith(
              (ref) => Stream.value(missing ? {'test.pdf'} : <String>{}),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: FileRequestAction(message: message)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Запросить файл'),
        !secret && !own && missing ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets(
      'location card fits a small screen and large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final time = DateTime.now().toUtc();
        final location = LiveLocation(
          id: '0b0c0387-e086-4b57-8880-8c38ec514242',
          latitude: 59.437,
          longitude: 24.7536,
          accuracy: 10,
          createdAt: time,
          updatedAt: time,
          expiresAt: time.add(const Duration(minutes: 15)),
          active: true,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              liveLocationProvider.overrideWith((ref) => null),
              liveLocationChangesProvider.overrideWith(
                (ref) => Stream.value(0),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(
                  ctx,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LiveLocationCard(
                    location: location,
                    chatId: 7,
                    foreground: brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Открыть на карте'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
