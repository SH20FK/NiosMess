// The app text size is the system text size multiplied by the in-app font
// size setting, bounded to the range the layouts are tested in.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/app_text_scaler.dart';

/// Scales small type more than large type, like the Android system scaler.
class _NonLinear extends TextScaler {
  const _NonLinear();

  @override
  double scale(double fontSize) => fontSize < 20 ? fontSize * 1.5 : fontSize * 1.2;

  @override
  double get textScaleFactor => 1.5;
}

void main() {
  test('the system size is honoured and multiplied by the app setting', () {
    const AppTextScaler scaler = AppTextScaler(
      system: TextScaler.linear(1.5),
      appScale: 1.15,
    );
    expect(scaler.scale(10), closeTo(17.25, 1e-9));
    expect(scaler.textScaleFactor, closeTo(1.725, 1e-9));
  });

  test('a default system size leaves the app setting alone', () {
    const AppTextScaler scaler = AppTextScaler(
      system: TextScaler.noScaling,
      appScale: 1.3,
    );
    expect(scaler.scale(10), closeTo(13, 1e-9));
  });

  test('the product is bounded on both sides', () {
    // The largest system size with the largest app size stops at 200%.
    expect(
      const AppTextScaler(
        system: TextScaler.linear(2),
        appScale: 1.3,
      ).scale(10),
      10 * AppTextScaler.maxScale,
    );
    expect(
      const AppTextScaler(
        system: TextScaler.linear(0.8),
        appScale: 0.85,
      ).scale(10),
      10 * AppTextScaler.minScale,
    );
  });

  test('a non-linear system scaler stays non-linear', () {
    const AppTextScaler scaler = AppTextScaler(
      system: _NonLinear(),
      appScale: 1,
    );
    expect(scaler.scale(10), closeTo(15, 1e-9));
    expect(scaler.scale(30), closeTo(36, 1e-9));
  });

  test('equal inputs make equal scalers', () {
    const AppTextScaler a = AppTextScaler(
      system: TextScaler.linear(1.5),
      appScale: 1.15,
    );
    const AppTextScaler b = AppTextScaler(
      system: TextScaler.linear(1.5),
      appScale: 1.15,
    );
    const AppTextScaler c = AppTextScaler(
      system: TextScaler.linear(1.5),
      appScale: 1.3,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('clamping for a single widget still works on top of it', () {
    const AppTextScaler scaler = AppTextScaler(
      system: TextScaler.linear(2),
      appScale: 1,
    );
    expect(scaler.clamp(maxScaleFactor: 1.3).scale(10), closeTo(13, 1e-9));
  });
}
