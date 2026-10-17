# vedika_chat

Public mirror of the Vedika chat Flutter wrapper, version 0.1.0.

Public mirror of the Vedika chat Flutter wrapper, version 0.1.0.

Flutter wrapper for the hosted Vedika chat.

Hosts the published Vedika chat inside a native [webview_flutter][1]
container on Android, iOS and macOS, and forwards chat credentials to
the bundle through a `VedikaTokenProvider`. The streaming wire
(UI Message Stream v1) runs inside the bundle; the wrapper does not
re-parse SSE on its own.

This package is a thin
Flutter wrapper that opens the same Vedika chat the web lane ships,
with a token minted by the host app's own backend.

[1]: https://pub.dev/packages/webview_flutter

## Hosted by default

The chat is loaded from the network every time it opens. `loaderUrl`
defaults to the published loader
(`https://cdn.vedika.io/chat-widget/v1/loader.js`), so a chat update
reaches every installed app with no app-store release. Do not copy the
loader into your app.

Plain `http` is refused: `VedikaChatConfig` throws an `ArgumentError` for
an `http:` `loaderUrl`, and the WebView only navigates to `https` URLs.

Passing a `file:` URL (a loader you bundle as an asset) for `loaderUrl`
is the explicit opt-in to a pinned copy. The app then stops receiving
chat updates until you ship a new app release, so every chat update costs
an app-store release. Use it for demos and offline test rigs, not for
production.

## When chat cannot load

If the hosted loader cannot be fetched, `VedikaChatView` shows a plain
screen instead of a blank page: the heading "Can't reach chat", the line
"Check your connection and try again." and a Retry button.

- It appears when the hosted load fails: no network, DNS failure, TLS
  failure, an HTTP status of 400 or more for the loader, or no answer
  within 15 seconds (`kHostedLoadTimeout`). A failed image, analytics call
  or API request inside the chat never shows it, and neither does the
  user moving around inside the page.
- Retry hides the screen, clears the WebView cache and loads the hosted
  loader again from the network. It never falls back to a cached or
  bundled copy. If the load fails again the screen comes back.
- The screen is a live region, the button is labelled, focusable and
  also activated by Enter or Space, and nothing on it (or in any log)
  contains the URL or a token. It takes its text colour from the
  surrounding `DefaultTextStyle`, so it follows your app's theme.
- It is not used when `loaderUrl` is a bundled copy, because that file is
  already on the device.

How it is detected: the WebView opens a small host page that the wrapper
generates, so the hosted part is the loader `<script>`. The host page
reports the script's `error` event and a 15 second watchdog over the
bridge, on every platform. `NavigationDelegate.onWebResourceError`
(main frame only) and `onHttpError` (status 400 or more for the loader
URL; Android reports the URL, iOS does not) are handled as well. The
decision logic is in `lib/src/chat_load.dart` (pure Dart, tested without
a device). `VedikaChatOfflineView` is exported if you want to show the
same screen yourself.

## Install

`vedika_chat` is not published on pub.dev. Install it from its GitHub
repository, pinned to a release tag:

```yaml
# pubspec.yaml
dependencies:
  vedika_chat:
    git:
      url: https://github.com/vedika-io/vedika-chat-flutter.git
      ref: v0.1.0
```

The package sits at the repository root, so no `path:` is needed. Then run
`flutter pub get`.

## Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:vedika_chat/vedika_chat.dart';

