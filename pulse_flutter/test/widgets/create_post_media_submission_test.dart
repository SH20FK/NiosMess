import 'package:pulse_flutter/screens/niosgram_screen.dart';
import 'package:pulse_flutter/providers/notifications_provider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/utils/cancellation_token.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/models/api/upload_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/niosgram_provider.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/repositories/chat_repository.dart';
import 'package:pulse_flutter/screens/create_post_screen.dart';

final class _File extends PlatformFile {
  _File(this.name, this.bytes, {this.declaredLength});
  @override
  final String name;
  final Uint8List bytes;
  final int? declaredLength;
  @override
  Uri get uri => Uri.parse('memory:fixture');
  @override
  get xFile => throw UnimplementedError();
  @override
  Future<int> length() async => declaredLength ?? bytes.length;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _Picker extends FilePickerPlatform {
  Future<List<PlatformFile>> Function() files = () async => [];
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) => files();
}

class _Auth extends AuthNotifier {
  bool loggingOut = false;
  @override
  bool get isLoggingOut => loggingOut;
  @override
  AuthState build() => const AuthState.initial().copyWith(
    hydrated: true,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'fixture',
      displayName: 'Test',
    ),
  );
  void switchAccount() => state = state.copyWith(
    session: const AuthSession(
      accessToken: 'other',
      userId: 2,
      username: 'other',
      displayName: 'Other',
    ),
  );
}

class _Settings extends UiSettingsNotifier {
  @override
  UiSettingsState build() => const UiSettingsState.defaults().copyWith(
    haptics: false,
    soundEffects: false,
  );
}

class _Notifications extends NotificationsNotifier {
  @override
  NotificationsState build() => const NotificationsState(unreadCount: 0);
}

class _Feed extends NiosgramNotifier {
  Completer<void>? pending;
  String? submitted;
  int submissions = 0;
  List<dynamic>? uploads;
  @override
  Future<NiosgramState> build() async => const NiosgramState();
  @override
  Future<void> createPost(
    String text, {
    dynamic uploadId,
    List<dynamic>? uploadIds,
    List<String>? aiTags,
    Map<String, dynamic>? poll,
  }) async {
    submissions++;
    submitted = text;
    uploads = uploadIds;
    await pending?.future;
  }
}

class _Repository extends ChatRepository {
  _Repository(super.ref);
  final sent = <Uint8List>[], names = <String>[];
  Completer<String>? pending;
  CancellationToken? cancellation;
  @override
  Future<String> uploadStreamInChunks({
    Uint8List? bytes,
    String? filePath,
    required String filename,
    required String mediaSubtype,
    required int fileSize,
    required void Function(int, int) onProgress,
    void Function(UploadStage)? onStageChanged,
    CancellationToken? cancellationToken,
    String? localId,
  }) async {
    expect(fileSize, bytes!.length);
    expect(bytes, isNotEmpty);
    expect(mediaSubtype, 'media');
    sent.add(Uint8List.fromList(bytes));
    names.add(filename);
    cancellation = cancellationToken;
    return pending?.future ?? 'fixture-upload';
  }
}

