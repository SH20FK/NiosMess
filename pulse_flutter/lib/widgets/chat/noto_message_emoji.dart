import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:pulse_flutter/core/media/media_playback_visibility.dart';
import 'package:pulse_flutter/core/motion/m3_spring_constants.dart';
import 'package:pulse_flutter/core/performance/adaptive_performance_provider.dart';
import 'package:pulse_flutter/core/utils/noto_emoji.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

typedef _AssetKey = (AssetBundle, String);

/// Vector compositions have their own small cache, separate from video codecs.
final class _NotoCompositionCache extends ChangeNotifier {
  static final instance = _NotoCompositionCache();
  final _ready = <_AssetKey, LottieComposition>{};
  final _pending = <_AssetKey, Future<LottieComposition?>>{};
  bool _notificationPending = false;

  void _notifyLater() {
    if (_notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      notifyListeners();
    });
  }

  Future<LottieComposition?> load(AssetBundle bundle, String path) {
    final key = (bundle, path);
    final ready = _ready.remove(key);
    if (ready != null) {
      _ready[key] = ready;
      return Future.value(ready);
    }
    final pending = _pending[key];
    if (pending != null) return pending;
    // Do not launch an isolate for every cached list child at once.
    if (_pending.length >= 2) return Future.value();
    final future = _decode(bundle, path, key);
    _pending[key] = future;
    return future;
  }

  Future<LottieComposition?> _decode(
    AssetBundle bundle,
    String path,
    _AssetKey key,
  ) async {
    final provider = AssetLottie(
      path,
      bundle: bundle,
      backgroundLoading: true,
      decoder: LottieComposition.decodeGZip,
    );
    try {
      final composition = await provider.load();
      while (_ready.length >= 12) {
        _ready.remove(_ready.keys.first);
      }
      _ready[key] = composition;
      return composition;
    } finally {
      // The provider also loads embedded images/fonts. Keep that behavior but
      // do not retain these assets in Lottie's unrelated 1000-entry cache.
      Lottie.cache.evict(provider);
      _pending.remove(key);
      _notifyLater();
    }
  }
}

final class _NotoPlaybackBudget extends ChangeNotifier {
  static final instance = _NotoPlaybackBudget();
  final _playing = <Object>{};
  bool _notificationPending = false;

  bool acquire(Object token, PerformanceTier tier) {
    final maximum = switch (tier) {
      PerformanceTier.tierA => 2,
      PerformanceTier.tierB => 1,
      PerformanceTier.tierC => 0,
    };
    if (_playing.contains(token)) {
      return _playing.take(maximum).contains(token);
    }
    if (_playing.length >= maximum) return false;
    _playing.add(token);
    return true;
  }

  void release(Object token) {
    if (!_playing.remove(token) || _notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      notifyListeners();
    });
  }
}

/// Finite, local Noto animation with a permanent Unicode/font fallback.
class NotoMessageEmoji extends ConsumerStatefulWidget {
  const NotoMessageEmoji({required this.emoji, this.size = 112, super.key});

  final NotoEmoji emoji;
  final double size;

  @override
  ConsumerState<NotoMessageEmoji> createState() => _NotoMessageEmojiState();
}

