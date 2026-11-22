import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/call_design_tokens.dart';
import 'package:pulse_flutter/core/theme/app_surfaces.dart';

void main() {
  test('call surfaces mirror the dark ladder of AppSurfaces', () {
    final ColorScheme dark = AppSurfaces.neutralize(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
    );

    expect(CallTokens.darkSurface, dark.surface);
    expect(CallTokens.darkSurfaceContainerHigh, dark.surfaceContainerHigh);
    expect(
      CallTokens.darkSurfaceContainerHighest,
      dark.surfaceContainerHighest,
    );
    expect(CallTokens.onDarkSurface, dark.onSurface);
  });
}
