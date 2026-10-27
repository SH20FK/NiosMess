import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/widgets/chat/ws_cached_image.dart';

void main() {
  testWidgets('untrusted media paths cannot read an arbitrary local image', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('nios-media-security-'),
    ))!;
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/private.png');
    await tester.runAsync(
      () => file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nm5kAAAAASUVORK5CYII=',
        ),
      ),
    );
    for (final path in ['local://${file.path}', file.path]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [autoDownloadAllowedProvider.overrideWithValue(false)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: WsCachedImage(
                key: ValueKey(path),
                mediaUrl: path,
                chatId: 7,
                isE2ee: false,
                errorWidget: (_, _) => const Text('unavailable'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Image), findsNothing, reason: path);
      expect(tester.takeException(), isNull);
    }
  });
}
