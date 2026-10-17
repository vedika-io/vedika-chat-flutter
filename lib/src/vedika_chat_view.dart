import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge_protocol.dart';
import 'chat_config.dart';
import 'chat_event.dart';
import 'chat_load.dart';
import 'chat_offline_view.dart';
import 'errors.dart';
import 'redactor.dart';
import 'vedika_chat_controller.dart';

/// Hosts the chat bundle inside a `WebView`.
///
/// The bundle is the hosted loader from [VedikaChatConfig.loaderUrl], fetched
/// from the network every time the chat opens, so a chat update reaches the
/// app with no app-store release. If that fetch fails (offline, DNS, TLS, an
/// HTTP error or a timeout) the view shows [VedikaChatOfflineView] with a
/// Retry button, and Retry fetches the hosted loader again with the WebView
/// cache cleared. A loader that is bundled inside the app (a non-network
/// `loaderUrl`) is the explicit opt-in to pinning and never shows it.
///
/// The widget must be created with a [VedikaChatController]; that
/// controller's `VedikaTokenProvider` is what the bundle calls when it
/// needs a credential. Lifecycle events posted by the bundle arrive on
/// the controller's `events` stream.
///
/// The widget owns the [WebViewController] and tears it down on dispose.
/// Navigation outside the configured `loaderUrl` host is denied (see
/// `bridge_protocol.dart`). The widget also respects safe-area insets
/// and forwards theme tokens into the host page as CSS variables.
class VedikaChatView extends StatefulWidget {
  const VedikaChatView({
    super.key,
    required this.controller,
    required this.config,
    this.onEvent,
  });

  final VedikaChatController controller;
  final VedikaChatConfig config;
  final void Function(VedikaChatEvent event)? onEvent;

  @override
  State<VedikaChatView> createState() => _VedikaChatViewState();

