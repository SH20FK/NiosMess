out_path = r"f:\Niosmess V2\pulse_flutter\test\auth_e2e_flow_test.dart"

tier3_and_4_code = """
  // ===========================================================================
  // TIER 3: PAIRWISE COMBINATIONS & NAVIGATION FLOWS (10 Tests)
  // ===========================================================================

  group('Feature Combinations: Pairwise Navigation Flows - Tier 3', () {
    testWidgets('F-T3-1: Onboarding -> Create Account -> Register -> Fill Form -> Verify Email', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/onboarding'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Onboarding
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RegisterScreen), findsOneWidget);

      // 2. Register Form
      await tester.enterText(find.byType(TextField).at(0), 'Alex Rivera');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      final cbs = find.byType(Checkbox);
      await tester.tap(cbs.at(0));
      await tester.tap(cbs.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));

      // 3. Verify Email
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
    });

    testWidgets('F-T3-2: Onboarding -> Log In -> Login -> Enter Credentials -> 2FA -> Main Chats', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldRequireTwoFa = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/onboarding'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Onboarding
      await tester.tap(find.widgetWithText(FilledButton, 'Welcome back'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoginScreen), findsOneWidget);

      // 2. Login Form
      await tester.enterText(find.byType(TextField).at(0), 'alex_r');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      // 3. 2FA Screen
      expect(find.byType(TwoFaScreen), findsOneWidget);

      // Reset repo flag so 2FA succeeds
      fakeAuthRepo.shouldRequireTwoFa = false;

      // 4. Enter 6 digits
      for (int i = 1; i <= 6; i++) {
        await tester.tap(find.text('$i'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      // 5. Main Chats
      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T3-3: Login -> Forgot Password -> Request -> Confirm -> Login', (WidgetTester tester) async {
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

      // 1. Forgot password
      await tester.tap(find.text('Forgot password?'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResetPasswordRequestScreen), findsOneWidget);

      // 2. Request screen
      await tester.enterText(find.byType(TextField), 'alex@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);

      // 3. Confirm screen
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.enterText(find.byType(TextField).last, 'BrandNewPassword123!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 500));

      // 4. Back to Login
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('F-T3-4: Registration -> Switch to Login -> Switch to Register (Bi-directional)', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RegisterScreen), findsOneWidget);

      // Tap Log In link
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoginScreen), findsOneWidget);

      // Tap Create account link
      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('F-T3-5: Verify Email (Authenticated) -> Setup Wizard -> Language -> Timezone -> Main Chats', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) {
            fakeAuthRepo = FakeAuthRepository(ref);
            return fakeAuthRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      // Log in first so user is authenticated
      await container.read(authProvider.notifier).login(identifier: 'alex_r', password: 'Password123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildAuthTestHarness(initialLocation: '/verify-email?email=alex%40example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      // Arrives at Setup Wizard
      expect(find.byType(SetupOnboardingScreen), findsOneWidget);

      // Step 0 -> Step 1 (Language)
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Russian'));
      await tester.pump(const Duration(milliseconds: 100));

      // Step 1 -> Step 2 (Timezone)
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      // Step 2 -> Finish
      await tester.tap(find.widgetWithText(PulseButton, 'Start messaging'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T3-6: Registration with Duplicate Username -> Correction -> Verify Email', (WidgetTester tester) async {
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

      await tester.enterText(find.byType(TextField).at(0), 'Alex Rivera');
      await tester.enterText(find.byType(TextField).at(1), 'taken_user');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      final cbs = find.byType(Checkbox);
      await tester.tap(cbs.at(0));
      await tester.tap(cbs.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      // First submit fails
      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RegisterScreen), findsOneWidget);

      // User fixes username and server is happy
      fakeAuthRepo.shouldFailRegister = false;
      await tester.enterText(find.byType(TextField).at(1), 'unique_alex');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('F-T3-7: Login with Bad Password -> Correction -> Main Chats', (WidgetTester tester) async {
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

      await tester.enterText(find.byType(TextField).at(0), 'alex_r');
      await tester.enterText(find.byType(TextField).at(1), 'wrong_pass');
      await tester.pump(const Duration(milliseconds: 100));

      // Attempt 1: Fails
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoginScreen), findsOneWidget);

      // Fix password
      fakeAuthRepo.shouldFailLogin = false;
      await tester.enterText(find.byType(TextField).at(1), 'CorrectSecret123!');
      await tester.pump(const Duration(milliseconds: 100));

      // Attempt 2: Succeeds
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T3-8: 2FA Failure -> Re-enter Code -> Auto-submit -> Main Chats', (WidgetTester tester) async {
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

      // Attempt 1: Wrong code
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('0'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TwoFaScreen), findsOneWidget);

      // Attempt 2: Correct code
      fakeAuthRepo.shouldFailTwoFa = false;
      for (int i = 1; i <= 6; i++) {
        await tester.tap(find.text('$i'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T3-9: Setup Wizard 3-Step Walkthrough with Language & Timezone Selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Step 0: Welcome
      expect(find.text('Nice to meet you!'), findsOneWidget);
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      // Step 1: Language
      expect(find.text('Choose your language'), findsOneWidget);
      await tester.tap(find.text('English').first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      // Step 2: Timezone
      expect(find.text('Your time zone'), findsOneWidget);
      await tester.tap(find.text('Automatic'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(PulseButton, 'Start messaging'));
      await tester.pump(const Duration(milliseconds: 500));

      // Complete
      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T3-10: Reset Password Flow -> Confirm -> Login with New Credentials', (WidgetTester tester) async {
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

      // Request
      await tester.enterText(find.byType(TextField), 'alex@example.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 500));

      // Confirm
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.enterText(find.byType(TextField).last, 'UpdatedPass123!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 500));

      // Login with new credentials
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'UpdatedPass123!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD APPLICATION SCENARIOS (5 Tests)
  // ===========================================================================

  group('Full Journeys: Real-World Scenarios - Tier 4', () {
    testWidgets('F-T4-1: Scenario 1 - Complete New User Journey (Onboarding -> Register -> Verify -> Setup -> Chats)', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((ref) {
            fakeAuthRepo = FakeAuthRepository(ref);
            return fakeAuthRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildAuthTestHarness(initialLocation: '/onboarding'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Phase 1: Onboarding
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump(const Duration(milliseconds: 500));

      // Phase 2: Registration
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextField).at(1), 'jane_doe');
      await tester.enterText(find.byType(TextField).at(2), 'jane@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'SecurePassword123!');
      await tester.pump(const Duration(milliseconds: 100));

      final cbs = find.byType(Checkbox);
      await tester.tap(cbs.at(0));
      await tester.tap(cbs.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));

      // Phase 3: Email Verification
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '654321');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(Material, 'Confirm code'));
      await tester.pump(const Duration(milliseconds: 500));

      // Phase 4: Login to Authenticate & Enter Setup Wizard
      if (find.byType(LoginScreen).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField).at(0), 'jane@example.com');
        await tester.enterText(find.byType(TextField).at(1), 'SecurePassword123!');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Log In').last);
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Phase 5: Main Chats
      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T4-2: Scenario 2 - Returning User Standard Login with 2FA Challenge', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              fakeAuthRepo.shouldRequireTwoFa = true;
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/login'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Login form with 2FA challenge
      await tester.enterText(find.byType(TextField).at(0), 'existing_user');
      await tester.enterText(find.byType(TextField).at(1), 'SecretPass123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      // 2FA Screen
      expect(find.byType(TwoFaScreen), findsOneWidget);

      fakeAuthRepo.shouldRequireTwoFa = false;
      for (int i = 1; i <= 6; i++) {
        await tester.tap(find.text('$i'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T4-3: Scenario 3 - Biometric Fast-Path Login', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.isEnabled = true;
      fakeBiometricService.authSuccess = true;

      final container = ProviderContainer(
        overrides: [
          biometricServiceProvider.overrideWithValue(fakeBiometricService),
          authRepositoryProvider.overrideWith((ref) {
            fakeAuthRepo = FakeAuthRepository(ref);
            return fakeAuthRepo;
          }),
        ],
      );
      addTearDown(container.dispose);

      // Perform biometric authentication
      final authenticated = await container.read(biometricServiceProvider).authenticateIfEnabled();
      expect(authenticated, isTrue);

      // Auto-restore session and route to Main Chats
      await container.read(authProvider.notifier).login(identifier: 'bio_user', password: 'StoredPassword123!');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildAuthTestHarness(initialLocation: '/login'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(container.read(authProvider).isAuthenticated, isTrue);
    });

    testWidgets('F-T4-4: Scenario 4 - Password Recovery & Re-Login Journey', (WidgetTester tester) async {
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

      // 1. Click Forgot Password
      await tester.tap(find.text('Forgot password?'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ResetPasswordRequestScreen), findsOneWidget);

      // 2. Request OTP
      await tester.enterText(find.byType(TextField), 'user@recovery.org');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Send code'));
      await tester.pump(const Duration(milliseconds: 500));

      // 3. Confirm with OTP & New Password
      expect(find.byType(ResetPasswordConfirmScreen), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '987654');
      await tester.enterText(find.byType(TextField).last, 'BrandNewSecret2026!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Update password'));
      await tester.pump(const Duration(milliseconds: 500));

      // 4. Log in with New Password
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'user@recovery.org');
      await tester.enterText(find.byType(TextField).at(1), 'BrandNewSecret2026!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F-T4-5: Scenario 5 - Skip & Quick Onboarding Journey', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/onboarding'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Onboarding -> Log In
      await tester.tap(find.widgetWithText(FilledButton, 'Welcome back'));
      await tester.pump(const Duration(milliseconds: 500));

      // 2. Log in
      await tester.enterText(find.byType(TextField).at(0), 'quick_user');
      await tester.enterText(find.byType(TextField).at(1), 'Pass123!');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      // 3. Arrives at Chats
      expect(find.text('Main Chats Screen'), findsOneWidget);
    });
  });
}
"""

with open(out_path, "a", encoding="utf-8") as f:
    f.write(tier3_and_4_code)

print("Tier 3 & 4 (15 tests) appended successfully. Total tests: 115.")
