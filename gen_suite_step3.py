out_path = r"f:\Niosmess V2\pulse_flutter\test\auth_e2e_flow_test.dart"

tier1_part2 = """
  group('Feature 6: 2FA OTP Screen - Tier 1 (Happy Path)', () {
    testWidgets('F6-T1-1: Renders hero title, subtitle, PIN dots, and numeric keypad', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Security verification'), findsOneWidget);
      expect(find.text('Enter 6-digit confirmation code'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('F6-T1-2: Tapping numeric keypad digits enters digits into PIN state', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F6-T1-3: Backspace key removes the last entered digit', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F6-T1-4: Entering 6th digit automatically submits 2FA verification', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/2fa?identifier=alex_r'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 1; i <= 6; i++) {
        await tester.tap(find.text('$i'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F6-T1-5: Successful 2FA verification routes to /main/chats', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/2fa?identifier=alex_r'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('9'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });
  });

  group('Feature 7: Email Verification Screen - Tier 1 (Happy Path)', () {
    testWidgets('F7-T1-1: Renders hero badge, email card, and CodePreview boxes', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.mark_email_read_rounded), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.byType(CodePreview), findsOneWidget);
    });

    testWidgets('F7-T1-2: Entering 6-digit code in hidden input formats CodePreview', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('F7-T1-3: Submitting valid code for authenticated user routes to /setup', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/verify-email?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('F7-T1-4: Submitting valid code for unauthenticated user routes to /login', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/verify-email?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '654321');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('F7-T1-5: Back button navigates back to /login', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Feature 8: Password Reset Request & Confirm - Tier 1 (Happy Path)', () {
    testWidgets('F8-T1-1: Reset request screen renders email field and submit button', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/request',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
      expect(find.byType(M3AuthTextField), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('F8-T1-2: Submitting valid email on request screen routes to /reset-password/confirm', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/reset-password/request'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'alex@example.com');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
    });

    testWidgets('F8-T1-3: Reset confirm screen renders email, CodePreview, and new password field', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/confirm?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.password_rounded), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.byType(CodePreview), findsOneWidget);
      expect(find.byType(M3AuthTextField), findsOneWidget);
    });

    testWidgets('F8-T1-4: New password visibility toggle toggles obscureText', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/confirm?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('F8-T1-5: Submitting valid OTP and new password confirms reset and routes to /login', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/reset-password/confirm?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.enterText(find.byType(TextField).last, 'NewPassword123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Feature 9: 6-Digit M3 OTP Input & CodePreview - Tier 1 (Happy Path)', () {
    testWidgets('F9-T1-1: CodePreview renders 6 discrete squircle containers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodePreview(code: '12'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsNWidgets(6));
    });

    testWidgets('F9-T1-2: CodePreview displays entered digits in respective cells', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodePreview(code: '456'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('F9-T1-3: Active cursor box renders primary border highlight', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodePreview(code: '1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodePreview), findsOneWidget);
    });

    testWidgets('F9-T1-4: Non-digit input is stripped from CodePreview', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodePreview(code: 'A9B8'.replaceAll(RegExp(r'\\D'), '')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('A'), findsNothing);
    });

    testWidgets('F9-T1-5: Full 6-digit code fills all 6 boxes completely', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CodePreview(code: '123456'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 1; i <= 6; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });
  });

  group('Feature 10: Auth State & Storage Lifecycle - Tier 1 (Happy Path)', () {
    test('F10-T1-1: AuthState.initial has unhydrated, not busy, null session', () {
      const state = AuthState.initial();
      expect(state.hydrated, isFalse);
      expect(state.busy, isFalse);
      expect(state.session, isNull);
      expect(state.isAuthenticated, isFalse);
      expect(state.error, isNull);
    });

    test('F10-T1-2: AuthState.copyWith accurately updates and clears properties', () {
      const state = AuthState.initial();
      final updated = state.copyWith(
        hydrated: true,
        busy: true,
        session: const AuthSession(
          accessToken: 'token_abc',
          userId: 1,
          username: 'user1',
          displayName: 'User One',
        ),
      );

      expect(updated.hydrated, isTrue);
      expect(updated.busy, isTrue);
      expect(updated.isAuthenticated, isTrue);

      final cleared = updated.copyWith(clearSession: true, busy: false);
      expect(cleared.isAuthenticated, isFalse);
      expect(cleared.busy, isFalse);
    });

    test('F10-T1-3: sessionProvider completeOnboarding marks onboardingCompleted', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).completeOnboarding();
      expect(container.read(sessionProvider).onboardingCompleted, isTrue);
    });

    test('F10-T1-4: AuthNotifier logout clears session and resets state', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(ref)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).session, isNull);
    });

    test('F10-T1-5: AuthNotifier updateProfile updates active session data', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(ref)),
        ],
      );
      addTearDown(container.dispose);

      // Authenticate
      await container.read(authProvider.notifier).login(
        identifier: 'alex_r',
        password: 'Password123!',
      );

      final res = await container.read(authProvider.notifier).updateProfile(
        displayName: 'Alexander The Great',
      );

      expect(res.success, isTrue);
      expect(container.read(authProvider).session?.displayName, equals('Alexander The Great'));
    });
  });
"""

with open(out_path, "a", encoding="utf-8") as f:
    f.write(tier1_part2)

print("Tier 1 Features 6-10 appended")
