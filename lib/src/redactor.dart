/// Redaction helpers used everywhere a token-shaped string could
/// cross a log, error or URL boundary.
///
/// The wrapper's promise is that a
/// resolved token never appears in a `debugPrint`, an exception
/// message, or a WebView URL. These helpers enforce that invariant
/// at the point where the string is about to leave the wrapper, and
/// tests pin the behaviour with a known sample token.
library;

/// Recognised token shapes:
///   - `vt_<alnum>` (the documented Vedika embed-token prefix)
///   - `eyJ...` (any base64-prefixed JWT, three segments of
///     `[-_a-zA-Z0-9]+.`)
final RegExp _vtRe = RegExp(r'vt_[A-Za-z0-9_\-]+');
final RegExp _jwtRe = RegExp(
  r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
);

/// Token-shaped placeholder used in redactions. Kept stable so logs
/// can be grep'd.
const String kTokenPlaceholder = 'vt_[redacted]';
const String kJwtPlaceholder = 'eyJ[redacted]';

/// Return [value] with any token-shaped substring replaced by a
/// stable placeholder.
String redactToken(String? value) {
  if (value == null) return '';
  return value
      .replaceAll(_vtRe, kTokenPlaceholder)
      .replaceAll(_jwtRe, kJwtPlaceholder);
}

/// Redact a URL so any token-shaped query parameter, fragment or
/// path segment is replaced with a placeholder.
String redactUrl(String? url) {
  if (url == null) return '';
  // Strip known sensitive query parameters first.
  var out = url.replaceAllMapped(
    RegExp(
      r'([?&])(token|access_token|auth|api_key|apikey|session)=([^&#\s]*)',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}${m.group(2)}=[redacted]',
  );
  out = out.replaceAll(_vtRe, kTokenPlaceholder);
  out = out.replaceAll(_jwtRe, kJwtPlaceholder);
  return out;
}

/// Wrap an exception in a redaction-safe message. The wrapper may
/// catch unknown errors from the WebView; this guarantees the
/// returned string is safe to `debugPrint` or surface to the host
/// app.
Object safeError(String prefix, Object error) {
  final inner = error.toString();
  return Exception('$prefix: ${redactToken(inner)}');
}
