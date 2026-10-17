// Widget-level tests for VedikaChatView with a fake WebViewPlatform.
//
// The fake stands in for the native WebView: it records what the view loads
// and lets a test fire the same callbacks the real platform fires (resource
// error, HTTP error, page finished) and the bridge messages the host page
// posts. What it cannot show is the native network stack itself; the
// platform behaviour these tests assume was read from webview_flutter_android
// 4.12 and webview_flutter_wkwebview 3.25.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeController extends PlatformWebViewController {
  FakeController(super.params) : super.implementation();

  final Map<String, void Function(JavaScriptMessage)> channels = {};
  final List<({String html, String? baseUrl})> loads = [];
  final List<String> scripts = [];
  int cacheClears = 0;
  bool throwOnClearCache = false;
  FakeNavigationDelegate? delegate;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    delegate = handler as FakeNavigationDelegate;
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params.onMessageReceived;
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    loads.add((html: html, baseUrl: baseUrl));
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
  }

  @override
  Future<void> clearCache() async {
    cacheClears++;
    if (throwOnClearCache) throw UnsupportedError('clearCache');
  }

  /// The bundle (or the host page) posts a message over the JS channel.
  void post(String json) =>
      channels[kVedikaBridgeChannel]!(JavaScriptMessage(message: json));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  WebResourceErrorCallback? onWebResourceError;
  HttpResponseErrorCallback? onHttpError;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {
    this.onHttpError = onHttpError;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(
        key: Key('fake-webview'),
      );
}

class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeController> controllers = [];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final c = FakeController(params);
    controllers.add(c);
    return c;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      FakeWebViewWidget(params);
}

final Uri hosted = Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js');

late FakeWebViewPlatform platform;
late VedikaChatController chat;

Future<FakeController> mount(
  WidgetTester tester,
  VedikaChatConfig config,
) async {
  chat = VedikaChatController(tokenProvider: () async => 'vt_test_token');
  addTearDown(chat.dispose);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: VedikaChatView(controller: chat, config: config),
      ),
    ),
  );
  await tester.pump(); // post-frame first load
  expect(platform.controllers, hasLength(1));
  return platform.controllers.single;
}

Finder get offline => find.byType(VedikaChatOfflineView);
Finder get webview => find.byKey(const Key('fake-webview'));

void mainFrameError(FakeController c, {String? url}) =>
    c.delegate!.onWebResourceError!(
      WebResourceError(
        errorCode: -1009,
        description: 'offline',
        isForMainFrame: true,
        url: url,
      ),
    );

