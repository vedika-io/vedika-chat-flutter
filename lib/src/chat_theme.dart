import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Theme tokens the wrapper injects into the WebView's host page as
/// CSS custom properties. The chat bundle reads them via
/// `var(--vedika-...)` so consumers can restyle the chat shell without
/// shipping a fork of the bundle.
///
/// Defaults are deliberately minimal: the wrapper ships a neutral
/// palette that matches the Vedika chat kit, and overrides come from
/// the host app's theme.
@immutable
class VedikaChatTheme {
  /// Background colour of the chat shell, as an 8-digit hex string
  /// (`#RRGGBBAA`). Defaults to fully transparent so the host app's
  /// surface colour shows through.
  final String background;

  /// Foreground / primary text colour, as a 6-digit hex string
  /// (`#RRGGBB`). Used for the chat surface's text contrast.
  final String foreground;

  /// Accent colour used by the bundle's interactive affordances
  /// (send button, focus ring). 6-digit hex.
  final String accent;

  /// Corner radius (in CSS units) applied to chat surfaces. Default
  /// `12px` matches the Vedika chat kit.
  final String radius;

  /// Font stack passed to the bundle. Defaults to the system stack
  /// on iOS / Android.
  final String fontFamily;

  const VedikaChatTheme({
    this.background = '#00000000',
    this.foreground = '#1f2937',
    this.accent = '#7c3aed',
    this.radius = '12px',
    this.fontFamily =
        "-apple-system, system-ui, 'Segoe UI', Roboto, sans-serif",
  });

  /// Construct a theme from a Flutter [Color].
  ///
  /// The wrapper does its best to translate the colours into the
  /// CSS variables the bundle expects, but the consumer is free to
  /// ignore this helper and pass a hand-built [VedikaChatTheme].
  factory VedikaChatTheme.fromColors({
    required Color background,
    required Color foreground,
    required Color accent,
    String radius = '12px',
    String fontFamily =
        "-apple-system, system-ui, 'Segoe UI', Roboto, sans-serif",
  }) {
    return VedikaChatTheme(
      background: _hex8(background),
      foreground: _hex6(foreground),
      accent: _hex6(accent),
      radius: radius,
      fontFamily: fontFamily,
    );
  }

  /// Render the theme as a CSS `:root { ... }` block. The wrapper
  /// injects this string into the host page's `<style>` so the
  /// bundle can read `var(--vedika-bg)` etc.
  String toCss() {
    return '''
:root {
  --vedika-bg: ${background};
  --vedika-fg: ${foreground};
  --vedika-accent: ${accent};
  --vedika-radius: ${radius};
  --vedika-font: ${fontFamily};
}
''';
  }

  static String _hex6(Color c) {
    final r = ((c.r * 255.0).round()) & 0xff;
    final g = ((c.g * 255.0).round()) & 0xff;
    final b = ((c.b * 255.0).round()) & 0xff;
    return '#${_pad2(r)}${_pad2(g)}${_pad2(b)}';
  }

  static String _hex8(Color c) {
    final a = ((c.a * 255.0).round()) & 0xff;
    return '${_hex6(c)}${_pad2(a)}';
  }

  static String _pad2(int v) => v.toRadixString(16).padLeft(2, '0');
}
