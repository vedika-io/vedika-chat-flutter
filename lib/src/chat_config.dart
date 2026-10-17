import 'chat_load.dart';
import 'chat_theme.dart';

/// The published, hosted Vedika loader. [VedikaChatConfig.loaderUrl] falls
/// back to this, so an app that does not override it receives every chat
/// update without an app-store release.
final Uri kDefaultLoaderUrl = Uri.parse(
  'https://cdn.vedika.io/chat-widget/v1/loader.js',
);

/// Configuration for a single chat session.
class VedikaChatConfig {
  /// Loader URL to load the chat bundle from.
  ///
  /// Defaults to the published, hosted Vedika loader ([kDefaultLoaderUrl]),
  /// which is fetched from the network every time the chat opens. That is
  /// how a chat update reaches every installed app with no app-store
  /// release. Override it per surface (for example to point a staging build
  /// at a different host).
  ///
  /// Plain `http` is refused with an [ArgumentError].
  ///
  /// Passing a file URL for a loader bundled inside the app is the explicit
  /// opt-in to a pinned copy: the app then stops receiving chat updates
  /// until you ship a new app release, and the offline screen is not used
  /// (see [isHostedLoader]).
  final Uri loaderUrl;

  /// Stable identifier for the local end user. Forwarded to the backend
  /// mint and surfaced inside the bundle so threads can be grouped by
  /// identity. Do not put a long-lived secret here.
  final String endUserId;

  /// Optional thread id to resume. When `null` the bundle starts a new
  /// thread.
  final String? threadId;

  /// Extra context passed to the bundle as `window.vedika.context`. Use
  /// for non-PII hints (locale, navigation slot, theme name).
  final Map<String, Object?> context;

  /// Extra hosts the WebView's navigation delegate should allow beyond
  /// the loader URL host and the default CDN allow-list. Use sparingly
  /// — every additional host widens the trust boundary.
  final List<String> allowedOrigins;

  /// Theme tokens injected into the WebView host page. Pass `null` to
  /// use the wrapper's default neutral palette.
  final VedikaChatTheme theme;

  /// Whether the widget should respect the host's safe-area insets
  /// (notch, gesture bar, system navigation). Defaults to `true` so
  /// the chat shell does not draw under the system UI.
  final bool respectSafeArea;

  /// Whether the safe-area inset should also apply to the bottom edge
  /// (e.g. the home indicator on iOS). Defaults to `true`. Hosts that
  /// put the chat inside a `Scaffold` body may disable this to avoid
  /// double-padding.
  final bool safeAreaBottom;

  VedikaChatConfig({
    Uri? loaderUrl,
    required this.endUserId,
    this.threadId,
    this.context = const {},
    this.allowedOrigins = const [],
    this.theme = const VedikaChatTheme(),
    this.respectSafeArea = true,
    this.safeAreaBottom = true,
  }) : loaderUrl = loaderUrl ?? kDefaultLoaderUrl {
    if (isRefusedLoaderUrl(this.loaderUrl)) {
      throw ArgumentError.value(
        this.loaderUrl.scheme,
        'loaderUrl',
        'must be an https URL (or a bundled file: URL for a pinned copy); '
            'plain http is refused',
      );
    }
  }

  /// True when [loaderUrl] is fetched over the network (https), so
  /// a failure to load it can mean "no connection". The view shows its
  /// "Can't reach chat" screen only in that case.
  bool get isHostedLoader => isHostedLoaderUrl(loaderUrl);
}
