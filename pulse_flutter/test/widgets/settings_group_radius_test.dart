import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/theme/expressive_tokens.dart';
import 'package:pulse_flutter/widgets/settings_ui.dart';

void main() {
  testWidgets('settings group corner follows the whole radius range', (
    WidgetTester tester,
  ) async {
    for (final (double setting, double expected) in <(double, double)>[
      (8, 12),
      (14, 18),
      (20, 24),
      (28, 32),
    ]) {
      late double outer;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<double>(setting),
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[
              AppRadiiTheme.fromCornerRadius(setting),
            ],
          ),
          home: Builder(
            builder: (BuildContext context) {
              outer = SettingsSection.outerRadius(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(outer, expected, reason: 'corner radius setting $setting');
    }
  });
}
