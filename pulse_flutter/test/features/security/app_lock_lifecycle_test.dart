import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/platform/client_capabilities.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/services/biometric_service.dart';
import 'package:pulse_flutter/features/security/application/app_lock_controller.dart';
import 'package:pulse_flutter/features/security/domain/app_lock_policy.dart';
import 'package:pulse_flutter/features/security/presentation/app_lock_gate.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.initial().copyWith(
    hydrated: true,
    session: const AuthSession(
      accessToken: 'fixture',
      userId: 1,
      username: 'fixture',
      displayName: 'Fixture',
    ),
  );
}

class _Biometrics extends Fake implements BiometricService {
  Future<bool>? capability;
  Future<bool> Function()? authentication;
  int enableWrites = 0;
  @override
  Future<bool> get canCheckBiometrics => capability ?? Future.value(true);
  @override
  Future<bool> authenticate({String reason = 'fixture'}) =>
      authentication?.call() ?? Future.value(false);
  @override
  Future<void> setBiometricEnabled(bool value) async {
    enableWrites++;
  }
}

class _Storage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{
    'app_lock.enabled': 'true',
    'app_lock.timeout': 'after30Seconds',
  };
  int reads = 0, writes = 0;
  Future<String?>? enabledRead;
  @override
  dynamic noSuchMethod(Invocation call) {
    final key = call.namedArguments[#key] as String;
    if (call.memberName == #read) {
      reads++;
      if (key == 'app_lock.enabled' && enabledRead != null) return enabledRead!;
      return Future<String?>.value(values[key]);
    }
    if (call.memberName == #write) {
      writes++;
      values[key] = call.namedArguments[#value] as String;
      return Future<void>.value();
    }
    return super.noSuchMethod(call);
  }
}

void main() {
  test(
    'browser provider and all actions never initialize native services',
    () async {
      final container = ProviderContainer(
        overrides: [
          clientCapabilitiesProvider.overrideWithValue(
            const ClientCapabilities(
              isWeb: true,
              platform: TargetPlatform.windows,
            ),
          ),
          biometricServiceProvider.overrideWith(
            (_) => throw StateError('native biometric touched'),
          ),
          appLockStorageProvider.overrideWith(
            (_) => throw StateError('native storage touched'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(appLockProvider.notifier);
      expect(container.read(appLockProvider).isSupported, isFalse);
      expect(await notifier.setEnabled(true), isFalse);
      expect(await notifier.authenticateAndUnlock(), isFalse);
      await notifier.setTimeout(AppLockTimeout.after1Minute);
      await notifier.retryInit();
      notifier.onAppBackgrounded();
      notifier.onAppResumed();
      notifier.lockManually();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLockProvider).isEnabled, isFalse);
      expect(container.read(appLockProvider).isLocked, isFalse);
    },
  );

  test(
    'native saved lock stays locked on denial and ignores auth after disposal',
    () async {
      final biometric = _Biometrics();
      final storage = _Storage();
      final container = ProviderContainer(
        overrides: [
          clientCapabilitiesProvider.overrideWithValue(
            const ClientCapabilities(
              isWeb: false,
              platform: TargetPlatform.android,
            ),
          ),
          biometricServiceProvider.overrideWithValue(biometric),
          appLockStorageProvider.overrideWithValue(storage),
        ],
      );
      final notifier = container.read(appLockProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(appLockProvider).isEnabled, isTrue);
      expect(container.read(appLockProvider).isLocked, isTrue);
      expect(
        container.read(appLockProvider).timeout,
        AppLockTimeout.after30Seconds,
      );
      expect(await notifier.authenticateAndUnlock(), isFalse);
      expect(container.read(appLockProvider).isLocked, isTrue);
      final pending = Completer<bool>();
      biometric.authentication = () => pending.future;
      final unlocking = notifier.authenticateAndUnlock();
      expect(container.read(appLockProvider).isAuthenticating, isTrue);
      container.dispose();
      pending.complete(true);
      expect(await unlocking, isFalse);
      expect(storage.writes, 0);
      expect(biometric.enableWrites, 0);
    },
  );

  test(
    'disposed initialization stops before touching persistent settings',
    () async {
      final pending = Completer<bool>();
      final biometric = _Biometrics()..capability = pending.future;
      final storage = _Storage();
      final container = ProviderContainer(
        overrides: [
          clientCapabilitiesProvider.overrideWithValue(
            const ClientCapabilities(
              isWeb: false,
              platform: TargetPlatform.android,
            ),
          ),
          biometricServiceProvider.overrideWithValue(biometric),
          appLockStorageProvider.overrideWithValue(storage),
        ],
      );
      container.read(appLockProvider);
      container.dispose();
      pending.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(storage.reads, 0);
      expect(storage.writes, 0);
      expect(biometric.enableWrites, 0);
    },
  );

  for (final language in ['en', 'ru']) {
    testWidgets(
      'authenticated content stays hidden during storage failure and retry at 320dp/200%: $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<String?>();
        final biometric = _Biometrics();
        final storage = _Storage()..enabledRead = pending.future;
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(_Auth.new),
                clientCapabilitiesProvider.overrideWithValue(
                  const ClientCapabilities(
                    isWeb: false,
                    platform: TargetPlatform.android,
                  ),
                ),
                biometricServiceProvider.overrideWithValue(biometric),
                appLockStorageProvider.overrideWithValue(storage),
              ],
              child: MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: const AppLockGate(
                  child: Scaffold(body: Text('Private fixture')),
                ),
              ),
            ),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(AppLockGate)),
          );
          await tester.pump();
          expect(container.read(appLockProvider).isInitializing, isTrue);
          expect(find.byType(AppLoadingIndicator), findsOneWidget);
          expect(find.text('Private fixture'), findsNothing);
          expect(find.bySemanticsLabel('Private fixture'), findsNothing);
          pending.completeError(
            StateError('fixture protected storage unavailable'),
          );
          await tester.pump();
          expect(
            container.read(appLockProvider).hasInitializationError,
            isTrue,
          );
          expect(find.text('Private fixture'), findsNothing);
          expect(find.bySemanticsLabel('Private fixture'), findsNothing);
          expect(storage.values['app_lock.enabled'], 'true');
          expect(storage.writes, 0);
          storage.enabledRead = null;
          await tester.tap(find.text(language == 'en' ? 'Retry' : 'Повторить'));
          await tester.pump();
          await tester.pump();
          expect(
            container.read(appLockProvider).hasInitializationError,
            isFalse,
          );
          expect(container.read(appLockProvider).isInitializing, isFalse);
          expect(container.read(appLockProvider).isEnabled, isTrue);
          expect(container.read(appLockProvider).isLocked, isTrue);
          expect(find.text('Private fixture'), findsNothing);
          expect(
            find.text(
              language == 'en' ? 'NiosMess is locked' : 'NiosMess заблокирован',
            ),
            findsOneWidget,
          );
          biometric.authentication = () async => true;
          expect(
            await container
                .read(appLockProvider.notifier)
                .authenticateAndUnlock(),
            isTrue,
          );
          await tester.pump();
          expect(find.text('Private fixture'), findsOneWidget);
          expect(storage.values['app_lock.enabled'], 'true');
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