class _NotoMessageEmojiState extends ConsumerState<NotoMessageEmoji>
    with TickerProviderStateMixin {
  final _token = Object();
  final _budget = _NotoPlaybackBudget.instance;
  final _cache = _NotoCompositionCache.instance;
  late final AnimationController _animation;
  late final AnimationController _spring;
  ProviderSubscription<UiSettingsState>? _settingsSubscription;
  ProviderSubscription<AdaptivePerformanceState>? _performanceSubscription;
  ScrollPosition? _scrollPosition;
  AssetBundle? _bundle;
  LottieComposition? _composition;
  bool _visible = false;
  bool _reducedMotion = false;
  bool _loading = false;
  bool _assetFailed = false;
  bool _requested = true;
  bool _started = false;
  bool _showAnimation = false;
  bool _disposing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this)..addStatusListener(_onStatus);
    _spring = AnimationController(
      vsync: this,
      duration: M3Durations.medium1,
      value: 1,
    );
    _budget.addListener(_syncPlayback);
    _cache.addListener(_syncPlayback);
    _settingsSubscription = ref.listenManual(uiSettingsProvider, (old, next) {
      if (old?.animateEmoji != next.animateEmoji) _syncPlayback();
    });
    _performanceSubscription = ref.listenManual(adaptivePerformanceProvider, (
      old,
      next,
    ) {
      if (old?.tier != next.tier ||
          old?.isDegraded != next.isDegraded ||
          old?.isPaused != next.isPaused) {
        _syncPlayback();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != position) {
      _scrollPosition?.isScrollingNotifier.removeListener(_syncPlayback);
      _scrollPosition = position;
      position?.isScrollingNotifier.addListener(_syncPlayback);
    }
    final bundle = DefaultAssetBundle.of(context);
    if (_bundle != bundle) {
      _bundle = bundle;
      _reset();
    }
    _syncPlayback();
  }

  bool get _motionAllowed {
    final performance = ref.read(adaptivePerformanceProvider);
    return !_reducedMotion &&
        ref.read(uiSettingsProvider).animateEmoji &&
        performance.tier != PerformanceTier.tierC &&
        !performance.isDegraded &&
        !performance.isPaused;
  }

  void _onVisibilityChanged(bool visible) {
    _visible = visible;
    if (!visible) _reset();
    _syncPlayback();
  }

  void _reset() {
    _generation++;
    _composition = null;
    _loading = false;
    _assetFailed = false;
    _requested = true;
    _started = false;
    _animation.stop();
    _spring.value = 1;
    _budget.release(_token);
    _setShowing(false);
  }

  void _setShowing(bool value) {
    if (_showAnimation == value || !mounted || _disposing) return;
    setState(() => _showAnimation = value);
  }

  void _syncPlayback() {
    if (!mounted || _disposing) return;
    final allowed =
        _visible &&
        _motionAllowed &&
        !(_scrollPosition?.isScrollingNotifier.value ?? false);
    if (!allowed || !_requested || widget.emoji.animationAsset == null) {
      _animation.stop();
      _spring.value = 1;
      _budget.release(_token);
      _setShowing(false);
      return;
    }
    if (_composition == null) {
      if (!_loading && !_assetFailed) unawaited(_load());
      return;
    }
    if (!_budget.acquire(_token, ref.read(adaptivePerformanceProvider).tier)) {
      _animation.stop();
      _setShowing(false);
      _budget.release(_token);
      return;
    }
    _setShowing(true);
    if (!_animation.isAnimating) {
      if (_started) {
        unawaited(_animation.forward());
      } else {
        _started = true;
        unawaited(_animation.forward(from: 0));
      }
    }
  }

  Future<void> _load() async {
    final generation = _generation;
    final path = widget.emoji.animationAsset;
    final bundle = _bundle;
    if (path == null || bundle == null) return;
    _loading = true;
    try {
      final composition = await _cache.load(bundle, path);
      if (!mounted || generation != _generation) return;
      _composition = composition;
      if (composition != null) _animation.duration = composition.duration;
    } catch (_) {
      if (generation == _generation) _assetFailed = true;
      // A missing/corrupt animation always leaves the exact Unicode visible.
    } finally {
      if (generation == _generation) {
        _loading = false;
        if (_composition != null) _syncPlayback();
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _requested = false;
    _budget.release(_token);
    _setShowing(false);
  }

  void _replay() {
    if (!_visible ||
        !_motionAllowed ||
        (_scrollPosition?.isScrollingNotifier.value ?? false) ||
        widget.emoji.animationAsset == null) {
      return;
    }
    _requested = true;
    _started = false;
    _animation.stop();
    _syncPlayback();
    unawaited(_spring.forward(from: 0));
  }

  @override
  void didUpdateWidget(covariant NotoMessageEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji.unicode != widget.emoji.unicode) {
      _reset();
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    _disposing = true;
    _generation++;
    _settingsSubscription?.close();
    _performanceSubscription?.close();
    _scrollPosition?.isScrollingNotifier.removeListener(_syncPlayback);
    _budget.removeListener(_syncPlayback);
    _cache.removeListener(_syncPlayback);
    _budget.release(_token);
    _animation.dispose();
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MediaPlaybackVisibility(
    onChanged: _onVisibilityChanged,
    child: Semantics(
      label: widget.emoji.unicode,
      excludeSemantics: true,
      button: widget.emoji.hasAnimation,
      onTap: widget.emoji.hasAnimation ? _replay : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.emoji.hasAnimation ? _replay : null,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _spring,
            builder: (context, child) => Transform.scale(
              scale:
                  1 +
                  0.12 * (1 - M3SpringCurves.snappy.transform(_spring.value)),
              child: child,
            ),
            child: SizedBox.square(
              dimension: widget.size,
              child: _showAnimation && _composition != null
                  ? Lottie(
                      composition: _composition,
                      controller: _animation,
                      repeat: false,
                      animate: false,
                      frameRate: const FrameRate(60),
                      fit: BoxFit.contain,
                      addRepaintBoundary: false,
                    )
                  : Center(
                      child: Text(
                        widget.emoji.unicode,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          inherit: false,
                          fontFamily: NotoEmoji.fontFamily,
                          // Color-font ink can extend beyond the glyph advance.
                          // Leave room so wide faces stay inside the bubble.
                          fontSize: widget.size * 0.90,
                          height: 1,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
