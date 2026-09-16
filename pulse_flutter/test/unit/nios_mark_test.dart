import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_flutter/core/identity/nios_mark.dart';

void main() {
  group('NiosMark Generative Identity Engine (NM)', () {
    test('Deterministic generation guarantees identical marks for same user ID', () {
      final mark1 = NiosMark.generate('user_4291', brightness: Brightness.dark, name: 'Alice Walker');
      final mark2 = NiosMark.generate('user_4291', brightness: Brightness.dark, name: 'Alice Walker');

      expect(mark1.id, equals('user_4291'));
      expect(mark1.seed, equals(mark2.seed));
      expect(mark1.color, equals(mark2.color));
      expect(mark1.accentColor, equals(mark2.accentColor));
      expect(mark1.shape, equals(mark2.shape));
      expect(mark1.tiltDegrees, equals(mark2.tiltDegrees));
      expect(mark1.monogram, equals('AW'));
      expect(mark1, equals(mark2));
    });

    test('Different user IDs generate distinct shapes or colors', () {
      final markA = NiosMark.generate('user_101', brightness: Brightness.light, name: 'Bob Dylan');
      final markB = NiosMark.generate('user_999', brightness: Brightness.light, name: 'Charlie Parker');

      expect(markA.seed, isNot(equals(markB.seed)));
      expect(markA.monogram, equals('BD'));
      expect(markB.monogram, equals('CP'));
    });

    test('Monogram extraction handles diverse naming inputs robustly', () {
      expect(NiosMark.extractMonogram('John Doe'), equals('JD'));
      expect(NiosMark.extractMonogram('Antigravity'), equals('AN'));
      expect(NiosMark.extractMonogram('SingleWord'), equals('SI'));
      expect(NiosMark.extractMonogram(''), equals('N'));
      expect(NiosMark.extractMonogram('   '), equals('N'));
    });

    test('resolveColor provides deterministic accessible colors for light and dark themes', () {
      const lightScheme = ColorScheme.light();
      const darkScheme = ColorScheme.dark();

      final lightColor1 = NiosMark.resolveColor('user_123', lightScheme);
      final lightColor2 = NiosMark.resolveColor('user_123', lightScheme);
      final darkColor = NiosMark.resolveColor('user_123', darkScheme);

      expect(lightColor1, equals(lightColor2));
      expect(lightColor1, isNot(equals(darkColor)));
    });
  });
}
