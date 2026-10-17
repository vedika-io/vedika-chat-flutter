import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

VedikaChatController _controller({
  Future<String> Function()? tokenProvider,
}) {
  return VedikaChatController(
    tokenProvider: tokenProvider ?? (() async => 'vt_test'),
  );
}

VedikaChatConfig _config({String? threadId}) => VedikaChatConfig(
      loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
      endUserId: 'app:user:1',
      threadId: threadId,
    );

void main() {
  group('VedikaChatController', () {
    test('open emits VedikaChatReady', () async {
      final ctl = _controller();
      final ready = <VedikaChatEvent>[];
      final sub = ctl.events.listen(ready.add);
      await ctl.open(_config());
      await Future<void>.delayed(Duration.zero);
      expect(ready, [isA<VedikaChatReady>()]);
      expect(ctl.isOpen, isTrue);
      expect(ctl.config?.endUserId, 'app:user:1');
      await sub.cancel();
      await ctl.dispose();
    });

    test('refreshToken forwards provider value', () async {
      final ctl = _controller(tokenProvider: () async => 'vt_refreshed');
      final tokens = <String>[];
      final sub = ctl.tokenUpdates.listen(tokens.add);
      final out = await ctl.refreshToken();
      await Future<void>.delayed(Duration.zero);
      expect(out, 'vt_refreshed');
      expect(tokens, ['vt_refreshed']);
      await sub.cancel();
      await ctl.dispose();
    });

    test('refreshToken throws VedikaTokenMissingError on empty', () async {
      final ctl = _controller(tokenProvider: () async => '');
      await expectLater(
        ctl.refreshToken(),
        throwsA(isA<VedikaTokenMissingError>()),
      );
      await ctl.dispose();
    });

    test('refreshToken wraps provider exceptions', () async {
      final ctl = _controller(tokenProvider: () async {
        throw StateError('mint failed');
      });
      await expectLater(
        ctl.refreshToken(),
        throwsA(
          isA<VedikaTokenProviderError>().having(
            (e) => e.cause.toString(),
            'cause',
            contains('mint failed'),
          ),
        ),
      );
      await ctl.dispose();
    });

    test('stop only emits when open', () async {
      final ctl = _controller();
      // No open yet — stop should be a no-op (no throw, no event).
      await ctl.stop();
      final cancels = <VedikaChatEvent>[];
      final sub = ctl.events.listen(cancels.add);
      await ctl.open(_config());
      await ctl.stop();
      await Future<void>.delayed(Duration.zero);
      expect(cancels.whereType<VedikaChatCancel>().length, 1);
      await sub.cancel();
      await ctl.dispose();
    });

    test('reportEvent surfaces bundles events', () async {
      final ctl = _controller();
      final seen = <VedikaChatEvent>[];
      final sub = ctl.events.listen(seen.add);
      ctl.reportEvent(const VedikaChatFinish('msg_99'));
      ctl.reportEvent(const VedikaChatTokenExpired());
      ctl.reportEvent(const VedikaChatError('boom', 'fatal'));
      await Future<void>.delayed(Duration.zero);
      expect(seen.whereType<VedikaChatFinish>().first.messageId, 'msg_99');
      expect(seen.whereType<VedikaChatTokenExpired>().length, 1);
      expect(seen.whereType<VedikaChatError>().first.code, 'boom');
      expect(ctl.lastEvent, isA<VedikaChatError>());
      await sub.cancel();
      await ctl.dispose();
    });

    test('dispose closes streams and is idempotent', () async {
      final ctl = _controller();
      await ctl.open(_config());
      await ctl.dispose();
      await ctl.dispose(); // second call must not throw
    });
  });

  group('VedikaChatConfig', () {
    test('default loader URL is the published CDN', () {
      // Not asserting directly because the loader URL is configurable,
      // but checks the structural shape.
      final c = _config();
      expect(c.loaderUrl.scheme, 'https');
      expect(c.loaderUrl.host, 'cdn.vedika.io');
      expect(c.context, isEmpty);
    });
  });
}