Future<String> mintVedikaToken() async {
  // Call your backend, which forwards to POST /api/v1/embed/tokens
  // on the Vedika API with your server key.
  return yourBackend.mintChatToken(
    endUserId: 'app:user:42',
    scope: 'chat',
    ttlSeconds: 600,
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final VedikaChatController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = VedikaChatController(tokenProvider: mintVedikaToken);
    _ctl.events.listen((event) {
      if (event is VedikaChatError) {
        debugPrint('chat error: ${event.code} ${event.message}');
      }
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: VedikaChatView(
          controller: _ctl,
          // `loaderUrl` defaults to the hosted loader.
          config: VedikaChatConfig(endUserId: 'app:user:42'),
        ),
      ),
    );
  }
}
```

A runnable example lives at `example/`:

```bash
cd example
flutter run
```

The example's `mintToken` returns a synthetic token that the bundle
will reject; replace it with a real backend mint in a real app.

## Public API

### `VedikaChatController`

Owns a chat session. Construct it with a token provider; pass it to
`VedikaChatView`. Refresh tokens through `refreshToken()`; subscribe
to `events` for `ready`, `token-expired`, `finish`, `cancel`,
`send-result` and `error` events. Call `stop()` to ask the bundle to
cancel the current turn. Call `dispose()` when the widget leaves the
tree.

### `VedikaTokenProvider`

`Future<String> Function()`. The wrapper calls this whenever the
bundle needs a fresh credential: on first load, on
`VedikaChatTokenExpired`, and proactively before expiry.

A `StaticTokenProvider` ships with the package for tests.

### `VedikaChatView`

`StatefulWidget` that hosts the bundle. Accepts a `VedikaChatConfig`,
denies navigation outside the loader URL's host (plus a small set of
CDN hosts: `cdn.vedika.io`, `harness.vedika.io`, `fonts.gstatic.com`).
Wraps the WebView in `SafeArea` by default so the chat shell does not
draw under the system UI; pass `respectSafeArea: false` for hosts that
already manage insets themselves. `bootstrapHtml(config)` is exposed
for tests so the redaction guarantee can be verified without spinning
up a real WebView. When the hosted loader cannot be fetched it shows
`VedikaChatOfflineView` (see "When chat cannot load").

### `VedikaChatOfflineView`

The "Can't reach chat" screen with a Retry button. Takes one `onRetry`
callback. Built from `widgets.dart` only, so it works under Material,
Cupertino or a bare `WidgetsApp`.

### `VedikaChatConfig`

Loader URL (defaults to the hosted loader, `kDefaultLoaderUrl`), end user id, optional thread id to resume, optional
context map, optional extra `allowedOrigins`, optional `theme` (see
`VedikaChatTheme`), and safe-area toggles (`respectSafeArea`,
`safeAreaBottom`).

### `VedikaChatTheme`

Theme tokens injected into the WebView host page as CSS custom
properties (`--vedika-bg`, `--vedika-fg`, `--vedika-accent`,
`--vedika-radius`, `--vedika-font`). Use `VedikaChatTheme.fromColors`
to derive a theme from a Flutter `ColorScheme` or pass an explicit
`VedikaChatTheme` for hand-crafted palettes.

### `VedikaChatEvent`

Sealed event hierarchy: `VedikaChatReady`, `VedikaChatTokenExpired`,
`VedikaChatFinish`, `VedikaChatCancel`, `VedikaChatSendResult`,
`VedikaChatError`. The latter is also an `Exception`.

### Typed exceptions

`VedikaTokenMissingError`, `VedikaTokenProviderError`,
`VedikaChatStateError`. All extend `VedikaChatException`.

### `VedikaTokenCache`

In-memory cache that calls the `VedikaTokenProvider` at most once per
refresh window. The `VedikaChatController` uses it internally; expose
it directly only if you need to invalidate before the refresh window
expires (e.g. on a forced logout).

### Token redaction helpers

`redactToken`, `redactUrl`, `safeError` — exposed for host apps that
need to scrub logs, error messages or URLs that may have crossed a
network boundary with a token-shaped substring inside.

## Security model

The wrapper enforces a three-part security contract (M-FL-SEC):

1. **Allowed-origin rules.** The WebView's `NavigationDelegate` only
   navigates to the loader URL's host or hosts on the
   `kDefaultAllowedOrigins` allow-list plus whatever the consumer adds
   via `VedikaChatConfig.allowedOrigins`. Non-`https` schemes and
   unknown hosts are rejected.
2. **Single JavaScript channel.** The wrapper registers a single
   `VedikaBridge` channel; the bundle calls
   `window.VedikaBridge.postMessage(JSON.stringify({type, ...}))` and
   the wrapper routes messages by the `type` discriminator. The
   wrapper's own host page also posts `load-failed` (reason `error` or
   `timeout`, nothing else) when the hosted loader cannot be fetched.
3. **Token redaction.** `redactToken` scrubs `vt_`-prefixed and JWT
   strings before they reach a log, an error, or a URL. `redactUrl`
   scrubs token-shaped query parameters and path segments. `safeError`
   wraps unknown errors so an accidental token in the message is
   scrubbed at the boundary. The bootstrap HTML is generated by
   `VedikaChatView.bootstrapHtml`; tests pin that it never contains a
   raw token, never calls `console.*`, and never embeds a token in a
   URL attribute.

## Platform support

| Platform | Status |
|---|---|
| Android (API 24+) | Supported |
| iOS (13+) | Supported |
| macOS (10.15+) | Supported |
| Flutter web | Not supported (`webview_flutter` lists no web) |

## How it differs from a headless stream

This is the **WebView-mode** wrapper. There is no native SSE framer, no
`http.Client.send()` reader, no second-rate schemas: the page inside
the WebView is the same Vedika chat the web app runs, and it
owns the SSE stream, the cancel endpoint and the schema.

A headless native core for Flutter (with `package:http` and a
self-contained SSE framer) is a later deliverable: it would
re-purpose Vedika tokens, but the UI layer stays the WebView version
because the chat layouts must not fork across platforms.

## Token lifecycle

1. The view loads an HTML host page that scripts in the hosted loader.
2. The bundle announces itself by posting `ready` over the
   `VedikaBridge` JS channel.
3. The controller asks the host `VedikaTokenProvider` for a fresh
   `vt_` and forwards it to the page via `acceptToken(...)`.
4. The bundle returns a `token-expired` event near TTL; the wrapper
   re-mints and re-posts.
5. The bundle may post `finish`, `cancel` or `error` to surface
   turn state.

## Tests

```bash
flutter pub get
flutter test
```

## Licensing

Apache 2.0. See `LICENSE`.