void main() {
  group('CreatePostScreen media submission', () {
    late _Picker picker;
    late FilePickerPlatform previous;
    late _Feed feed;
    late _Repository repository;
    late ProviderContainer container;
    setUp(() {
      previous = FilePickerPlatform.instance;
      picker = _Picker();
      FilePickerPlatform.instance = picker;
    });
    tearDown(() {
      FilePickerPlatform.instance = previous;
    });
    Future<void> open(WidgetTester tester, {bool quick = false}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_Auth.new),
            uiSettingsProvider.overrideWith(_Settings.new),
            niosgramProvider.overrideWith(() => feed = _Feed()),
            notificationsProvider.overrideWith(_Notifications.new),
            chatRepositoryProvider.overrideWith(
              (ref) => repository = _Repository(ref),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => quick
                          ? const NiosgramScreen()
                          : const CreatePostScreen(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      container = ProviderScope.containerOf(tester.element(find.text('Open')));
      // Instantiate the same real provider boundary that the screen uses.
      await container.read(niosgramProvider.future);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    Future<void> pick(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined).first);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'video preview placeholder never replaces actual file bytes on Publish',
      (tester) async {
        final bytes = Uint8List.fromList([
          0,
          0,
          0,
          20,
          102,
          116,
          121,
          112,
          105,
          115,
          111,
          109,
          0,
          0,
          0,
          0,
          105,
          115,
          111,
          109,
        ]);
        picker.files = () async => [_File('clip.mp4', bytes)];
        await open(tester);
        await pick(tester);
        await tester.tap(find.text('Publish').first);
        await tester.pumpAndSettle();
        expect(repository.sent.single, orderedEquals(bytes));
        expect(repository.names, ['clip.mp4']);
        expect(feed.submissions, 1);
        expect(feed.uploads, ['fixture-upload']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('picker rejects a file larger than the real upload cap', (
      tester,
    ) async {
      picker.files = () async => [
        _File(
          'clip.mp4',
          Uint8List.fromList([1, 2, 3]),
          declaredLength: 11 * 1024 * 1024,
        ),
      ];
      await open(tester);
      await pick(tester);
      final sizeError = tester
          .element(find.byType(CreatePostScreen))
          .l10n
          .postFileTooLarge;
      expect(find.text(sizeError), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Text without rejected file',
      );
      await tester.tap(find.text('Publish').first);
      await tester.pumpAndSettle();
      expect(feed.submissions, 1);
      expect(feed.uploads, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('closing during picker ignores its late result', (
      tester,
    ) async {
      final pending = Completer<List<PlatformFile>>();
      picker.files = () => pending.future;
      await open(tester);
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined).first);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete([
        _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
      ]);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(feed.submissions, 0);
    });
    testWidgets(
      'disposal cancels pending upload and cannot publish a late success',
      (tester) async {
        picker.files = () async => [
          _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
        ];
        await open(tester);
        await pick(tester);
        repository = container.read(chatRepositoryProvider) as _Repository;
        final pending = Completer<String>();
        repository.pending = pending;
        await tester.tap(find.text('Publish').first);
        await tester.pump();
        await tester.pump();
        final token = repository.cancellation;
        expect(token, isNotNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(token!.isCancelled, isTrue);
        pending.complete('late-upload');
        await tester.pump();
        await tester.pump();
        expect(feed.submissions, 0);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'account switch during upload cannot publish into the new session',
      (tester) async {
        picker.files = () async => [
          _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
        ];
        await open(tester);
        await pick(tester);
        repository = container.read(chatRepositoryProvider) as _Repository;
        final pending = Completer<String>();
        repository.pending = pending;
        await tester.tap(find.text('Publish').first);
        await tester.pump();
        await tester.pump();
        (container.read(authProvider.notifier) as _Auth).switchAccount();
        pending.complete('old-account-upload');
        await tester.pumpAndSettle();
        expect(feed.submissions, 0);
        expect(find.byType(CreatePostScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'full composer preserves text changed while publication is pending',
      (tester) async {
        await open(tester);
        final pending = Completer<void>();
        feed.pending = pending;
        await tester.enterText(find.byType(TextField), 'Original fixture');
        await tester.tap(find.text('Publish').first);
        await tester.pump();
        await tester.enterText(
          find.byType(TextField),
          'New draft during publication',
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(feed.submitted, 'Original fixture');
        expect(find.byType(CreatePostScreen), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'New draft during publication',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    for (final quick in [false, true]) {
      testWidgets(
        'picker from an old account cannot attach files to the next draft: quick=$quick',
        (tester) async {
          await open(tester, quick: quick);
          if (quick) {
            await tester.tap(find.byKey(const ValueKey('collapsed_quick_bar')));
            await tester.pumpAndSettle();
          }
          final pending = Completer<List<PlatformFile>>();
          picker.files = () => pending.future;
          await tester.tap(
            find.byIcon(Icons.add_photo_alternate_outlined).first,
          );
          await tester.pump();
          (container.read(authProvider.notifier) as _Auth).switchAccount();
          pending.complete([
            _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
          ]);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'New account fixture');
          await tester.tap(find.text('Publish').first);
          await tester.pumpAndSettle();
          expect(feed.submissions, 1);
          expect(feed.uploads, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
      testWidgets(
        'confirmed logout during upload cannot publish or erase the draft: quick=$quick',
        (tester) async {
          picker.files = () async => [
            _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
          ];
          await open(tester, quick: quick);
          if (quick) {
            await tester.tap(find.byKey(const ValueKey('collapsed_quick_bar')));
            await tester.pumpAndSettle();
          }
          await tester.enterText(find.byType(TextField), 'Pending fixture');
          await pick(tester);
          repository = container.read(chatRepositoryProvider) as _Repository;
          final pending = Completer<String>();
          repository.pending = pending;
          await tester.tap(find.text('Publish').first);
          await tester.pump();
          await tester.pump();
          expect(repository.sent, hasLength(1));
          (container.read(authProvider.notifier) as _Auth).loggingOut = true;
          pending.complete('late-logout-upload');
          await tester.pumpAndSettle();
          expect(feed.submissions, 0);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'Pending fixture',
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets(
      'quick composer preserves edits made while publication is pending',
      (tester) async {
        await open(tester, quick: true);
        await tester.tap(find.byKey(const ValueKey('collapsed_quick_bar')));
        await tester.pumpAndSettle();
        final pending = Completer<void>();
        feed.pending = pending;
        await tester.enterText(find.byType(TextField), 'Original fixture');
        await tester.tap(find.text('Publish').first);
        await tester.pump();
        await tester.enterText(
          find.byType(TextField),
          'New draft during publication',
        );
        pending.complete();
        await tester.pumpAndSettle();
        expect(feed.submitted, 'Original fixture');
        expect(
          find.byKey(const ValueKey('expanded_quick_composer')),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'New draft during publication',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets('canceling quick draft ignores the pending picker result', (
      tester,
    ) async {
      await open(tester, quick: true);
      await tester.tap(find.byKey(const ValueKey('collapsed_quick_bar')));
      await tester.pumpAndSettle();
      final pending = Completer<List<PlatformFile>>();
      picker.files = () => pending.future;
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined).first);
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel').first);
      await tester.pumpAndSettle();
      pending.complete([
        _File('clip.mp4', Uint8List.fromList([1, 2, 3])),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collapsed_quick_bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
