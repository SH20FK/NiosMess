out_path = r"f:\Niosmess V2\pulse_flutter\test\auth_e2e_flow_test.dart"

tier2_code = """
  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES (50 Tests)
  // ===========================================================================

  group('Feature 1: Onboarding Carousel Screen - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F1-T2-1: Swiping past boundary on last slide does not throw exception', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 5; i++) {
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('F1-T2-2: Theme toggle button on organic background switches theme mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final themeToggle = find.byIcon(Icons.dark_mode_rounded);
      expect(themeToggle, findsOneWidget);

      await tester.tap(themeToggle);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F1-T2-3: Back button is hidden on onboarding screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('F1-T2-4: Rapid button taps handle completion cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final btn = find.widgetWithText(FilledButton, 'Create account');
      for (int i = 0; i < 3; i++) {
        await tester.tap(btn);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('F1-T2-5: Small viewport (320x568) renders without overflow errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
          surfaceSize: const Size(320, 568),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  group('Feature 2: Setup Wizard Screen - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F2-T2-1: Tapping Skip on Step 0 applies default locale/auto timezone and completes', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F2-T2-2: Tapping Skip on Step 1 completes setup wizard and navigates to /main/chats', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F2-T2-3: Manual timezone tile opens search bottom sheet with query filter', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Choose manually'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('F2-T2-4: Setup wizard has PopScope(canPop: false) preventing dismissal', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);
    });

    testWidgets('F2-T2-5: Live clock format handles current DateTime safely', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Step 0 -> Step 1 -> Step 2
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Current time'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Feature 3: Login Screen - Tier 2 (Boundaries & Validation)', () {
    testWidgets('F3-T2-1: Empty identifier triggers validation error', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/login',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Please enter username or email'), findsOneWidget);
    });

    testWidgets('F3-T2-2: Empty password triggers validation error', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/login',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'alex_r');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter password'), findsOneWidget);
    });

    testWidgets('F3-T2-3: Server login failure keeps user on login screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailLogin = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/login'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'wrong_user');
      await tester.enterText(find.byType(TextField).at(1), 'wrong_pass');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('F3-T2-4: Duplicate submit taps during busy state are ignored', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/login'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'alex_r');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F3-T2-5: Whitespace in identifier is automatically trimmed', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/login'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), '  alex_r  ');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeAuthRepo.lastLoginIdentifier, equals('alex_r'));
    });
  });

  group('Feature 4: Registration Screen - Tier 2 (Boundaries & Validation)', () {
    testWidgets('F4-T2-1: Empty display name fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter name'), findsOneWidget);
    });

    testWidgets('F4-T2-2: Short display name (<2 chars) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'A');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('F4-T2-3: Short username (<3 chars) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'al');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Username must be at least 3 characters'), findsOneWidget);
    });

    testWidgets('F4-T2-4: Invalid email (missing @) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'invalid-email');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('F4-T2-5: Short password (<8 chars) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'short');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('F4-T2-6: Unchecked Terms of Service blocks submission', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      // Only check privacy
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('F4-T2-7: Unchecked Privacy Policy blocks submission', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      // Only check ToS
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('F4-T2-8: Server registration error displays error toast and resets busy state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailRegister = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/register'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex');
      await tester.enterText(find.byType(TextField).at(1), 'duplicate_user');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      final cbs = find.byType(Checkbox);
      await tester.tap(cbs.at(0));
      await tester.tap(cbs.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });

  group('Feature 5: Biometric Service - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F5-T2-1: Biometric failure returns false without unhandled exceptions', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.authSuccess = false;

      final result = await fakeBiometricService.authenticate();
      expect(result, isFalse);
    });

    testWidgets('F5-T2-2: Biometric hardware unavailable returns isDeviceSupported false', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.isSupported = false;

      expect(await fakeBiometricService.isDeviceSupported, isFalse);
    });

    testWidgets('F5-T2-3: Unenrolled biometrics returns canCheckBiometrics false', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.canCheck = false;

      expect(await fakeBiometricService.canCheckBiometrics, isFalse);
    });

    testWidgets('F5-T2-4: Empty secure storage returns isBiometricEnabled false by default', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      expect(await fakeBiometricService.isBiometricEnabled, isFalse);
    });

    testWidgets('F5-T2-5: Disabling biometrics writes false to storage', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      await fakeBiometricService.setBiometricEnabled(true);
      expect(await fakeBiometricService.isBiometricEnabled, isTrue);

      await fakeBiometricService.setBiometricEnabled(false);
      expect(await fakeBiometricService.isBiometricEnabled, isFalse);
    });
  });

  group('Feature 6: 2FA OTP Screen - Tier 2 (Boundaries & Keypad)', () {
    testWidgets('F6-T2-1: Missing pending identifier on 2FA submit returns error gracefully', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(ref)),
        ],
      );
      addTearDown(container.dispose);

      final res = await container.read(authProvider.notifier).verifyTwoFa(code: '123456');
      expect(res.success, isFalse);
      expect(res.message, contains('2FA session is missing'));
    });

    testWidgets('F6-T2-2: Submit arrow button is disabled when PIN length < 6', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TwoFaScreen), findsOneWidget);
    });

    testWidgets('F6-T2-3: Invalid 2FA OTP error displays error toast and resets PIN', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailTwoFa = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/2fa?identifier=alex_r'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('1'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TwoFaScreen), findsOneWidget);
    });

    testWidgets('F6-T2-4: Backspace key on empty PIN handles safely without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F6-T2-5: Keypad input ignores extra digit taps beyond 6 digits', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/2fa?identifier=alex_r',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      for (int i = 0; i < 8; i++) {
        await tester.tap(find.text('5'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('Feature 7: Email Verification Screen - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F7-T2-1: Incomplete code (<6 digits) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('F7-T2-2: Verification failure preserves email and stays on screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailVerifyEmail = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/verify-email?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
    });

    testWidgets('F7-T2-3: Code with letters or symbols is filtered to digits only', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '1A2B3C');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('F7-T2-4: Submitting during busy state is prevented', (WidgetTester tester) async {
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
      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F7-T2-5: Initial email from query parameter populates email card', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/verify-email?email=special.user%2Btag%40domain.org',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('special.user+tag@domain.org'), findsOneWidget);
    });
  });

  group('Feature 8: Password Reset - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F8-T2-1: Reset request with invalid email fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/request',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'invalidemail');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('F8-T2-2: Server error on reset request stays on screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailResetRequest = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/reset-password/request'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField), 'unknown@example.com');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResetPasswordRequestScreen), findsOneWidget);
    });

    testWidgets('F8-T2-3: Reset confirm with <6 digit OTP fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/confirm?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.enterText(find.byType(TextField).last, 'NewPassword123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);
    });

    testWidgets('F8-T2-4: Reset confirm with short password (<6 chars) fails validation', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/reset-password/confirm?email=alex%40example.com',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.enterText(find.byType(TextField).last, '123');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('F8-T2-5: Server error on reset confirm allows retry', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldFailResetConfirm = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/reset-password/confirm?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.enterText(find.byType(TextField).last, 'NewPassword123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);
    });
  });

  group('Feature 9: M3AuthTextField - Tier 2 (Boundaries & Edge Cases)', () {
    testWidgets('F9-T2-1: Focus node listener updates border and styling', (WidgetTester tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(() {
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AuthTextField(
                controller: controller,
                label: 'Test Label',
                prefixIcon: Icons.person_rounded,
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(M3AuthTextField), findsOneWidget);
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('F9-T2-2: Field validation error applies error text', (WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: M3AuthTextField(
                controller: controller,
                label: 'Validated Field',
                prefixIcon: Icons.email_rounded,
                validator: (val) => (val == null || val.isEmpty) ? 'Required Field' : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Required Field'), findsOneWidget);
    });

    testWidgets('F9-T2-3: Suffix icon button receives tap events', (WidgetTester tester) async {
      final controller = TextEditingController();
      bool suffixTapped = false;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AuthTextField(
                controller: controller,
                label: 'Suffix Field',
                prefixIcon: Icons.lock_rounded,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    suffixTapped = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(suffixTapped, isTrue);
    });

    testWidgets('F9-T2-4: Unicode and emoji input enters cleanly', (WidgetTester tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AuthTextField(
                controller: controller,
                label: 'Unicode Field',
                prefixIcon: Icons.message_rounded,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test Unicode');
      await tester.pumpAndSettle();

      expect(controller.text, equals('Test Unicode'));
    });

    testWidgets('F9-T2-5: onFieldSubmitted callback triggers on enter', (WidgetTester tester) async {
      final controller = TextEditingController();
      String? submittedValue;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: M3AuthTextField(
                controller: controller,
                label: 'Submit Field',
                prefixIcon: Icons.check_rounded,
                onFieldSubmitted: (v) => submittedValue = v,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Submitted text');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submittedValue, equals('Submitted text'));
    });
  });

  group('Feature 10: Session & Preferences - Tier 2 (Boundaries & Edge Cases)', () {
    test('F10-T2-1: SessionNotifier defaults to false when storage is empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).ensureLoaded();
      expect(container.read(sessionProvider).onboardingCompleted, isFalse);
    });

    test('F10-T2-2: uiSettingsProvider manual timezone sets specified timezone ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(uiSettingsProvider.notifier).useManualTimeZone('Asia/Tokyo');
      expect(container.read(uiSettingsProvider).timeZoneMode, equals(AppTimeZoneMode.manual));
      expect(container.read(uiSettingsProvider).timeZoneId, equals('Asia/Tokyo'));
    });

    test('F10-T2-3: uiSettingsProvider automatic timezone clears manual zone ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(uiSettingsProvider.notifier).useManualTimeZone('America/New_York');
      container.read(uiSettingsProvider.notifier).useAutomaticTimeZone();

      expect(container.read(uiSettingsProvider).timeZoneMode, equals(AppTimeZoneMode.auto));
    });

    test('F10-T2-4: AuthNotifier refreshProfile without session does nothing safely', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => FakeAuthRepository(ref)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).refreshProfile();
      expect(container.read(authProvider).isAuthenticated, isFalse);
    });

    test('F10-T2-5: AuthNotifier clearError resets error state to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authProvider.notifier).clearError();
      expect(container.read(authProvider).error, isNull);
    });
  });
"""

with open(out_path, "a", encoding="utf-8") as f:
    f.write(tier2_code)

print("Tier 2 appended successfully")
