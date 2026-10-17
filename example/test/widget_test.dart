import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  // The example app hosts a WebView and cannot be pumped in a unit-test
  // environment without a platform implementation. We assert the
  // wrapper's import surface and config object instead, which is what
  // the example app relies on.
  test('VedikaChatConfig compiles in the example app', () {
    final cfg = VedikaChatConfig(
      loaderUrl: Uri.parse(
        'https://cdn.vedika.io/chat-widget/v1/loader.js',
      ),
      endUserId: 'app:user:demo',
    );
    expect(cfg.endUserId, 'app:user:demo');
    expect(cfg.loaderUrl.host, 'cdn.vedika.io');
    expect(cfg.threadId, isNull);
  });

  test('VedikaChatController build + dispose do not throw', () {
    final ctl = VedikaChatController(
      tokenProvider: () async => 'vt_example',
    );
    addTearDown(ctl.dispose);
    ctl.open(
      VedikaChatConfig(
        loaderUrl: Uri.parse(
          'https://cdn.vedika.io/chat-widget/v1/loader.js',
        ),
        endUserId: 'app:user:demo',
      ),
    );
    expect(ctl.isOpen, isTrue);
  });
}
