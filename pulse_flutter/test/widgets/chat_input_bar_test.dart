import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/l10n/app_localizations.dart';
import 'package:pulse_flutter/models/api/sticker_model.dart';
import 'package:pulse_flutter/providers/sticker_provider.dart';
import 'package:pulse_flutter/widgets/chat/chat_input_bar.dart';

class _FakeStickerSetsNotifier extends StickerSetsNotifier {
  _FakeStickerSetsNotifier(this._sets);
  final List<ApiStickerSet> _sets;

  @override
  Future<List<ApiStickerSet>> build() async => _sets;
}

Widget _wrapWidget({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  group('ChatInputBar Widget & Motion Tests', () {
    testWidgets('renders input pill and action buttons in initial empty state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: ChatInputBar(
            inputController: controller,
            inputFocusNode: focusNode,
            isAiProcessing: false,
            uploadingMedia: false,
            editingMessageId: null,
            editingOriginalText: null,
            replyToMessageId: null,
            replyPreviewText: null,
            onSend: () {},
            onCommitEdit: () {},
            onCancelEdit: () {},
            onClearReply: () {},
            onAttachMedia: () {},
            onAiPressed: () {},
            onVoiceSend: (_) {},
            hapticsEnabled: false,
          ),
        ),
      );
      await tester.pump();

      // Text input field is present
      expect(find.byType(TextField), findsOneWidget);

      // Record button is shown when empty
      expect(find.byKey(const ValueKey<String>('record_action')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('send_action')), findsNothing);

      // Action icons
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('typing text morphs record button into send button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          child: ChatInputBar(
            inputController: controller,
            inputFocusNode: focusNode,
            isAiProcessing: false,
            uploadingMedia: false,
            editingMessageId: null,
            editingOriginalText: null,
            replyToMessageId: null,
            replyPreviewText: null,
            onSend: () {},
            onCommitEdit: () {},
            onCancelEdit: () {},
            onClearReply: () {},
            onAttachMedia: () {},
            onAiPressed: () {},
            onVoiceSend: (_) {},
            hapticsEnabled: false,
          ),
        ),
      );
      await tester.pump();

      // Type text
      controller.text = 'Привет мир!';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Record button disappears, send button appears
      expect(find.byKey(const ValueKey<String>('send_action')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('record_action')), findsNothing);
    });

    testWidgets('emoji toggle button opens M3 segmented hub and backspace works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrapWidget(
          overrides: [
            stickerSetsProvider.overrideWith(
              () => _FakeStickerSetsNotifier(const <ApiStickerSet>[]),
            ),
          ],
          child: ChatInputBar(
            inputController: controller,
            inputFocusNode: focusNode,
            isAiProcessing: false,
            uploadingMedia: false,
            editingMessageId: null,
            editingOriginalText: null,
            replyToMessageId: null,
            replyPreviewText: null,
            onSend: () {},
            onCommitEdit: () {},
            onCancelEdit: () {},
            onClearReply: () {},
            onAttachMedia: () {},
            onAiPressed: () {},
            onVoiceSend: (_) {},
            hapticsEnabled: false,
          ),
        ),
      );
      await tester.pump();

      // Tap emoji toggle button
      final emojiBtn = find.byIcon(Icons.emoji_emotions_outlined);
      expect(emojiBtn, findsOneWidget);
      await tester.tap(emojiBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Hub opens with tabs
      expect(find.text('Эмодзи'), findsOneWidget);
      expect(find.text('Стикеры'), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

      // Icon changes to keyboard
      expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

      // Test emoji backspace button
      controller.text = 'Привет😊';
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();

      final backspaceBtn = find.byIcon(Icons.backspace_outlined);
      await tester.tap(backspaceBtn);
      await tester.pump();

      expect(controller.text, 'Привет');

      // Tap Stickers tab
      final stickersTab = find.text('Стикеры');
      await tester.tap(stickersTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Stickers view is now active (showing empty state from fake provider)
      expect(find.text('У вас пока нет стикерпаков'), findsOneWidget);
    });
  });
}
