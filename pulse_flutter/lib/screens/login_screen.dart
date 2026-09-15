import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/network/oauth_navigation_helper.dart';
import 'package:pulse_flutter/core/storage/ephemeral_storage.dart';
import 'package:pulse_flutter/core/theme/app_typography.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/core/utils/app_toast.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/core/utils/system_utils.dart';
import 'package:pulse_flutter/models/api/auth_models.dart';
import 'package:pulse_flutter/providers/auth_provider.dart';
import 'package:pulse_flutter/providers/connectivity_provider.dart';
import 'package:pulse_flutter/services/oauth_service.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/auth/auth_scaffold.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  bool _isExplainerExpanded = false;
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
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isDevicePollingCancelled = true;
    super.dispose();
  }

  void _cancelDeviceAuth() {
    HapticService.tap();
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _isDevicePollingCancelled = true;
      _deviceCodeResponse = null;
      _isStartingAuth = false;
      _remainingSeconds = 0;
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
    // Offline pre-check
    final bool isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      HapticService.destructive();
      AppToast.showError(context, context.l10n.loginOfflineError);
      return;
    }

    HapticService.tap();
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _isStartingAuth = true;
      _isDevicePollingCancelled = false;
      _remainingSeconds = 0;
    });

    try {
      final OAuthService oauthService = ref.read(oauthServiceProvider);
      final NiosDeviceCodeResponse deviceResp =
          await oauthService.requestDeviceCode();

      if (!mounted) return;

      setState(() {
        _isStartingAuth = false;
        _deviceCodeResponse = deviceResp;
        _remainingSeconds = deviceResp.expiresIn;
      });

      // Start countdown timer
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          _isDevicePollingCancelled = true;
          setState(() {});
        }
      });

      // Open authorization page with pre-filled code in browser
      await OAuthNavigationHelper()
          .openInBrowser(deviceResp.verificationUriComplete);

      // Start polling for token
      _runDeviceTokenPolling(deviceResp);
    } catch (e) {
      if (mounted) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        setState(() {
          _isStartingAuth = false;
          _deviceCodeResponse = null;
          _remainingSeconds = 0;
        });
        HapticService.destructive();
        AppToast.showError(context, context.l10n.loginStartAuthFailed);
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
        throw Exception(
          tokenResp.errorDescription ?? context.l10n.loginNiosIdTokenFailed,
        );
      }

      _countdownTimer?.cancel();
      _countdownTimer = null;
      setState(() {
        _deviceCodeResponse = null;
        _isExchanging = true;
      });

      await _completeLoginWithToken(tokenResp.accessToken!);
    } catch (e) {
      if (_isDevicePollingCancelled || !mounted) return;
      HapticService.destructive();
      _countdownTimer?.cancel();
      _countdownTimer = null;
      setState(() {
        _deviceCodeResponse = null;
        _isExchanging = false;
      });
      AppToast.showError(context, context.l10n.loginNiosIdError);
    }
  }


  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isOnline = ref.watch(connectivityProvider).value ?? true;

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
      child: AuthScaffold(
        showBackButton: false,
        showThemeToggle: true,
        isLoadingOverlay: _isExchanging,
        loadingOverlayText:
            _statusText ?? context.l10n.loginAuthorizingOverlay,
        header: _buildHeroHeader(scheme, textTheme),
        footer: _buildLegalFooter(scheme, textTheme),
        children: [
          // ── Offline Warning Banner ──────────────────────────────────
          if (!isOnline) ...[
            _buildOfflineBanner(scheme),
            const SizedBox(height: 16),
          ],

          // ── Main Action or Device Code Verification ─────────────────
          if (_deviceCodeResponse != null) ...[
            _buildDeviceCodeCard(scheme, textTheme),
          ] else ...[
            _buildPrimaryAction(scheme),
            const SizedBox(height: 12),
            _buildSecondaryAction(),
            const SizedBox(height: 20),
            _buildExplainerSection(scheme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroHeader(ColorScheme scheme, TextTheme textTheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Unified Brand Hero Logo without drop shadows or MD2 elevation
        Center(
          child: Hero(
            tag: 'app_brand_logo',
            child: const AppLogoMark(size: 80),
          )
              .animate()
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: const Duration(milliseconds: 380),
                curve: M3SpringCurves.spatial,
              )
              .fade(duration: const Duration(milliseconds: 300)),
        ),
        const SizedBox(height: 20),

        // Brand Title using localized appName
        Text(
          context.l10n.appName,
          style: TextStyle(
            fontFamily: AppFonts.headline,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ).animate().fade(duration: const Duration(milliseconds: 300)),
        const SizedBox(height: 8),

        // Slogan
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
        ).animate().fade(
              delay: const Duration(milliseconds: 80),
              duration: const Duration(milliseconds: 300),
            ),
      ],
    );
  }

  Widget _buildOfflineBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: AppRadii.mdRadius,
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.loginOfflineError,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: const Duration(milliseconds: 250));
  }

  Widget _buildPrimaryAction(ColorScheme scheme) {
    return AuthPrimaryButton(
      label: context.l10n.loginSignInWithNiosId,
      icon: Icons.all_inclusive_rounded,
      isLoading: _isStartingAuth,
      onPressed: (_isStartingAuth || _isExchanging) ? null : _startNiosIdAuth,
    ).animate().fade(
          delay: const Duration(milliseconds: 120),
          duration: const Duration(milliseconds: 300),
        );
  }

  Widget _buildSecondaryAction() {
    return AuthPrimaryButton(
      label: context.l10n.loginCreateNiosId,
      isTonal: true,
      onPressed: (_isStartingAuth || _isExchanging)
          ? null
          : () {
              HapticService.tap();
              OAuthNavigationHelper().openRegistration();
            },
    ).animate().fade(
          delay: const Duration(milliseconds: 160),
          duration: const Duration(milliseconds: 300),
        );
  }

  Widget _buildExplainerSection(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: context.l10n.loginWhatIsNiosId,
          expanded: _isExplainerExpanded,
          child: InkWell(
            onTap: () {
              HapticService.tap();
              setState(() {
                _isExplainerExpanded = !_isExplainerExpanded;
              });
            },
            borderRadius: AppRadii.lgRadius,
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.loginWhatIsNiosId,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExplainerExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 280),
                      curve: M3SpringCurves.spatial,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        _buildExplainerPillar(
                          icon: Icons.badge_outlined,
                          title: context.l10n.loginExplainerPillar1Title,
                          desc: context.l10n.loginExplainerPillar1Desc,
                          scheme: scheme,
                        ),
                        const SizedBox(height: 12),
                        _buildExplainerPillar(
                          icon: Icons.lock_outline_rounded,
                          title: context.l10n.loginExplainerPillar2Title,
                          desc: context.l10n.loginExplainerPillar2Desc,
                          scheme: scheme,
                        ),
                        const SizedBox(height: 12),
                        _buildExplainerPillar(
                          icon: Icons.shield_outlined,
                          title: context.l10n.loginExplainerPillar3Title,
                          desc: context.l10n.loginExplainerPillar3Desc,
                          scheme: scheme,
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _isExplainerExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                  sizeCurve: M3SpringCurves.spatial,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).animate().fade(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 300),
        );
  }

  Widget _buildExplainerPillar({
    required IconData icon,
    required String title,
    required String desc,
    required ColorScheme scheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: AppRadii.smRadius,
          ),
          child: Icon(
            icon,
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCodeCard(ColorScheme scheme, TextTheme textTheme) {
    final NiosDeviceCodeResponse resp = _deviceCodeResponse!;
    final bool isExpired = _remainingSeconds <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.lgRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status Bar & Countdown Timer ────────────────────────────
          Row(
            children: [
              if (!isExpired) ...[
                AppLoadingIndicator(size: 16, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.loginWaitingBrowserConfirmation,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.timer_off_outlined,
                  size: 18,
                  color: scheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.loginCodeExpired,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.error,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired
                      ? scheme.errorContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: AppRadii.fullRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: isExpired
                          ? scheme.onErrorContainer
                          : scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isExpired
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isExpired) ...[
            // ── Expired State ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 48,
                    color: scheme.error.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.loginCodeExpired,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            AuthPrimaryButton(
              label: context.l10n.loginGetNewCode,
              icon: Icons.refresh_rounded,
              onPressed: _startNiosIdAuth,
            ),
          ] else ...[
            // ── Active Code Flow: QR + Code Box ───────────────────────
            Text(
              context.l10n.loginConfirmDesc,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // High-contrast clean QR Code container
            Center(
              child: Semantics(
                image: true,
                label: context.l10n.loginScanQrToSignIn,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.mdRadius,
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: QrImageView(
                    data: resp.verificationUriComplete,
                    version: QrVersions.auto,
                    size: 160,
                    padding: EdgeInsets.zero,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF151515),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF151515),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.loginScanQrToSignIn,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // High-contrast copyable Code Box
            Semantics(
              button: true,
              label: '${context.l10n.loginCodeCopied}: ${resp.userCode}',
              child: Tooltip(
                message: context.l10n.loginCodeCopied,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: resp.userCode));
                      HapticService.tap();
                      AppToast.showSuccess(context, context.l10n.loginCodeCopied);
                    },
                    borderRadius: AppRadii.mdRadius,
                    child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: AppRadii.mdRadius,
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
            ),
          ),
        ),
        const SizedBox(height: 18),

            // Primary confirmation in browser button
            AuthPrimaryButton(
              label: context.l10n.loginConfirmInBrowser,
              icon: Icons.open_in_browser_rounded,
              onPressed: () {
                HapticService.tap();
                OAuthNavigationHelper()
                    .openInBrowser(resp.verificationUriComplete);
              },
            ),
          ],
          const SizedBox(height: 8),

          // Cancel Action
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
    ).animate().scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: const Duration(milliseconds: 300),
          curve: M3SpringCurves.spatial,
        ).fade(duration: const Duration(milliseconds: 250));
  }

  Widget _buildLegalFooter(ColorScheme scheme, TextTheme textTheme) {
    // Strictly legal links only — NO build version or channel in footer per user specification.
    return Column(
      mainAxisSize: MainAxisSize.min,
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
              onTap: () {
                HapticService.tap();
                context.push('/legal/terms');
              },
              borderRadius: AppRadii.smRadius,
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
              onTap: () {
                HapticService.tap();
                context.push('/legal/privacy');
              },
              borderRadius: AppRadii.smRadius,
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
    ).animate().fade(
          delay: const Duration(milliseconds: 240),
          duration: const Duration(milliseconds: 300),
        );
  }
}