void main() {
  // A fresh fake platform per test. The platform interface refuses to be
  // reset to null, so each test simply installs a new instance.
  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  group('hosted by default', () {
    testWidgets('loads the hosted loader when the config does not set one',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      expect(c.loads, hasLength(1));
      expect(c.loads.single.baseUrl, hosted.toString());
      expect(c.loads.single.html, contains('<script src="$hosted"'));
      expect(webview, findsOneWidget);
      expect(offline, findsNothing);
    });

    testWidgets('loads an explicit hosted loader from the network',
        (tester) async {
      final custom = Uri.parse('https://chat.example.com/loader.js');
      final c = await mount(
        tester,
        VedikaChatConfig(loaderUrl: custom, endUserId: 'u1'),
      );
      expect(c.loads.single.baseUrl, custom.toString());
      expect(c.loads.single.html, contains('<script src="$custom"'));
    });

    testWidgets('a bundled loader file is used only when explicitly passed',
        (tester) async {
      final bundled = Uri.parse('file:///data/app/chat/loader.js');
      final c = await mount(
        tester,
        VedikaChatConfig(loaderUrl: bundled, endUserId: 'u1'),
      );
      expect(c.loads.single.html, contains('<script src="$bundled"'));
      expect(c.loads.single.html, isNot(contains('cdn.vedika.io')));
    });

    testWidgets('a bundled loader never shows the offline screen',
        (tester) async {
      final c = await mount(
        tester,
        VedikaChatConfig(
          loaderUrl: Uri.parse('file:///data/app/chat/loader.js'),
          endUserId: 'u1',
        ),
      );
      mainFrameError(c);
      c.post('{"type":"load-failed","reason":"error"}');
      await tester.pump();
      expect(offline, findsNothing);
      expect(webview, findsOneWidget);
    });
  });

  group('the offline screen appears when the hosted load fails', () {
    testWidgets('on a main-frame network error', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c, url: hosted.toString());
      await tester.pump();
      expect(offline, findsOneWidget);
      expect(webview, findsNothing);
      expect(find.text("Can't reach chat"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('on a main-frame error that carries no URL (iOS)',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c);
      await tester.pump();
      expect(offline, findsOneWidget);
    });

    testWidgets('on an HTTP error status for the hosted loader',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.delegate!.onHttpError!(
        HttpResponseError(
          request: WebResourceRequest(uri: hosted),
          response: WebResourceResponse(uri: null, statusCode: 503),
        ),
      );
      await tester.pump();
      expect(offline, findsOneWidget);
    });

    testWidgets('when the host page reports the loader failed to load',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.post('{"type":"load-failed","reason":"error"}');
      await tester.pump();
      expect(offline, findsOneWidget);
    });

    testWidgets('when the host page reports the loader timed out',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.post('{"type":"load-failed","reason":"timeout"}');
      await tester.pump();
      expect(offline, findsOneWidget);
    });
  });

  group('the offline screen does not appear for other failures', () {
    testWidgets('a sub-resource error', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.delegate!.onWebResourceError!(
        WebResourceError(
          errorCode: -2,
          description: 'blocked',
          isForMainFrame: false,
          url: 'https://cdn.vedika.io/logo.png',
        ),
      );
      await tester.pump();
      expect(offline, findsNothing);
      expect(webview, findsOneWidget);
    });

    testWidgets('a main-frame error for a different page', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c, url: 'https://elsewhere.example.net/page');
      await tester.pump();
      expect(offline, findsNothing);
    });

    testWidgets('an HTTP error for another URL, or a non-error status',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.delegate!.onHttpError!(
        HttpResponseError(
          request: WebResourceRequest(
            uri: Uri.parse('https://cdn.vedika.io/api/turns'),
          ),
          response: WebResourceResponse(uri: null, statusCode: 500),
        ),
      );
      c.delegate!.onHttpError!(
        HttpResponseError(
          request: WebResourceRequest(uri: hosted),
          response: WebResourceResponse(uri: null, statusCode: 304),
        ),
      );
      // iOS reports no URL at all; that cannot be matched to the loader.
      c.delegate!.onHttpError!(
        HttpResponseError(
          response: WebResourceResponse(uri: null, statusCode: 500),
        ),
      );
      await tester.pump();
      expect(offline, findsNothing);
    });

    testWidgets('a chat-level error event from the bundle', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      c.post('{"type":"error","code":"rate_limited","message":"slow down"}');
      await tester.pump();
      expect(offline, findsNothing);
    });
  });

  group('Retry', () {
    testWidgets('hides the screen and reloads the hosted loader from the network',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c);
      await tester.pump();
      expect(c.loads, hasLength(1));
      expect(c.cacheClears, 0);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(offline, findsNothing);
      expect(webview, findsOneWidget);
      expect(c.cacheClears, 1);
      expect(c.loads, hasLength(2));
      expect(c.loads.last.baseUrl, hosted.toString());
      expect(c.loads.last.html, contains('<script src="$hosted"'));
    });

    testWidgets('shows the screen again if the reload fails again',
        (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c);
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      c.post('{"type":"load-failed","reason":"error"}');
      await tester.pump();
      expect(offline, findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(offline, findsNothing);
      expect(c.loads, hasLength(3));
      expect(c.cacheClears, 2);
    });

    testWidgets('a successful reload clears the failure', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c);
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      c.post('{"type":"ready","origin":"flutter"}');
      await tester.pump();
      expect(offline, findsNothing);
      expect(webview, findsOneWidget);
    });

    testWidgets('survives a clearCache that throws', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      mainFrameError(c);
      await tester.pump();
      c.throwOnClearCache = true;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(c.loads, hasLength(2));
    });
  });

  group('the existing security checks are intact', () {
    testWidgets('navigation is still limited to the allow-list', (tester) async {
      final c = await mount(tester, VedikaChatConfig(endUserId: 'u1'));
      final d = c.delegate!;
      Future<NavigationDecision> decide(String url) async =>
          await d.onNavigationRequest!(
            NavigationRequest(url: url, isMainFrame: true),
          );
      expect(await decide('https://cdn.vedika.io/page'),
          NavigationDecision.navigate);
      expect(await decide('https://evil.example.com/'),
          NavigationDecision.prevent);
      expect(await decide('http://cdn.vedika.io/page'),
          NavigationDecision.prevent);
      expect(await decide('file:///etc/passwd'), NavigationDecision.prevent);
    });

    testWidgets('the offline screen never renders the URL or a token',
        (tester) async {
      final c = await mount(
        tester,
        VedikaChatConfig(
          loaderUrl: Uri.parse('https://chat.example.com/loader.js?session=vt_abc123'),
          endUserId: 'u1',
        ),
      );
      mainFrameError(c);
      await tester.pump();
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        expect(t.data, isNot(contains('chat.example.com')));
        expect(t.data, isNot(contains('vt_')));
      }
    });
  });

  group('the WebView is not rebuilt', () {
    testWidgets('a parent rebuild neither recreates the controller nor reloads',
        (tester) async {
      chat = VedikaChatController(tokenProvider: () async => 'vt_test_token');
      addTearDown(chat.dispose);
      final config = VedikaChatConfig(endUserId: 'u1');
      late StateSetter rebuild;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return VedikaChatView(controller: chat, config: config);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      rebuild(() {});
      await tester.pump();
      rebuild(() {});
      await tester.pump();
      expect(platform.controllers, hasLength(1));
      expect(platform.controllers.single.loads, hasLength(1));
    });
  });

  group('bridge messages', () {
    testWidgets('load-failed is not forwarded as a chat event', (tester) async {
      final events = <VedikaChatEvent>[];
      chat = VedikaChatController(tokenProvider: () async => 'vt_test_token');
      addTearDown(chat.dispose);
      final sub = chat.events.listen(events.add);
      addTearDown(sub.cancel);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: VedikaChatView(
              controller: chat,
              config: VedikaChatConfig(endUserId: 'u1'),
            ),
          ),
        ),
      );
      await tester.pump();
      events.clear();
      platform.controllers.single.post('{"type":"load-failed","reason":"error"}');
      await tester.pump();
      await tester.pump(Duration.zero);
      expect(events, isEmpty);
      expect(offline, findsOneWidget);
    });
  });
}
