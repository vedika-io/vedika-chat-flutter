# Unreleased

- Minimum toolchain is now Dart 3.8 and Flutter 3.32. The old floor was
  contradictory: Flutter 3.10 ships Dart 3.0, which cannot satisfy
  `sdk: ^3.10.7`. The example app's iOS deployment target is now 15.0.
- Hosted by default: `VedikaChatConfig.loaderUrl` is now optional and
  defaults to the published loader (`kDefaultLoaderUrl`). The doc comment
  already promised this; the parameter used to be required. A bundled
  `file:` loader stays available as the explicit opt-in to a pinned copy,
  and the docs now say it costs an app release for every chat update.
  `VedikaChatConfig` is no longer a `const` constructor (it never could be
  called as one, because `Uri` is not const).
- Plain `http` is refused: `VedikaChatConfig` throws an `ArgumentError`
  for an `http:` loader URL, and `isHostedLoaderUrl` is https only. The
  navigation delegate already refused every scheme but https.
- New offline screen, `VedikaChatOfflineView`: "Can't reach chat", "Check
  your connection and try again." and a Retry button. `VedikaChatView`
  shows it when the hosted loader fails to load (no network, DNS, TLS, an
  HTTP status of 400 or more, or no answer within `kHostedLoadTimeout`,
  15 seconds), never for a sub-resource failure and never for a bundled
  loader. Retry clears the WebView cache and loads the hosted loader again.
- New bridge message `load-failed` (`kMsgLoadFailed`), posted by the
  wrapper's own host page. It carries only a coarse reason.
- New pure helpers in `chat_load.dart`: `VedikaChatLoadState`,
  `isHostedLoadError`, `isHostedHttpFailure`, `isSameDocument`,
  `isHostedLoaderUrl`.
- `VedikaChatView` now creates its `WebViewController` once instead of on
  every `build`, so a parent rebuild no longer reloads the chat.
- Tests: pure logic, the offline widget, and `VedikaChatView` against a fake
  `WebViewPlatform` (new dev dependency `webview_flutter_platform_interface`).

# 0.1.0

- First public release.
- `VedikaChatView` and `VedikaChatController` host the published
  Vedika chat loader inside a `webview_flutter` WebView on Android,
  iOS and macOS.
- `VedikaTokenProvider` is the host-side callback that mints a
  short-lived `vt_` token through the customer's backend.
- Lifecycle events (`ready`, `token-expired`, `finish`, `cancel`,
  `send-result`, `error`) flow through `controller.events`.
- Typed exceptions: `VedikaTokenMissingError`,
  `VedikaTokenProviderError`, `VedikaChatStateError`.
- Unit tests cover the controller, the static token provider and the
  config object. Example app covers config + controller.
- Bundle URL defaults to `https://cdn.vedika.io/chat-widget/v1/loader.js`;
  overridable per surface.
