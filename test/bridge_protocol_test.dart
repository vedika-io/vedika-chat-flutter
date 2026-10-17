import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  group('bridge protocol constants', () {
    test('channel name is stable', () {
      expect(kVedikaBridgeChannel, 'VedikaBridge');
    });

    test('message discriminators are stable', () {
      expect(kMsgReady, 'ready');
      expect(kMsgTokenExpired, 'token-expired');
      expect(kMsgFinish, 'finish');
      expect(kMsgCancel, 'cancel');
      expect(kMsgError, 'error');
      expect(kMsgSendResult, 'send-result');
      expect(kMsgLoadFailed, 'load-failed');
    });

    test('load-failed is a host-page signal, not a bundle event kind', () {
      const kinds = [
        kMsgReady,
        kMsgTokenExpired,
        kMsgFinish,
        kMsgCancel,
        kMsgError,
        kMsgSendResult,
      ];
      expect(kinds, isNot(contains(kMsgLoadFailed)));
    });

    test('event kinds match the message discriminators', () {
      expect(const VedikaChatReady().kind, kMsgReady);
      expect(const VedikaChatTokenExpired().kind, kMsgTokenExpired);
      expect(const VedikaChatFinish('x').kind, kMsgFinish);
      expect(const VedikaChatCancel().kind, kMsgCancel);
      expect(const VedikaChatSendResult(ok: true).kind, kMsgSendResult);
      expect(const VedikaChatError('x', 'y').kind, kMsgError);
    });

    test('token source is stable', () {
      expect(kTokenSourceFlutter, 'flutter.tokenProvider');
    });

    test('default allowed origins are HTTPS-friendly', () {
      expect(kDefaultAllowedOrigins, contains('cdn.vedika.io'));
      expect(kDefaultAllowedOrigins, contains('harness.vedika.io'));
      expect(kDefaultAllowedOrigins, contains('fonts.gstatic.com'));
      expect(kAllowedSchemes, contains('https'));
      expect(kAllowedSchemes, isNot(contains('http')));
      expect(kAllowedSchemes, isNot(contains('file')));
    });
  });

  group('isOriginAllowed', () {
    test('matches exact hosts', () {
      expect(isOriginAllowed('cdn.vedika.io', const ['cdn.vedika.io']),
          isTrue);
    });

    test('rejects mismatched hosts', () {
      expect(isOriginAllowed('evil.example.com', const ['cdn.vedika.io']),
          isFalse);
    });

    test('treats * as wildcard', () {
      expect(isOriginAllowed('anything.example.com', const ['*']), isTrue);
    });

    test('rejects null and empty hosts', () {
      expect(isOriginAllowed(null, const ['*']), isFalse);
      expect(isOriginAllowed('', const ['*']), isFalse);
    });
  });

  group('shouldAllowNavigation', () {
    final loader = Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js');

    test('accepts the loader URL exactly', () {
      expect(
        shouldAllowNavigation(
          url: loader.toString(),
          loaderUri: loader,
        ),
        isTrue,
      );
    });

    test('accepts subresources on the default CDN hosts', () {
      expect(
        shouldAllowNavigation(
          url: 'https://harness.vedika.io/health',
          loaderUri: loader,
        ),
        isTrue,
      );
    });

    test('accepts extra allowed hosts the consumer passes in', () {
      expect(
        shouldAllowNavigation(
          url: 'https://my-cdn.example.com/bundle.js',
          loaderUri: loader,
          extraAllowedHosts: const ['my-cdn.example.com'],
        ),
        isTrue,
      );
    });

    test('rejects http URLs', () {
      expect(
        shouldAllowNavigation(
          url: 'http://cdn.vedika.io/loader.js',
          loaderUri: loader,
        ),
        isFalse,
      );
    });

    test('http and https on the same allowed host give different answers', () {
      expect(
        shouldAllowNavigation(
          url: 'https://my-cdn.example.com/bundle.js',
          loaderUri: loader,
          extraAllowedHosts: const ['my-cdn.example.com'],
        ),
        isTrue,
      );
      expect(
        shouldAllowNavigation(
          url: 'http://my-cdn.example.com/bundle.js',
          loaderUri: loader,
          extraAllowedHosts: const ['my-cdn.example.com'],
        ),
        isFalse,
      );
    });

    test('the "*" host never lets a non-https scheme in', () {
      const star = ['*'];
      expect(
        shouldAllowNavigation(
            url: 'https://anywhere.example.com/', loaderUri: loader, extraAllowedHosts: star),
        isTrue,
      );
      for (final url in [
        'http://anywhere.example.com/',
        'HTTP://anywhere.example.com/',
        'ws://anywhere.example.com/',
        'wss://anywhere.example.com/',
        'ftp://anywhere.example.com/',
        'file://anywhere.example.com/x',
        '//anywhere.example.com/',
      ]) {
        expect(
          shouldAllowNavigation(url: url, loaderUri: loader, extraAllowedHosts: star),
          isFalse,
          reason: url,
        );
      }
    });

    test('rejects file:// URLs', () {
      expect(
        shouldAllowNavigation(
          url: 'file:///etc/passwd',
          loaderUri: loader,
        ),
        isFalse,
      );
    });

    test('rejects unknown hosts', () {
      expect(
        shouldAllowNavigation(
          url: 'https://evil.example.com/loader.js',
          loaderUri: loader,
        ),
        isFalse,
      );
    });

    test('rejects malformed URLs', () {
      expect(
        shouldAllowNavigation(url: 'not a url', loaderUri: loader),
        isFalse,
      );
    });
  });
}
