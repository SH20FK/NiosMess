import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pulse_flutter/core/network/oauth_navigation_helper.dart';
import 'package:pulse_flutter/core/storage/ephemeral_storage.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/services/oauth_service.dart';
import 'package:pulse_flutter/widgets/adaptive/adaptive_glass.dart';
import 'package:pulse_flutter/widgets/m3_organic_background.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Material 3 Expressive Unified Authentication Hub for NiosMess with Nios ID OAuth 2.0 PKCE.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialCode,
    this.initialState,
    this.initialError,
    this.initialErrorDescription,
  });

  final String? initialCode;
  final String? initialState;
  final String? initialError;
  final String? initialErrorDescription;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isStartingAuth = false;
  bool _isExchanging = false;
  String? _statusText;
  NiosDeviceCodeResponse? _deviceCodeResponse;
  bool _isDevicePollingCancelled = false;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkOAuthReturn();
      }
    });
  }

  @override
  void dispose() {
    _isDevicePollingCancelled = true;
    super.dispose();
  }

  void _cancelDeviceAuth() {
    HapticFeedback.lightImpact();
    setState(() {
      _isDevicePollingCancelled = true;
      _deviceCodeResponse = null;
      _isStartingAuth = false;
    });
  }

  /// Checks URL query parameters or widget properties for OAuth 2.0 PKCE return data.
  Future<void> _checkOAuthReturn() async {
    final Uri currentUri = Uri.base;
    final Map<String, String> query = currentUri.queryParameters;

    final String? code = widget.initialCode ?? query['code'];
    final String? stateParam = widget.initialState ?? query['state'];
    final String? error = widget.initialError ?? query['error'];
    final String? errorDesc =
        widget.initialErrorDescription ?? query['error_description'];
    final String? niosOAuth = query['nios_oauth'];

    if (code == null && error == null && niosOAuth != 'start') {
      return;
    }

    // Clean address bar immediately to prevent token/code leakage
    OAuthNavigationHelper().sanitizeAddressBar();

    if (niosOAuth == 'start') {
      await _startNiosIdAuth();
      return;
    }

    if (error != null) {
      HapticService.destructive();
      if (mounted) {
        AppToast.showError(
          context,
          errorDesc ?? 'Доступ Nios ID не предоставлен.',
        );
      }
      return;
    }

    if (code != null) {
      await _handleOAuthCallback(code: code, stateParam: stateParam);
    }
  }

  /// Executes PKCE verification, code-to-token exchange and WebSocket login.
  Future<void> _handleOAuthCallback({
    required String code,
    required String? stateParam,
  }) async {
    final EphemeralStorage storage = EphemeralStorage();
    final String? verifier = storage.getVerifier();
    final String? expectedState = storage.getState();
    storage.clear();

    if (verifier == null ||
        expectedState == null ||
        stateParam != expectedState) {
      HapticService.destructive();
      if (mounted) {
        AppToast.showError(context, 'Не удалось проверить ответ Nios ID (state mismatch).');
      }
      return;
    }

    setState(() {
      _isExchanging = true;
      _statusText = 'Авторизация в Nios ID...';
    });

    try {
      final OAuthService oauthService = ref.read(oauthServiceProvider);
      final NiosOAuthTokenResponse tokenResponse = await oauthService
          .exchangeAuthCode(code: code, verifier: verifier);

      if (!tokenResponse.isSuccess || tokenResponse.accessToken == null) {
        throw Exception(
          tokenResponse.errorDescription ??
              tokenResponse.error ??
              'Не удалось получить токен доступа Nios ID',
        );
      }

      await _completeLoginWithToken(tokenResponse.accessToken!);
    } catch (e) {
      HapticService.destructive();
      if (mounted) {
        AppToast.showError(context, 'Ошибка авторизации: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExchanging = false;
          _statusText = null;
        });
      }
    }
  }

  Future<void> _completeLoginWithToken(String accessToken) async {
    setState(() {
      _statusText = 'Вход выполнен. Подключаем NiosMess...';
    });

    final AuthActionResult result = await ref
        .read(authProvider.notifier)
        .loginWithOAuth(oauthAccessToken: accessToken);

    if (!mounted) return;

    if (result.success) {
      HapticService.confirm();
      context.go('/main/chats');
    } else {
      HapticService.destructive();
      AppToast.showError(
        context,
        result.message ?? 'NiosMess не принял вход Nios ID',
      );
    }
  }

  /// Initiates RFC 8628 OAuth Device Flow for seamless universal login.
  Future<void> _startNiosIdAuth() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isStartingAuth = true;
      _isDevicePollingCancelled = false;
    });

    try {
      final OAuthService oauthService = ref.read(oauthServiceProvider);
      final NiosDeviceCodeResponse deviceResp =
          await oauthService.requestDeviceCode();

      if (!mounted) return;

      setState(() {
        _isStartingAuth = false;
        _deviceCodeResponse = deviceResp;
      });

      // Automatically open the authorization page with pre-filled code in browser
      await OAuthNavigationHelper()
          .openInBrowser(deviceResp.verificationUriComplete);

      // Start polling for token
      _runDeviceTokenPolling(deviceResp);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStartingAuth = false;
          _deviceCodeResponse = null;
        });
        AppToast.showError(context, 'Не удалось начать авторизацию: $e');
      }
    }
  }

  Future<void> _runDeviceTokenPolling(NiosDeviceCodeResponse deviceResp) async {
    final OAuthService oauthService = ref.read(oauthServiceProvider);

    try {
      final NiosOAuthTokenResponse? tokenResp =
          await oauthService.pollDeviceToken(
        deviceCode: deviceResp.deviceCode,
        intervalSeconds: deviceResp.interval,
        maxDurationSeconds: deviceResp.expiresIn,
        isCancelled: () => _isDevicePollingCancelled || !mounted,
      );

      if (_isDevicePollingCancelled || !mounted || tokenResp == null) {
        return;
      }

      if (!tokenResp.isSuccess || tokenResp.accessToken == null) {
        throw Exception(tokenResp.errorDescription ?? 'Не получен токен доступа');
      }

      setState(() {
        _deviceCodeResponse = null;
        _isExchanging = true;
      });

      await _completeLoginWithToken(tokenResp.accessToken!);
    } catch (e) {
      if (_isDevicePollingCancelled || !mounted) return;
      HapticService.destructive();
      setState(() {
        _deviceCodeResponse = null;
        _isExchanging = false;
      });
      AppToast.showError(context, 'Ошибка входа Nios ID: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_deviceCodeResponse != null) {
          _cancelDeviceAuth();
          return;
        }
        final DateTime now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          AppToast.showInfo(context, 'Нажмите ещё раз для выхода');
          return;
        }
        SystemUtils.minimizeApp();
      },
      child: M3OrganicBackground(
        showBackButton: false,
        showThemeToggle: true,
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Hero Header ──────────────────────────────
                        _buildHeroHeader(scheme, textTheme),
                        const SizedBox(height: 28),

                        // ── Ecosystem Benefits Card ───────────────────
                        _buildBenefitsCard(scheme, textTheme),
                        const SizedBox(height: 32),

                        // ── Primary Action Block ──────────────────────
                        _buildPrimaryAction(scheme, textTheme),
                        const SizedBox(height: 16),

                        // ── Secondary Action (Register) ───────────────
                        _buildSecondaryAction(scheme, textTheme),
                        const SizedBox(height: 28),

                        // ── Legal Footer ──────────────────────────────
                        _buildLegalFooter(scheme, textTheme),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Loading Overlay during OAuth Exchange ────────────────
            if (_isExchanging) _buildLoadingOverlay(scheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      children: [
        // Brand Squircle Logo Badge
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.all_inclusive_rounded,
              size: 46,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),

        // Brand Title
        Text(
          'NiosMess',
          style: GoogleFonts.unbounded(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 8),

        // Subtitle
        Text(
          'Войдите в NiosMess через аккаунт Nios ID',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildBenefitsCard(ColorScheme scheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildPillarRow(
            icon: Icons.badge_outlined,
            iconBg: scheme.primaryContainer,
            iconColor: scheme.onPrimaryContainer,
            title: 'Единый вход Nios ID',
            subtitle: 'Быстрый и защищённый доступ без ввода лишних паролей.',
            scheme: scheme,
            textTheme: textTheme,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              height: 1,
            ),
          ),
          _buildPillarRow(
            icon: Icons.lock_outline_rounded,
            iconBg: scheme.secondaryContainer,
            iconColor: scheme.onSecondaryContainer,
            title: 'Сквозное E2EE шифрование',
            subtitle: 'Ваши сообщения и звонки защищены криптографией на устройстве.',
            scheme: scheme,
            textTheme: textTheme,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              height: 1,
            ),
          ),
          _buildPillarRow(
            icon: Icons.shield_outlined,
            iconBg: scheme.tertiaryContainer,
            iconColor: scheme.onTertiaryContainer,
            title: 'Конфиденциальность',
            subtitle: 'NiosMess не получает и не хранит мастер-пароль от аккаунта.',
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 150.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPillarRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryAction(ColorScheme scheme, TextTheme textTheme) {
    if (_deviceCodeResponse != null) {
      return _buildDeviceCodeCard(scheme, textTheme);
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: (_isStartingAuth || _isExchanging) ? null : _startNiosIdAuth,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        icon: _isStartingAuth
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                ),
              )
            : Icon(Icons.vpn_key_rounded, size: 20, color: scheme.onPrimary),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Войти через Nios ID',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 250.ms);
  }

  Widget _buildDeviceCodeCard(ColorScheme scheme, TextTheme textTheme) {
    final NiosDeviceCodeResponse resp = _deviceCodeResponse!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ожидание подтверждения...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'В браузере открыта страница входа Nios ID. Убедитесь, что код совпадает:',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: resp.userCode));
              HapticFeedback.lightImpact();
              AppToast.showSuccess(context, 'Код скопирован');
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resp.userCode,
                    style: GoogleFonts.firaCode(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    OAuthNavigationHelper().openInBrowser(resp.verificationUriComplete);
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Открыть Nios ID'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _cancelDeviceAuth,
                child: const Text('Отмена'),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSecondaryAction(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      children: [
        Center(
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              OAuthNavigationHelper().openRegistration();
            },
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: scheme.primary,
            ),
            label: Text(
              'Создать аккаунт Nios ID',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms, delay: 300.ms);
  }

  Widget _buildLegalFooter(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      children: [
        Text(
          'Входя в приложение, вы соглашаетесь с документами:',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            InkWell(
              onTap: () => context.push('/legal/terms'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Условия использования',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            Text(
              '•',
              style: TextStyle(
                color: scheme.outlineVariant,
                fontSize: 12,
              ),
            ),
            InkWell(
              onTap: () => context.push('/legal/privacy'),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Политика конфиденциальности',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 450.ms, delay: 350.ms);
  }

  Widget _buildLoadingOverlay(ColorScheme scheme, TextTheme textTheme) {
    return Positioned.fill(
      child: AdaptiveGlass(
        tierASigma: 8.0,
        tierBSigma: 4.0,
        tintColor: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.zero,
        border: const Border.fromBorderSide(BorderSide.none),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulseLoadingIndicator(size: 48),
                const SizedBox(height: 20),
                Text(
                  _statusText ?? 'Авторизация...',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
