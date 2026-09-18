import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/services/double_ratchet_service.dart';
import 'package:pulse_flutter/services/e2ee_service.dart';
import 'package:pulse_flutter/widgets/chat/e2ee_verification_sheet.dart';

class _FakeE2eeService extends E2eeService {
  _FakeE2eeService() : super();

  @override
  Future<E2eeSessionInfo> getSessionInfo(int chatId) async {
    final dr = DoubleRatchetService();
    final secretKey = SecretKey(List<int>.generate(32, (i) => i + 1));
    final words = await dr.getVisualWords(secretKey);

    return E2eeSessionInfo(
      status: E2eeSessionStatus.secured,
      isVerified: false,
      ourFingerprint: '1122 3344 5566 7788',
      peerFingerprint: '99AA BBCC DDEE FF00',
      visualWords: words,
    );
  }
}

void main() {
  group('Milestone 5: 12 Colored Safety Words (E2EE v1)', () {
    late DoubleRatchetService dr;

    setUp(() {
      dr = DoubleRatchetService();
    });

    test('getVisualWords returns exactly 12 colored words', () async {
      final key = SecretKey(List<int>.generate(32, (i) => i * 3));
      final words = await dr.getVisualWords(key);

      expect(words.length, 12);
      const allowedColors = {
        'red',
        'green',
        'yellow',
        'blue',
        'purple',
        'cyan',
        'orange',
        'teal',
      };

      for (final item in words) {
        expect(item.word, isNotEmpty);
        expect(allowedColors, contains(item.color));
      }
    });

    test('getVisualWords is deterministic for identical keys', () async {
      final key1 = SecretKey(List<int>.generate(32, (i) => 42));
      final key2 = SecretKey(List<int>.generate(32, (i) => 42));

      final words1 = await dr.getVisualWords(key1);
      final words2 = await dr.getVisualWords(key2);

      expect(words1.length, 12);
      expect(words2.length, 12);

      for (int i = 0; i < 12; i++) {
        expect(words1[i].word, words2[i].word);
        expect(words1[i].color, words2[i].color);
      }
    });

    test('getVisualWords differs for distinct keys', () async {
      final keyA = SecretKey(List<int>.generate(32, (i) => i));
      final keyB = SecretKey(List<int>.generate(32, (i) => 255 - i));

      final wordsA = await dr.getVisualWords(keyA);
      final wordsB = await dr.getVisualWords(keyB);

      final wordsListA = wordsA.map((w) => w.word).toList();
      final wordsListB = wordsB.map((w) => w.word).toList();

      expect(wordsListA, isNot(equals(wordsListB)));
    });
  });

  group('Milestone 5: E2eeVerificationSheet Widget', () {
    testWidgets('displays E2EE v1 badge and all 12 words with numbers',
        (WidgetTester tester) async {
      final fakeE2ee = _FakeE2eeService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            e2eeServiceProvider.overrideWithValue(fakeE2ee),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: E2eeVerificationSheet(chatId: 42),
            ),
          ),
        ),
      );

      // Settle future builder
      await tester.pumpAndSettle();

      // Check Double Ratchet v2 badge
      expect(find.text('Double Ratchet v2'), findsOneWidget);

      // Check 12 word numbered prefixes (#1 through #12)
      for (int i = 1; i <= 12; i++) {
        expect(find.text('#$i'), findsOneWidget);
      }
    });
  });
}
