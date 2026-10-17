import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

final Uri hosted = Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js');

void main() {
  group('isSameDocument', () {
    test('ignores query, fragment, host case and a trailing slash', () {
      expect(
        isSameDocument(hosted, Uri.parse('$hosted?v=2#top')),
        isTrue,
      );
      expect(
        isSameDocument(
          Uri.parse('https://CDN.vedika.io/a/'),
          Uri.parse('https://cdn.vedika.io/a'),
        ),
        isTrue,
      );
      expect(
        isSameDocument(
          Uri.parse('https://cdn.vedika.io'),
          Uri.parse('https://cdn.vedika.io/'),
        ),
        isTrue,
      );
    });

    test('separates different paths, hosts, schemes and ports', () {
      expect(
        isSameDocument(hosted, Uri.parse('https://cdn.vedika.io/other.js')),
        isFalse,
      );
      expect(
        isSameDocument(
          hosted,
          Uri.parse('https://other.example.com/chat-widget/v1/loader.js'),
        ),
        isFalse,
      );
      expect(
        isSameDocument(
          hosted,
          Uri.parse('http://cdn.vedika.io/chat-widget/v1/loader.js'),
        ),
        isFalse,
      );
      expect(
        isSameDocument(
          hosted,
          Uri.parse('https://cdn.vedika.io:8443/chat-widget/v1/loader.js'),
        ),
        isFalse,
      );
    });
  });

  group('isHostedLoaderUrl', () {
    test('only https is hosted; plain http and a bundled copy are not', () {
      expect(isHostedLoaderUrl(hosted), isTrue);
      expect(isHostedLoaderUrl(Uri.parse('http://localhost:8080/l.js')), isFalse);
      expect(isHostedLoaderUrl(Uri.parse('file:///data/app/chat/loader.js')),
          isFalse);
      expect(isHostedLoaderUrl(Uri.parse('asset:///loader.js')), isFalse);
      expect(isHostedLoaderUrl(Uri.parse('data:text/javascript,1')), isFalse);
    });
  });

  group('isRefusedLoaderUrl', () {
    test('refuses the network schemes that are not https', () {
      expect(isRefusedLoaderUrl(Uri.parse('http://cdn.vedika.io/l.js')), isTrue);
      expect(isRefusedLoaderUrl(Uri.parse('HTTP://cdn.vedika.io/l.js')), isTrue);
      expect(isRefusedLoaderUrl(Uri.parse('ws://cdn.vedika.io/l.js')), isTrue);
      expect(isRefusedLoaderUrl(Uri.parse('ftp://cdn.vedika.io/l.js')), isTrue);
      expect(isRefusedLoaderUrl(hosted), isFalse);
      expect(isRefusedLoaderUrl(Uri.parse('file:///data/app/chat/loader.js')),
          isFalse);
    });
  });

  group('isHostedLoadError (no network, DNS, TLS, timeout)', () {
    test('accepts a main-frame error for the hosted URL', () {
      expect(
        isHostedLoadError(
          isForMainFrame: true,
          url: hosted.toString(),
          hostedUrl: hosted,
        ),
        isTrue,
      );
    });

    test('accepts a main-frame error with no URL (iOS provisional failure)', () {
      expect(
        isHostedLoadError(isForMainFrame: true, url: null, hostedUrl: hosted),
        isTrue,
      );
      expect(
        isHostedLoadError(isForMainFrame: true, url: '', hostedUrl: hosted),
        isTrue,
      );
    });

    test('ignores sub-resource errors, even for the hosted URL', () {
      expect(
        isHostedLoadError(
          isForMainFrame: false,
          url: hosted.toString(),
          hostedUrl: hosted,
        ),
        isFalse,
      );
      expect(
        isHostedLoadError(isForMainFrame: null, url: null, hostedUrl: hosted),
        isFalse,
      );
    });

    test('ignores a main-frame error for some other page', () {
      expect(
        isHostedLoadError(
          isForMainFrame: true,
          url: 'https://cdn.vedika.io/logo.png',
          hostedUrl: hosted,
        ),
        isFalse,
      );
      expect(
        isHostedLoadError(
          isForMainFrame: true,
          url: 'https://elsewhere.example.net/',
          hostedUrl: hosted,
        ),
        isFalse,
      );
    });
  });

  group('isHostedHttpFailure', () {
    test('accepts status >= 400 on the hosted URL', () {
      for (final status in [400, 403, 404, 429, 500, 502, 503, 599]) {
        expect(
          isHostedHttpFailure(
            statusCode: status,
            requestUri: hosted,
            hostedUrl: hosted,
          ),
          isTrue,
          reason: 'status $status',
        );
      }
    });

    test('ignores statuses below 400', () {
      for (final status in [0, 200, 204, 301, 304, 399]) {
        expect(
          isHostedHttpFailure(
            statusCode: status,
            requestUri: hosted,
            hostedUrl: hosted,
          ),
          isFalse,
          reason: 'status $status',
        );
      }
    });

    test('ignores an HTTP error for another URL (image, XHR, analytics)', () {
      expect(
        isHostedHttpFailure(
          statusCode: 500,
          requestUri: Uri.parse('https://cdn.vedika.io/api/turns'),
          hostedUrl: hosted,
        ),
        isFalse,
      );
    });

    test('needs both a URL and a status', () {
      expect(
        isHostedHttpFailure(statusCode: 500, requestUri: null, hostedUrl: hosted),
        isFalse,
      );
      expect(
        isHostedHttpFailure(statusCode: null, requestUri: hosted, hostedUrl: hosted),
        isFalse,
      );
    });
  });

  group('VedikaChatLoadState', () {
    const loading = VedikaChatLoadState();

    test('starts loading on attempt 0', () {
      expect(loading.status, VedikaChatLoadStatus.loading);
      expect(loading.attempt, 0);
    });

    test('loading -> ready on a finished load', () {
      expect(loading.onLoaded().status, VedikaChatLoadStatus.ready);
    });

    test('any state -> failed on a hosted-load failure', () {
      expect(loading.onFailed().status, VedikaChatLoadStatus.failed);
      expect(loading.onLoaded().onFailed().status, VedikaChatLoadStatus.failed);
    });

    test('failed is sticky against a late loaded signal', () {
      final failed = loading.onFailed();
      expect(failed.onLoaded(), failed);
      expect(failed.onFailed(), failed);
    });

    test('retry: failed -> loading with the attempt bumped', () {
      final retried = loading.onFailed().onRetry();
      expect(retried.status, VedikaChatLoadStatus.loading);
      expect(retried.attempt, 1);
    });

    test('retry does nothing unless failed', () {
      expect(loading.onRetry(), loading);
      expect(loading.onLoaded().onRetry(), loading.onLoaded());
    });

    test('a successful load after a retry clears the failure', () {
      final s = loading.onFailed().onRetry().onLoaded();
      expect(s.status, VedikaChatLoadStatus.ready);
      expect(s.attempt, 1);
    });

    test('a failed retry shows the failure again, and can be retried again', () {
      final s = loading.onFailed().onRetry().onFailed();
      expect(s.status, VedikaChatLoadStatus.failed);
      expect(s.onRetry().attempt, 2);
    });

    test('reset is a no-op at start and starts over otherwise', () {
      expect(loading.onReset(), loading);
      final r = loading.onFailed().onReset();
      expect(r.status, VedikaChatLoadStatus.loading);
      expect(r.attempt, 1);
    });

    test('has value equality', () {
      expect(const VedikaChatLoadState(), const VedikaChatLoadState());
      expect(
        const VedikaChatLoadState().hashCode,
        const VedikaChatLoadState().hashCode,
      );
    });
  });

  group('offline copy', () {
    test('is the agreed plain copy and carries no URL or error detail', () {
      expect(kOfflineHeading, "Can't reach chat");
      expect(kOfflineBody, 'Check your connection and try again.');
      expect(kOfflineRetry, 'Retry');
      final all = '$kOfflineHeading $kOfflineBody $kOfflineRetry';
      expect(RegExp(r'https?:|token|vt_|error', caseSensitive: false).hasMatch(all),
          isFalse);
    });

    test('the hosted-load timeout is finite and positive', () {
      expect(kHostedLoadTimeout, greaterThan(Duration.zero));
      expect(kHostedLoadTimeout, lessThanOrEqualTo(const Duration(seconds: 60)));
    });
  });
}
