import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_io/io.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_dialogs.dart';
import 'package:pulse_flutter/core/modal/app_modal.dart';
import 'package:pulse_flutter/core/modal/m3_modal_surface.dart';
import 'package:pulse_flutter/widgets/profile/working_hours_planner_dialog.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Onest': 'assets/fonts/onest/Onest-Variable.ttf',
      'GolosText': 'assets/fonts/golos_text/GolosText-Variable.ttf',
      'BricolageGrotesque':
          'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  Future<void> mount(
    WidgetTester tester,
    WidgetBuilder open, {
    double width = 390,
    double height = 720,
    double scale = 1,
    String locale = 'ru',
    Brightness brightness = Brightness.dark,
    double keyboard = 0,
    bool reduced = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themed(
          const VisualThemeSettings(
            seedColor: Color(0xff6750a4),
            themeMode: ThemeMode.system,
            useSystemDynamic: false,
            predictiveBackEnabled: true,
          ),
          brightness,
        ),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(body: Builder(builder: open)),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    for (final locale in ['ru', 'en']) {
      for (final width in [320.0, 390.0]) {
        for (final scenario in [
          'leave',
          'delete',
          'secret',
          'storage',
          'session',
        ]) {
          testWidgets(
            '$scenario confirmation fits $width $locale $brightness at 200%',
            (tester) async {
              await mount(
                tester,
                (context) => TextButton(
                  child: const Text('open'),
                  onPressed: () {
                    final l = context.l10n;
                    showAppConfirmDialog(
                      context: context,
                      title: switch (scenario) {
                        'leave' => l.groupManageLeaveTitle,
                        'storage' =>
                          l.settingsStorageClearTemporaryConfirmTitle,
                        'session' => l.modalSessionTitle,
                        _ => l.chatDelete,
                      },
                      subtitle: switch (scenario) {
                        'leave' => l.groupManageLeaveBody,
                        'secret' => l.secretDeleteWarning,
                        'storage' => l.settingsStorageClearTemporaryConfirmBody,
                        'session' => l.modalSessionBody('NiosMess Desktop'),
                        _ => l.modalDeleteChatBody,
                      },
                      confirmLabel: scenario == 'leave'
                          ? l.groupManageLeave
                          : scenario == 'session'
                          ? l.modalSessionConfirm
                          : l.commonDelete,
                      cancelLabel: l.commonCancel,
                      destructive: true,
                      icon: Icons.logout_rounded,
                    );
                  },
                ),
                width: width,
                scale: 2,
                locale: locale,
                brightness: brightness,
              );
              await tester.tap(find.text('open'));
              await tester.pumpAndSettle();
              expect(find.byType(BottomSheet), findsNothing);
              final surface = tester.widget<M3ModalSurface>(
                find.byType(M3ModalSurface),
              );
              expect(surface.tone, ModalTone.high);
              final confirm = tester.getRect(find.byType(FilledButton));
              final cancel = tester.getRect(find.byType(TextButton).last);
              expect(confirm.overlaps(cancel), isFalse);
              expect(confirm.bottom, lessThanOrEqualTo(720));
              expect(cancel.bottom, lessThanOrEqualTo(720));
              expect(confirm.left, greaterThanOrEqualTo(0));
              expect(confirm.right, lessThanOrEqualTo(width));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  for (final width in [839.0, 840.0]) {
    testWidgets('confirmation breakpoint $width and reduced motion', (
      tester,
    ) async {
      await mount(
        tester,
        (context) => TextButton(
          child: const Text('open'),
          onPressed: () => AppModal.confirm(
            context: context,
            title: context.l10n.chatDelete,
            message: context.l10n.modalDeleteChatBody,
          ),
        ),
        width: width,
        reduced: true,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<M3ModalSurface>(find.byType(M3ModalSurface)).variant,
        ModalVariant.dialog,
      );
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final facade in ['nullable', 'boolean']) {
    for (final action in [
      'confirm',
      'cancel',
      'back',
      'barrier',
      'swipe',
      'double',
    ]) {
      testWidgets('$facade result and business action for $action', (
        tester,
      ) async {
        Object? result = 'pending';
        int operations = 0;
        await mount(
          tester,
          (context) => TextButton(
            child: const Text('open'),
            onPressed: () async {
              final confirmed = facade == 'boolean'
                  ? await AppModal.confirm(
                      context: context,
                      title: context.l10n.chatDelete,
                      message: context.l10n.modalDeleteChatBody,
                      confirmLabel: context.l10n.commonDelete,
                      cancelLabel: context.l10n.commonCancel,
                      destructive: true,
                    )
                  : await showAppConfirmDialog(
                      context: context,
                      title: context.l10n.chatDelete,
                      subtitle: context.l10n.modalDeleteChatBody,
                      confirmLabel: context.l10n.commonDelete,
                      cancelLabel: context.l10n.commonCancel,
                      destructive: true,
                    );
              result = confirmed;
              if (confirmed == true) operations++;
            },
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (action == 'confirm' || action == 'double') {
          final point = tester.getCenter(find.byType(FilledButton));
          await tester.tapAt(point);
          if (action == 'double') await tester.tapAt(point);
        } else if (action == 'cancel') {
          await tester.tap(find.text('Отмена'));
        } else if (action == 'back') {
          await tester.binding.handlePopRoute();
        } else if (action == 'barrier') {
          await tester.tapAt(const Offset(10, 10));
        } else {
          await tester.drag(find.byType(M3ModalSurface), const Offset(0, 100));
          await tester.pumpAndSettle();
          expect(result, 'pending');
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(operations, action == 'confirm' || action == 'double' ? 1 : 0);
        expect(
          result,
          action == 'confirm' || action == 'double'
              ? true
              : action == 'cancel' || facade == 'boolean'
              ? false
              : null,
        );
        expect(find.byType(M3ModalSurface), findsNothing);
        expect(find.text('open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'form stays centered with keyboard and long text while actions remain visible',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await mount(
        tester,
        (context) => TextButton(
          child: const Text('open'),
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (ctx) => AppDialog(
              title: ctx.l10n.profileDisplayName,
              subtitle: List.filled(
                6,
                ctx.l10n.appearanceSelectHexPrompt,
              ).join(' '),
              actions: [
                AppDialogAction(
                  label: ctx.l10n.commonCancel,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                AppDialogAction(
                  label: ctx.l10n.commonSave,
                  isPrimary: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
              child: AppDialogFormContent(
                fields: [
                  AppDialogField(
                    controller: controller,
                    label: ctx.l10n.profileDisplayName,
                  ),
                ],
              ),
            ),
          ),
        ),
        width: 320,
        scale: 2,
        keyboard: 240,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester.getRect(find.byType(FilledButton)).bottom,
        lessThanOrEqualTo(480),
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Nios');
      await tester.pump();
      expect(controller.text, 'Nios');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('working hours editor has a single shared surface on desktop', (
    tester,
  ) async {
    await mount(
      tester,
      (context) => TextButton(
        child: const Text('open'),
        onPressed: () => WorkingHoursPlannerDialog.show(context),
      ),
      width: 1000,
      height: 900,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(M3ModalSurface), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('modal snapshots $brightness', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      String scenario = 'leave';
      final controller = TextEditingController(text: 'NiosMess');
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themed(
              const VisualThemeSettings(
                seedColor: Color(0xff6750a4),
                themeMode: ThemeMode.system,
                useSystemDynamic: false,
                predictiveBackEnabled: true,
              ),
              brightness,
            ),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    final l = context.l10n;
                    if (scenario == 'form') {
                      await showAppDialog<void>(
                        context: context,
                        builder: (ctx) => AppDialog(
                          title: l.profileDisplayName,
                          actions: [
                            AppDialogAction(
                              label: l.commonSave,
                              isPrimary: true,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                          child: AppDialogFormContent(
                            fields: [
                              AppDialogField(
                                controller: controller,
                                label: l.profileDisplayName,
                              ),
                            ],
                          ),
                        ),
                      );
                      return;
                    }
                    await showAppConfirmDialog(
                      context: context,
                      title: switch (scenario) {
                        'leave' => l.groupManageLeaveTitle,
                        'storage' =>
                          l.settingsStorageClearTemporaryConfirmTitle,
                        'session' => l.modalSessionTitle,
                        _ => l.chatDelete,
                      },
                      subtitle: switch (scenario) {
                        'leave' => l.groupManageLeaveBody,
                        'secret' => l.secretDeleteWarning,
                        'storage' => l.settingsStorageClearTemporaryConfirmBody,
                        'session' => l.modalSessionBody('NiosMess Desktop'),
                        _ => l.modalDeleteChatBody,
                      },
                      confirmLabel: scenario == 'leave'
                          ? l.groupManageLeave
                          : scenario == 'session'
                          ? l.modalSessionConfirm
                          : l.commonDelete,
                      cancelLabel: l.commonCancel,
                      destructive: true,
                      icon: scenario == 'leave' || scenario == 'session'
                          ? Icons.logout_rounded
                          : Icons.delete_outline_rounded,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      for (final item in [
        'leave',
        'delete',
        'secret',
        'storage',
        'session',
        'form',
      ]) {
        scenario = item;
        if (item == 'form') {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        }
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final output = Platform.environment['NIOS_MODAL_CAPTURE_DIR'];
        if (output != null) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/${item}_${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
        Navigator.of(
          tester.element(
            find.byType(AppDialog).evaluate().isNotEmpty
                ? find.byType(AppDialog).first
                : find.byType(M3ModalSurface).first,
          ),
        ).pop();
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      }
    });
  }
}
