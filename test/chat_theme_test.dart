import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  group('VedikaChatTheme', () {
    test('default theme renders CSS variables', () {
      const theme = VedikaChatTheme();
      final css = theme.toCss();
      expect(css, contains('--vedika-bg'));
      expect(css, contains('--vedika-fg'));
      expect(css, contains('--vedika-accent'));
      expect(css, contains('--vedika-radius'));
      expect(css, contains('--vedika-font'));
    });

    test('custom values are reflected in the CSS block', () {
      const theme = VedikaChatTheme(
        background: '#ff0000ff',
        foreground: '#00ff00',
        accent: '#0000ff',
        radius: '4px',
        fontFamily: 'Inter, sans-serif',
      );
      final css = theme.toCss();
      expect(css, contains('--vedika-bg: #ff0000ff'));
      expect(css, contains('--vedika-fg: #00ff00'));
      expect(css, contains('--vedika-accent: #0000ff'));
      expect(css, contains('--vedika-radius: 4px'));
      expect(css, contains('--vedika-font: Inter, sans-serif'));
    });

    test('fromColors produces hex strings from Color values', () {
      final theme = VedikaChatTheme.fromColors(
        background: const Color(0xff112233),
        foreground: const Color(0xff445566),
        accent: const Color(0xff778899),
      );
      final css = theme.toCss();
      expect(css, contains('--vedika-bg: #112233'));
      expect(css, contains('--vedika-fg: #445566'));
      expect(css, contains('--vedika-accent: #778899'));
    });
  });
}
