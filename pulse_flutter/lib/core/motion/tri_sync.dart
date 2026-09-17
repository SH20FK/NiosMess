import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_flutter/core/sound/app_sound.dart';
import 'package:pulse_flutter/core/utils/haptic_service.dart';
import 'package:pulse_flutter/providers/ui_settings_provider.dart';

/// Event types for [TriSync] multi-channel coordination.
enum TriSyncEvent {
  /// Subtle selection or tap (buttons, chips, list items).
  tap,

  /// Fast snapping (slider steps, segment changes, tab clicks).
  snap,

  /// Threshold crossing, release activation, or action confirmation.
  pop,

  /// Full dismissal or exit transition (sheets, media viewer).
  dismiss,

  /// Celebration or message reaction.
  reaction,

  /// Destructive action (delete, unpair, wipe).
  destructive,
}

/// TriSync: Unified coordinator for motion, haptics, and audio.
///
/// Implements TS from the Wow-Layer specification:
/// - Keyframe-synchronized feedback across tactile, audio, and visual channels.
/// - Built-in debouncer/throttle (minimum 45ms) to prevent haptic motor queue overflow.
/// - Respects user preferences in [uiSettingsProvider] (haptics and soundEffects).
class TriSync {
  TriSync._();

  static final Map<TriSyncEvent, int> _lastTriggerTimes = <TriSyncEvent, int>{};

  /// Minimum interval between two events of the same type to prevent spam.
  static const int kMinThrottleMs = 45;

  /// Triggers a coordinated [TriSyncEvent].
  ///
  /// [ref] is optional: when passed, reads [uiSettingsProvider] and [appSoundProvider].
  /// [force] bypasses the 45ms throttle guard when set to true.
  static void trigger(
    TriSyncEvent event, {
    WidgetRef? ref,
    BuildContext? context,
    bool force = false,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int last = _lastTriggerTimes[event] ?? 0;

    if (!force && (now - last) < kMinThrottleMs) {
      return;
    }
    _lastTriggerTimes[event] = now;

    // Check user settings if ref or context is available
    bool hapticsEnabled = true;
    bool soundEnabled = true;
    SoundService? sound;

    if (ref != null) {
      final UiSettingsState settings = ref.read(uiSettingsProvider);
      hapticsEnabled = settings.haptics;
      soundEnabled = settings.soundEffects;
      sound = ref.read(appSoundProvider);
    } else if (context != null) {
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final UiSettingsState settings = container.read(uiSettingsProvider);
        hapticsEnabled = settings.haptics;
        soundEnabled = settings.soundEffects;
        sound = container.read(appSoundProvider);
      } catch (_) {
        // Fallback when invoked outside ProviderScope
      }
    }

    // 1. Tactile channel
    if (hapticsEnabled) {
      switch (event) {
        case TriSyncEvent.tap:
          HapticService.tap();
          break;
        case TriSyncEvent.snap:
          HapticService.selection();
          break;
        case TriSyncEvent.pop:
          HapticService.confirm();
          break;
        case TriSyncEvent.dismiss:
          HapticService.mediumImpact();
          break;
        case TriSyncEvent.reaction:
          HapticService.reaction();
          break;
        case TriSyncEvent.destructive:
          HapticService.destructive();
          break;
      }
    }

    // 2. Audio channel
    if (soundEnabled && sound != null) {
      switch (event) {
        case TriSyncEvent.tap:
        case TriSyncEvent.snap:
          sound.playUiTick();
          break;
        case TriSyncEvent.pop:
          sound.playReaction();
          break;
        case TriSyncEvent.dismiss:
          sound.play(AppSound.navigation);
          break;
        case TriSyncEvent.reaction:
          sound.play(AppSound.message);
          break;
        case TriSyncEvent.destructive:
          break;
      }
    }
  }

  /// Convenience shortcut for subtle taps.
  static void tap({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.tap, ref: ref, context: context);

  /// Convenience shortcut for slider steps or segment snaps.
  static void snap({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.snap, ref: ref, context: context);

  /// Convenience shortcut for threshold crossings or pop confirmations.
  static void pop({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.pop, ref: ref, context: context);

  /// Convenience shortcut for view dismissals or sheet closes.
  static void dismiss({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.dismiss, ref: ref, context: context);

  /// Convenience shortcut for celebration or message reactions.
  static void reaction({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.reaction, ref: ref, context: context);

  /// Convenience shortcut for destructive actions.
  static void destructive({WidgetRef? ref, BuildContext? context}) =>
      trigger(TriSyncEvent.destructive, ref: ref, context: context);
}
