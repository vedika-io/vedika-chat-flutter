import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

const String sampleToken = 'vt_abcdefghij1234567890ABCDEFGHIJ'; // gitleaks:allow

VedikaChatConfig _config() => VedikaChatConfig(
      loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
      endUserId: 'app:user:test',
      threadId: 'thread_1',
      context: const {'locale': 'en-GB'},
    );

void main() {
  group('VedikaChatView.bootstrapHtml', () {
    test('includes the loader URL, end user id and thread id', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      expect(
        html,
        contains(
          'data-loader-src="https://cdn.vedika.io/chat-widget/v1/loader.js"',
        ),
      );
      expect(html, contains('data-end-user-id="app:user:test"'));
      expect(html, contains('data-thread-id="thread_1"'));
    });

    test('injects the theme CSS variables into the host page', () {
      const theme = VedikaChatTheme(
        background: '#abcdef99',
        foreground: '#001122',
        accent: '#ffaabb',
        radius: '16px',
        fontFamily: 'Inter, sans-serif',
      );
      final cfg = VedikaChatConfig(
        loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
        endUserId: 'app:user:test',
        theme: theme,
      );
      final html = VedikaChatView.bootstrapHtml(cfg);
      expect(html, contains('--vedika-bg: #abcdef99'));
      expect(html, contains('--vedika-fg: #001122'));
      expect(html, contains('--vedika-accent: #ffaabb'));
      expect(html, contains('--vedika-radius: 16px'));
      expect(html, contains('--vedika-font: Inter, sans-serif'));
    });

    test('uses the single JavaScript channel declared by the protocol', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      expect(html, contains('window.VedikaBridge'));
      expect(html, contains('VedikaBridge.postMessage'));
    });

    test('never embeds a raw token in the page source', () {
      // The bootstrap HTML is a pure template. Even if a regression
      // accidentally injects a token-shaped string, the placeholder
      // helper would be used, not a raw token.
      final html = VedikaChatView.bootstrapHtml(_config());
      expect(html.contains(sampleToken), isFalse,
          reason: 'bootstrap HTML must never contain a raw token');
    });

    test('does not call console.log on the token path', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      // Strip HTML comments and JS line comments to focus on the
      // actual code paths the host page runs.
      var code = html.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
      code = code.replaceAll(RegExp(r'//[^\n]*'), '');
      expect(code.contains('console.log'), isFalse);
      expect(code.contains('console.error'), isFalse);
      expect(code.contains('console.warn'), isFalse);
    });

    test('does not embed the token in a URL (script src, href, srcset)', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      for (final attr in ['src=', 'href=', 'srcset=']) {
        for (final line in html.split('\n')) {
          if (line.contains(attr)) {
            expect(line.contains(sampleToken), isFalse,
                reason: '$attr must not contain a raw token');
          }
        }
      }
    });

    test('escapes HTML attributes (defence in depth)', () {
      final cfg = VedikaChatConfig(
        loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
        endUserId: '<script>alert(1)</script>',
      );
      final html = VedikaChatView.bootstrapHtml(cfg);
      // The literal end user id must not appear in the HTML; only the
      // escaped form should.
      expect(html.contains('<script>alert(1)</script>'), isFalse);
      expect(html, contains('<script>'));
    });

    test('reports a hosted-loader failure and a timeout over the channel', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      // The loader script reports its own failure (offline, DNS, TLS, HTTP
      // error) and a watchdog reports a load that never finishes.
      expect(html, contains("onerror=\"window.vedika.reportLoadFailed('error')\""));
      expect(html, contains('onload="window.vedika.reportLoaderLoaded()"'));
      expect(html, contains("window.vedika.reportLoadFailed('timeout')"));
      expect(html, contains("type: 'load-failed'"));
      expect(html, contains('}, ${kHostedLoadTimeout.inMilliseconds});'));
    });

    test('the load-failure report carries no URL and no token', () {
      final html = VedikaChatView.bootstrapHtml(_config());
      final start = html.indexOf('window.vedika.reportLoadFailed = function');
      final end = html.indexOf('};', start);
      final body = html.substring(start, end);
      expect(body, contains("reason: reason === 'timeout' ? 'timeout' : 'error'"));
      expect(body.contains('http'), isFalse);
      expect(body.contains('token'), isFalse);
      expect(body.contains('loader'), isFalse);
    });

    test('a bundled loader gets no offline wiring', () {
      final cfg = VedikaChatConfig(
        loaderUrl: Uri.parse('file:///data/app/chat/loader.js'),
        endUserId: 'app:user:test',
      );
      final html = VedikaChatView.bootstrapHtml(cfg);
      expect(html, contains('<script src="file:///data/app/chat/loader.js" async></script>'));
      expect(html.contains('reportLoadFailed'), isFalse);
      expect(html.contains('load-failed'), isFalse);
      expect(html.contains('setTimeout'), isFalse);
    });

    test('uses the hosted loader when the config does not set one', () {
      final html = VedikaChatView.bootstrapHtml(
        VedikaChatConfig(endUserId: 'app:user:test'),
      );
      expect(
        html,
        contains('<script src="https://cdn.vedika.io/chat-widget/v1/loader.js"'),
      );
    });

    test('context JSON escapes < / to avoid script-tag breakouts', () {
      final cfg = VedikaChatConfig(
        loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
        endUserId: 'app:user:test',
        context: const {'k': '</script><script>x'},
      );
      final html = VedikaChatView.bootstrapHtml(cfg);
      expect(html.contains('</script><script>x'), isFalse);
      expect(html.contains('<\\/script>'), isTrue);
    });
  });
}
