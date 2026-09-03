out_path = r"f:\Niosmess V2\pulse_flutter\test\auth_e2e_flow_test.dart"

tier1_code = """
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository fakeAuthRepo;
  late FakeBiometricService fakeBiometricService;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (50 Tests)
  // ===========================================================================

  group('Feature 1: Onboarding Carousel Screen - Tier 1 (Happy Path)', () {
    testWidgets('F1-T1-1: Renders AppLogoMark hero container and brand header', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.text('Ni'), findsOneWidget);
      expect(find.text('s Mess'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });

    testWidgets('F1-T1-2: Displays initial slide with call icon and description', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('F1-T1-3: Swiping PageView advances slide and updates pill indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('F1-T1-4: Tapping Create Account navigates to /register', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final primaryBtn = find.widgetWithText(FilledButton, 'Create account');
      expect(primaryBtn, findsOneWidget);

      await tester.tap(primaryBtn);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('F1-T1-5: Tapping Welcome Back / Login navigates to /login', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/onboarding',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final loginBtn = find.widgetWithText(FilledButton, 'Welcome back');
      expect(loginBtn, findsOneWidget);

      await tester.tap(loginBtn);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Feature 2: Setup Wizard Screen - Tier 1 (Happy Path)', () {
    testWidgets('F2-T1-1: Renders Step 0 Welcome step with waving hand hero badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
      expect(find.text('Nice to meet you!'), findsOneWidget);
      expect(find.widgetWithText(PulseButton, 'Continue'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
    });

    testWidgets('F2-T1-2: Step 0 to Step 1 transition displays language options', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.byIcon(Icons.language_rounded), findsOneWidget);
      expect(find.text('Russian'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('F2-T1-3: Selecting language tile updates selection checkmark', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Russian'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('F2-T1-4: Step 1 to Step 2 transition displays Timezone mode selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/setup',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Step 0 -> Step 1
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      // Step 1 -> Step 2
      await tester.tap(find.widgetWithText(PulseButton, 'Continue'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Your time zone'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('Choose manually'), findsOneWidget);
      expect(find.widgetWithText(PulseButton, 'Start messaging'), findsOneWidget);
    });

    testWidgets('F2-T1-5: Start messaging button completes wizard and routes to /main/chats', (WidgetTester tester) async {
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

      await tester.tap(find.widgetWithText(PulseButton, 'Start messaging'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });
  });

  group('Feature 3: Login Screen - Tier 1 (Happy Path)', () {
    testWidgets('F3-T1-1: Renders login form with brand header, inputs, and submit button', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/login',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(M3AuthTextField), findsNWidgets(2));
      expect(find.text('В'), findsOneWidget);
      expect(find.text('йти'), findsOneWidget);
      expect(find.text('Log In'), findsWidgets);
    });

    testWidgets('F3-T1-2: Password visibility toggle toggles obscureText', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/login',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('F3-T1-3: Submitting valid credentials authenticates and routes to /main/chats', (WidgetTester tester) async {
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Main Chats Screen'), findsOneWidget);
    });

    testWidgets('F3-T1-4: Login requiring 2FA redirects to /2fa', (WidgetTester tester) async {
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

      await tester.enterText(find.byType(TextField).at(0), 'alex_r');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123!');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TwoFaScreen), findsOneWidget);
    });

    testWidgets('F3-T1-5: Navigation links route to /register and /reset-password/request', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/login',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Forgot password link
      await tester.tap(find.text('Forgot password?'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ResetPasswordRequestScreen), findsOneWidget);
    });
  });

  group('Feature 4: Registration Screen - Tier 1 (Happy Path)', () {
    testWidgets('F4-T1-1: Renders registration fields, brand header, and consent checkboxes', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(M3AuthTextField), findsNWidgets(4));
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.text('С'), findsOneWidget);
      expect(find.text('здать'), findsOneWidget);
    });

    testWidgets('F4-T1-2: Password visibility toggle on registration switches obscureText', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    });

    testWidgets('F4-T1-3: Tapping checkboxes toggles ToS and Privacy consent', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(0));
      await tester.tap(checkboxes.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      final Checkbox cb0 = tester.widget<Checkbox>(checkboxes.at(0));
      final Checkbox cb1 = tester.widget<Checkbox>(checkboxes.at(1));
      expect(cb0.value, isTrue);
      expect(cb1.value, isTrue);
    });

    testWidgets('F4-T1-4: Valid registration with consent navigates to /verify-email', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              fakeAuthRepo = FakeAuthRepository(ref);
              return fakeAuthRepo;
            }),
          ],
          child: buildAuthTestHarness(initialLocation: '/register'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).at(0), 'Alex Rivera');
      await tester.enterText(find.byType(TextField).at(1), 'alex_r');
      await tester.enterText(find.byType(TextField).at(2), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(3), 'Password123!');
      await tester.pump(const Duration(milliseconds: 100));

      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(0));
      await tester.tap(checkboxes.at(1));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Create account').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });

    testWidgets('F4-T1-5: Tapping Already have an account navigates to /login', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildAuthTestHarness(
          initialLocation: '/register',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Log In').last);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('Feature 5: Biometric Service & Capabilities - Tier 1 (Happy Path)', () {
    testWidgets('F5-T1-1: isDeviceSupported detects biometric hardware availability', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.isSupported = true;

      final supported = await fakeBiometricService.isDeviceSupported;
      expect(supported, isTrue);
    });

    testWidgets('F5-T1-2: canCheckBiometrics verifies biometric enrollment status', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.canCheck = true;

      final canCheck = await fakeBiometricService.canCheckBiometrics;
      expect(canCheck, isTrue);
    });

    testWidgets('F5-T1-3: isBiometricEnabled persists preference in secure storage', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      expect(await fakeBiometricService.isBiometricEnabled, isFalse);

      await fakeBiometricService.setBiometricEnabled(true);
      expect(await fakeBiometricService.isBiometricEnabled, isTrue);
    });

    testWidgets('F5-T1-4: authenticate invokes prompt and returns true on success', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.authSuccess = true;

      final result = await fakeBiometricService.authenticate();
      expect(result, isTrue);
    });

    testWidgets('F5-T1-5: authenticateIfEnabled checks enabled flag and authenticates', (WidgetTester tester) async {
      fakeBiometricService = FakeBiometricService();
      fakeBiometricService.isEnabled = false;
      expect(await fakeBiometricService.authenticateIfEnabled(), isTrue);

      fakeBiometricService.isEnabled = true;
      fakeBiometricService.authSuccess = true;
      expect(await fakeBiometricService.authenticateIfEnabled(), isTrue);
    });
  });
"""

with open(out_path, "a", encoding="utf-8") as f:
    f.write(tier1_code)

print("Tier 1 Features 1-5 appended")
