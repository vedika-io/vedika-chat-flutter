/// Load-state logic for the hosted chat loader.
///
/// Pure Dart: no WebView, no widgets. `VedikaChatView` feeds WebView and
/// bridge events into these helpers, and the tests run them without a device.
///
/// The question answered here is "did the HOSTED chat fail to load?". The host
/// page the WebView opens is generated locally, so the hosted part is the
/// loader script it pulls in. A failed image, analytics call or API request
/// inside the chat never counts.
library;

import 'package:flutter/foundation.dart';

/// Copy shown on the offline screen. No internal terms, no URL.
const String kOfflineHeading = "Can't reach chat";
const String kOfflineBody = 'Check your connection and try again.';
const String kOfflineRetry = 'Retry';

/// How long the host page waits for the hosted loader before it reports a
/// timeout. A load that fails outright (offline, DNS, TLS, HTTP error) is
/// reported at once; this only covers a load that never finishes.
const Duration kHostedLoadTimeout = Duration(seconds: 15);

/// Where the hosted load stands.
enum VedikaChatLoadStatus { loading, ready, failed }

/// Tiny state machine: loading -> ready, any -> failed, failed -> loading.
///
/// `failed` is sticky. A late "loaded" signal (for example the host page
/// finishing after an HTTP error) must never hide the offline screen. Only an
/// explicit [onRetry] or [onReset] leaves it.
@immutable
class VedikaChatLoadState {
  const VedikaChatLoadState({
    this.status = VedikaChatLoadStatus.loading,
    this.attempt = 0,
  });

  final VedikaChatLoadStatus status;

  /// Number of forced reloads so far (Retry, or a changed config).
  final int attempt;

  /// The hosted chat finished loading.
  VedikaChatLoadState onLoaded() => status == VedikaChatLoadStatus.loading
      ? VedikaChatLoadState(status: VedikaChatLoadStatus.ready, attempt: attempt)
      : this;

  /// A hosted-load failure was detected.
  VedikaChatLoadState onFailed() => status == VedikaChatLoadStatus.failed
      ? this
      : VedikaChatLoadState(status: VedikaChatLoadStatus.failed, attempt: attempt);

  /// The user pressed Retry.
  VedikaChatLoadState onRetry() => status == VedikaChatLoadStatus.failed
      ? VedikaChatLoadState(
          status: VedikaChatLoadStatus.loading,
          attempt: attempt + 1,
        )
      : this;

  /// The config changed; start over.
  VedikaChatLoadState onReset() =>
      status == VedikaChatLoadStatus.loading && attempt == 0
          ? this
          : VedikaChatLoadState(
              status: VedikaChatLoadStatus.loading,
              attempt: attempt + 1,
            );

  @override
  bool operator ==(Object other) =>
      other is VedikaChatLoadState &&
      other.status == status &&
      other.attempt == attempt;

  @override
  int get hashCode => Object.hash(status, attempt);

  @override
  String toString() => 'VedikaChatLoadState($status, attempt: $attempt)';
}

/// True when [loaderUrl] is an https URL, so a failure to load it can mean
/// "no connection". A bundled copy (file, asset or data URL) is the explicit
/// opt-in to pinning and never uses the offline screen, because it is already
/// on the device. Plain `http` is neither: [VedikaChatConfig] refuses it
/// (see [isRefusedLoaderUrl]).
bool isHostedLoaderUrl(Uri loaderUrl) => loaderUrl.scheme == 'https';

/// True for a loader URL that must never be loaded: a network scheme that is
/// not https. The chat page carries tokens and user messages, so it is not
/// fetched in the clear.
bool isRefusedLoaderUrl(Uri loaderUrl) {
  final scheme = loaderUrl.scheme;
  return scheme == 'http' || scheme == 'ws' || scheme == 'ftp';
}

/// True when two URLs name the same document: same scheme, host, port and
/// path. Query and fragment are ignored, and a trailing slash does not matter.
bool isSameDocument(Uri a, Uri b) {
  String path(Uri u) {
    var p = u.path.isEmpty ? '/' : u.path;
    if (p.length > 1 && p.endsWith('/')) p = p.substring(0, p.length - 1);
    return p;
  }

  return a.scheme == b.scheme &&
      a.host == b.host &&
      a.port == b.port &&
      path(a) == path(b);
}

/// Decide whether a WebView resource error means "the hosted chat did not
/// load".
///
/// Only main-frame errors count (no network, DNS, TLS, timeout). The
/// platform may omit the URL on a provisional failure (iOS), so an empty URL
/// is accepted; a non-empty URL must be the hosted one, which keeps a failed
/// navigation to some other page, or a sub-resource, from replacing the chat.
bool isHostedLoadError({
  required bool? isForMainFrame,
  required String? url,
  required Uri hostedUrl,
}) {
  if (isForMainFrame != true) return false;
  if (url == null || url.isEmpty) return true;
  final parsed = Uri.tryParse(url);
  return parsed != null && isSameDocument(parsed, hostedUrl);
}

/// Decide whether an HTTP error means "the hosted chat did not load": status
/// 400 or more on the hosted URL itself. Android reports every request,
/// sub-resources included, so the URL must match; iOS reports no URL, so it
/// can never match and is ignored here (the host page's own script-error
/// signal covers iOS).
bool isHostedHttpFailure({
  required int? statusCode,
  required Uri? requestUri,
  required Uri hostedUrl,
}) {
  if (statusCode == null || statusCode < 400) return false;
  return requestUri != null && isSameDocument(requestUri, hostedUrl);
}
