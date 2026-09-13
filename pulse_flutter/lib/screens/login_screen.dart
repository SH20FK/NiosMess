import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/network/oauth_navigation_helper.dart';
import 'package:pulse_flutter/core/storage/ephemeral_storage.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
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
          errorDesc ?? context.l10n.loginNiosIdNotGranted,
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
        AppToast.showError(context, context.l10n.loginNiosIdStateMismatch);
      }
      return;
    }

    final l10n = context.l10n;
    setState(() {
      _isExchanging = true;
      _statusText = l10n.loginNiosIdAuthorizing;
    });

    try {
      final OAuthService oauthService = ref.read(oauthServiceProvider);
      final NiosOAuthTokenResponse tokenResponse = await oauthService
          .exchangeAuthCode(code: code, verifier: verifier);

      if (!tokenResponse.isSuccess || tokenResponse.accessToken == null) {
        throw Exception(
          tokenResponse.errorDescription ??
              tokenResponse.error ??
              l10n.loginNiosIdTokenFailed,
        );
      }

      await _completeLoginWithToken(tokenResponse.accessToken!);
    } catch (e) {
      HapticService.destructive();
      if (mounted) {
        AppToast.showError(context, l10n.loginAuthError(e));
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
      _statusText = context.l10n.loginConnectingNiosMess;
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
        result.message ?? context.l10n.loginNiosMessRejected,
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
          AppToast.showInfo(context, context.l10n.loginTapAgainToExit);
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Hero Header ──────────────────────────────
                        _buildHeroHeader(scheme, textTheme),
                        SizedBox(height: _deviceCodeResponse != null ? 32 : 44),

                        // ── Main Action or Device Code Verification ───
                        if (_deviceCodeResponse != null) ...[
                          _buildDeviceCodeCard(scheme, textTheme),
                        ] else ...[
                          _buildPrimaryAction(scheme, textTheme),
                          const SizedBox(height: 12),
                          _buildSecondaryAction(scheme, textTheme),
                        ],
                        const SizedBox(height: 36),

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Clean Brand Squircle Emblem with subtle glow
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.38 : 0.22),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                  spreadRadius: -2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: SvgPicture.asset(
              'assets/svg/niosmess_n_mark.svg',
              colorFilter: ColorFilter.mode(
                scheme.onPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 22),

        // Brand Title in Bricolage Grotesque
        Text(
          'NiosMess',
          style: TextStyle(
            fontFamily: AppFonts.headline,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
        const SizedBox(height: 10),

        // Subtitle without awkward line wraps
        Text(
          context.l10n.loginSlogan,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
      ],
    );
  }

  Widget _buildPrimaryAction(ColorScheme scheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: (_isStartingAuth || _isExchanging) ? null : _startNiosIdAuth,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        icon: _isStartingAuth
            ? AppLoadingIndicator(
                size: 20,
                color: scheme.onPrimary,
              )
            : const Icon(Icons.all_inclusive_rounded, size: 22),
        label: Text(
          context.l10n.loginSignInWithNiosId,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 150.ms);
  }

  Widget _buildSecondaryAction(ColorScheme scheme, TextTheme textTheme) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.tonal(
        onPressed: () {
          HapticFeedback.lightImpact();
          OAuthNavigationHelper().openRegistration();
        },
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.65),
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Text(
          context.l10n.loginCreateNiosId,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
            letterSpacing: 0.1,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 450.ms, delay: 200.ms);
  }

  Widget _buildDeviceCodeCard(ColorScheme scheme, TextTheme textTheme) {
    final NiosDeviceCodeResponse resp = _deviceCodeResponse!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),

      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppLoadingIndicator(
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.loginConfirmTitle,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.loginConfirmDesc,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),

          // High-contrast clean Code Box
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: resp.userCode));
              HapticFeedback.lightImpact();
              AppToast.showSuccess(context, context.l10n.loginCodeCopied);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        resp.userCode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: scheme.primary.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.loginTapToCopy,
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary confirmation button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                OAuthNavigationHelper().openInBrowser(resp.verificationUriComplete);
              },
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              label: Text(
                context.l10n.loginConfirmInBrowser,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Clean cancel action
          TextButton(
            onPressed: _cancelDeviceAuth,
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: Text(
              context.l10n.commonCancel,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1));
  }

  Widget _buildLegalFooter(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      children: [
        Text(
          context.l10n.loginAgreeTermsPrefix,
          style: TextStyle(
            fontFamily: AppFonts.body,
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
                  context.l10n.loginTermsOfService,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
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
                  context.l10n.loginPrivacyPolicy,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
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
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
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