  /// Build the HTML host page the WebView loads. Exposed for tests so
  /// the redaction guarantee can be verified without spinning up a
  /// real WebView.
  @visibleForTesting
  static String bootstrapHtml(VedikaChatConfig config) {
    final loader = config.loaderUrl.toString();
    final endUserId = _escapeAttr(config.endUserId);
    final threadId =
        config.threadId == null ? '' : _escapeAttr(config.threadId!);
    final contextJson =
        jsonEncode(config.context).replaceAll('</', '<\\/');
    final themeCss = config.theme.toCss();
    // Only a loader fetched over the network can fail for lack of one; a
    // bundled loader gets no offline wiring (see VedikaChatConfig).
    final hosted = config.isHostedLoader;
    final loaderHandlers = hosted
        ? " onerror=\"window.vedika.reportLoadFailed('error')\""
              " onload=\"window.vedika.reportLoaderLoaded()\""
        : '';
    final loadWatch = hosted
        ? '''
  // Report a hosted-loader failure once, and a loader that never finishes
  // after the timeout. The payload is a coarse reason only: no URL, no token.
  var loadTimer = setTimeout(function () {
    window.vedika.reportLoadFailed('timeout');
  }, ${kHostedLoadTimeout.inMilliseconds});
  window.vedika.reportLoadFailed = function (reason) {
    clearTimeout(loadTimer);
    post({ type: '$kMsgLoadFailed', reason: reason === 'timeout' ? 'timeout' : 'error' });
  };
  window.vedika.reportLoaderLoaded = function () {
    clearTimeout(loadTimer);
  };
'''
        : '';
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
<title>Vedika chat</title>
<style>
$themeCss
  html, body { margin: 0; padding: 0; height: 100%; background: var(--vedika-bg); color: var(--vedika-fg); font-family: var(--vedika-font); }
  vedika-chat { display: block; height: 100%; }
</style>
</head>
<body>
<vedika-chat
  data-loader-src="$loader"
  data-end-user-id="$endUserId"
  data-thread-id="$threadId"
></vedika-chat>
<script>
window.vedika = window.vedika || {};
window.vedika.acceptToken = function (payload) {
  // The bundle reads the token straight off the payload. The wrapper
  // never embeds it in a URL, a developer-tools log, or anywhere else.
  window.__vedikaLastToken = payload && payload.token || '';
  window.${kVedikaBridgeChannel} && window.${kVedikaBridgeChannel}.postMessage(
    JSON.stringify({ type: '${kMsgSendResult}', ok: true })
  );
};
window.vedika.requestToken = function (origin) {
  window.${kVedikaBridgeChannel} && window.${kVedikaBridgeChannel}.postMessage(
    JSON.stringify({ type: '${kMsgReady}', origin: origin || 'flutter' })
  );
};
window.vedika.context = $contextJson;
(function () {
  function post(obj) {
    window.${kVedikaBridgeChannel} && window.${kVedikaBridgeChannel}.postMessage(JSON.stringify(obj));
  }
  window.vedika.reportFinish = function (messageId) {
    post({ type: '${kMsgFinish}', messageId: messageId || '' });
  };
  window.vedika.reportCancel = function () {
    post({ type: '${kMsgCancel}' });
  };
  window.vedika.reportError = function (code, message) {
    post({ type: '${kMsgError}', code: code || 'unknown', message: message || '' });
  };
  window.vedika.reportTokenExpired = function () {
    post({ type: '${kMsgTokenExpired}' });
  };
$loadWatch})();
</script>
<script src="$loader" async$loaderHandlers></script>
</body>
</html>
''';
  }

  /// Escape a string for use as an HTML attribute value. The only
  /// characters that need to be escaped in our bootstrap HTML are
  /// `&`, `"` and `<`; everything else is safe inside double quotes.
  static String _escapeAttr(String value) {
    final amp = String.fromCharCode(0x26);
    final ampEntity = String.fromCharCodes(const [0x26, 0x61, 0x6d, 0x70, 0x3b]);
    final quot = String.fromCharCode(0x22);
    final quotEntity = String.fromCharCodes(const [0x26, 0x71, 0x75, 0x6f, 0x74, 0x3b]);
    final lt = String.fromCharCode(0x3c);
    final ltEntity = String.fromCharCodes(const [0x26, 0x6c, 0x74, 0x3b]);
    return value
        .replaceAll(amp, ampEntity)
        .replaceAll(quot, quotEntity)
        .replaceAll(lt, ltEntity);
  }
}

class _VedikaChatViewState extends State<VedikaChatView> {
  late final WebViewController _web;
  VedikaChatLoadState _loadState = const VedikaChatLoadState();
  bool _firstReady = false;
  StreamSubscription<VedikaChatEvent>? _eventSub;
  StreamSubscription<String>? _tokenSub;

  @override
  void initState() {
    super.initState();
    // One WebViewController for the life of the state. Building it in
    // `build` would reload the chat on every rebuild, including the one
    // that swaps the offline screen back for the WebView.
    _web = _createController();
    _eventSub = widget.controller.events.listen(_onStreamedEvent);
    _tokenSub = widget.controller.tokenUpdates.listen(_postToken);
    widget.controller.open(widget.config);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant VedikaChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _firstReady = false;
      _loadState = _loadState.onReset();
      widget.controller.open(widget.config);
      _load();
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  WebViewController _createController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_onPageFinished()),
          onNavigationRequest: (request) {
            final cfg = widget.config;
            final allow = shouldAllowNavigation(
              url: request.url,
              loaderUri: cfg.loaderUrl,
              extraAllowedHosts: cfg.allowedOrigins,
            );
            return allow ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          // Main-frame network failures: no connection, DNS, TLS, timeout.
          // Sub-resource failures (images, requests made by the chat) are
          // not reported here as failures; see isHostedLoadError.
          onWebResourceError: (error) {
            if (isHostedLoadError(
              isForMainFrame: error.isForMainFrame,
              url: error.url,
              hostedUrl: widget.config.loaderUrl,
            )) {
              _markFailed();
            }
          },
          // HTTP status >= 400 on the hosted URL itself.
          onHttpError: (error) {
            if (isHostedHttpFailure(
              statusCode: error.response?.statusCode,
              requestUri: error.request?.uri,
              hostedUrl: widget.config.loaderUrl,
            )) {
              _markFailed();
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        kVedikaBridgeChannel,
        onMessageReceived: (message) => unawaited(_onBridge(message.message)),
      );
  }

  void _onStreamedEvent(VedikaChatEvent event) {
    if (!mounted) return;
    widget.onEvent?.call(event);
    if (event is VedikaChatTokenExpired) {
      unawaited(_refreshAndPost());
    }
  }

  Future<void> _refreshAndPost() async {
    try {
      final token = await widget.controller.refreshToken();
      if (mounted) _postToken(token);
    } on VedikaChatException catch (_) {
      // The tokenProvider surfaces its own errors; do not let them
      // bubble up to the widget tree.
    }
  }

  void _postToken(String token) {
    // The token is posted into the bundle via `acceptToken`. We never
    // embed it in a URL, in a console.log, or in the host page's DOM
    // outside the channel envelope. The redactor is run on the JSON
    // envelope as a defence-in-depth measure so a future regression
    // that accidentally echoes the token is still safe.
    final payload = jsonEncode({
      'source': kTokenSourceFlutter,
      'token': redactToken(token),
    });
    _web.runJavaScript(
      'window.vedika && window.vedika.acceptToken(${jsonEncode(payload)});',
    );
  }

  /// The hosted loader could not be fetched. Only meaningful for a loader
  /// served over the network; a bundled loader never uses the offline screen.
  void _markFailed() {
    if (!mounted || !widget.config.isHostedLoader) return;
    final next = _loadState.onFailed();
    if (next != _loadState) setState(() => _loadState = next);
  }

  void _markLoaded() {
    if (!mounted) return;
    final next = _loadState.onLoaded();
    if (next != _loadState) setState(() => _loadState = next);
  }

  /// Retry: back to the WebView, with the WebView cache cleared so the hosted
  /// loader is fetched from the network, never from a cached copy. The same
  /// hosted loader URL from the config is loaded; no bundled copy is used.
  Future<void> _retry() async {
    if (!mounted || _loadState.status != VedikaChatLoadStatus.failed) return;
    setState(() => _loadState = _loadState.onRetry());
    _firstReady = false;
    try {
      await _web.clearCache();
    } catch (_) {
      // A platform that cannot clear the cache still retries the load.
    }
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    Widget body = _loadState.status == VedikaChatLoadStatus.failed
        ? VedikaChatOfflineView(onRetry: () => unawaited(_retry()))
        : WebViewWidget(controller: _web);
    if (cfg.respectSafeArea) {
      body = SafeArea(
        left: true,
        right: true,
        top: true,
        bottom: cfg.safeAreaBottom,
        child: body,
      );
    }
    return body;
  }

  Future<void> _load() async {
    final cfg = widget.config;
    final html = VedikaChatView.bootstrapHtml(cfg);
    await _web.loadHtmlString(html, baseUrl: cfg.loaderUrl.toString());
  }

  Future<void> _onPageFinished() async {
    if (_firstReady) return;
    _firstReady = true;
    unawaited(_refreshAndPost());
  }

  Future<void> _onBridge(String raw) async {
    Map<String, Object?> data;
    try {
      final decoded = jsonDecode(raw);
      data = (decoded as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    final type = data['type'];
    switch (type) {
      case kMsgReady:
        _markLoaded();
        widget.controller.reportEvent(const VedikaChatReady());
      case kMsgLoadFailed:
        _markFailed();
      case kMsgTokenExpired:
        widget.controller.reportEvent(const VedikaChatTokenExpired());
      case kMsgFinish:
        widget.controller.reportEvent(VedikaChatFinish(
          (data['messageId'] as String?) ?? '',
        ));
      case kMsgCancel:
        widget.controller.reportEvent(const VedikaChatCancel());
      case kMsgError:
        widget.controller.reportEvent(VedikaChatError(
          (data['code'] as String?) ?? 'unknown',
          redactToken((data['message'] as String?) ?? 'bundle error'),
        ));
      case kMsgSendResult:
        widget.controller.reportEvent(
          VedikaChatSendResult(ok: (data['ok'] as bool?) ?? true),
        );
    }
  }
}
