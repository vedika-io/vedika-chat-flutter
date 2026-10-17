/// Constants for the cross-process bridge between the wrapper and the
/// Vedika chat bundle.
///
/// The chat bundle runs inside the WebView and talks to the wrapper
/// over a single JavaScript channel. The names below are the public
/// wire; tests pin them so a rename is impossible without a bump.
///
/// The React Native, iOS and Android wrappers expose the same surface.
library;

/// Name of the JavaScript channel the wrapper registers on the
/// WebView. The bundle calls `window.<channel>.postMessage(...)` and
/// the wrapper receives the message via `onMessageReceived`.
const String kVedikaBridgeChannel = 'VedikaBridge';

/// Discriminator values the bundle emits. Kept in sync with
/// `chat_event.dart`'s `VedikaChatEvent.kind` strings.
const String kMsgReady = 'ready';
const String kMsgTokenExpired = 'token-expired';
const String kMsgFinish = 'finish';
const String kMsgCancel = 'cancel';
const String kMsgError = 'error';
const String kMsgSendResult = 'send-result';

/// Posted by the wrapper's own host page (not the bundle) when the hosted
/// loader script could not be fetched: offline, DNS, TLS, an HTTP error or
/// a timeout. The payload carries only a coarse `reason` (`error` or
/// `timeout`), never a URL or a token. The view answers with its offline
/// screen; this is not a [VedikaChatEvent].
const String kMsgLoadFailed = 'load-failed';

/// `source` field that the wrapper stamps into the payload it posts
/// back into the bundle (via `window.vedika.acceptToken`).
const String kTokenSourceFlutter = 'flutter.tokenProvider';

/// Default origin allow-list used by the WebView's navigation
/// delegate. The wrapper accepts the loader URL's host and a small
/// set of well-known CDN hosts that the loader script may pull
/// subresources from. Consumers may override this list via
/// [VedikaChatConfig.allowedOrigins].
const List<String> kDefaultAllowedOrigins = <String>[
  // Resolved at navigation time from `VedikaChatConfig.loaderUrl`.
  '__loader_host__',
  'cdn.vedika.io',
  'harness.vedika.io',
  'fonts.gstatic.com',
];

/// Schemes accepted by the navigation delegate. Plain `http` and
/// non-network schemes (file:, blob:, data:) are rejected so a
/// compromised bundle cannot redirect the WebView to a phishing
/// origin.
const Set<String> kAllowedSchemes = <String>{'https'};

/// Return `true` if [host] is on the allow-list [origins].
///
/// The list supports the literal wildcard `*` and exact host matches.
/// A null/empty host is treated as a non-match.
bool isOriginAllowed(String? host, List<String> origins) {
  if (host == null || host.isEmpty) return false;
  for (final o in origins) {
    if (o == '*') return true;
    if (o == host) return true;
  }
  return false;
}

/// Decide whether a navigation request is permitted by the bridge's
/// allowed-origin and allowed-scheme rules. Used by
/// `VedikaChatView._shouldNavigate`.
bool shouldAllowNavigation({
  required String url,
  required Uri loaderUri,
  List<String>? extraAllowedHosts,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (!kAllowedSchemes.contains(uri.scheme)) return false;
  final hosts = <String>[
    loaderUri.host,
    ...kDefaultAllowedOrigins,
    if (extraAllowedHosts != null) ...extraAllowedHosts,
  ];
  return isOriginAllowed(uri.host, hosts);
}
