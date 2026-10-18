import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pulse_flutter/core/localization/l10n.dart';
import 'package:pulse_flutter/core/theme/app_theme.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';
import 'package:pulse_flutter/widgets/app_logo_mark.dart';
import 'package:pulse_flutter/widgets/pulse_loading_indicator.dart';

/// Paints a first frame before local storage and other bootstrap work begin.
/// The application subtree is mounted only after initialization succeeds.
class AppStartupGate extends StatefulWidget {
  const AppStartupGate({
    required this.initialize,
    required this.child,
    this.onError,
    super.key,
  });

  final Future<void> Function() initialize;
  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  bool _initializing = false;
  bool _ready = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted || _initializing || _ready) return;
    setState(() {
      _initializing = true;
      _hasError = false;
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    // Keep the reporter for this attempt even if the parent later rebuilds.
    final report = widget.onError;
    try {
      await widget.initialize();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _ready = true;
      });
    } catch (error, stackTrace) {
      try {
        report?.call(error, stackTrace);
      } catch (_) {
        // A diagnostic callback must not make a recoverable bootstrap error
        // unhandled or prevent the user from retrying.
        debugPrint('AppStartupGate error reporter failed');
      }
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    // Do not read providers, preferences, or plugins before bootstrap succeeds.
    final visualTheme = const UiSettingsState.defaults().visualTheme;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.themed(visualTheme, Brightness.light),
      darkTheme: AppTheme.themed(visualTheme, Brightness.dark),
      home: Builder(
        builder: (context) {
          final l10n = context.l10n;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogoMark(size: 88),
                        const SizedBox(height: 20),
                        Text(
                          l10n.appName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.splashTagline,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (_hasError)
                          Semantics(
                            liveRegion: true,
                            child: Material(
                              color: scheme.errorContainer,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: scheme.onErrorContainer,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.splashInitError,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: scheme.onErrorContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.splashInitErrorSubtitle,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: scheme.onErrorContainer,
                                          ),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: _initializing ? null : _start,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(l10n.commonRetry),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const AppLoadingIndicator(size: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
