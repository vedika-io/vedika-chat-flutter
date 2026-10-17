import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  test('VedikaChatConfig holds the loader URL, end user id and context', () {
    final c = VedikaChatConfig(
      loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
      endUserId: 'app:user:42',
      threadId: 'thread_1',
      context: {'locale': 'en-GB', 'slot': 'home'},
    );
    expect(c.loaderUrl.toString(),
        'https://cdn.vedika.io/chat-widget/v1/loader.js');
    expect(c.endUserId, 'app:user:42');
    expect(c.threadId, 'thread_1');
    expect(c.context['locale'], 'en-GB');
  });

  test('VedikaChatConfig with default context is empty', () {
    final c = VedikaChatConfig(
      loaderUrl: Uri.parse('https://example.com/loader.js'),
      endUserId: 'app:user:1',
    );
    expect(c.context, isEmpty);
    expect(c.threadId, isNull);
  });

  test('VedikaChatConfig defaults to the hosted loader', () {
    final c = VedikaChatConfig(endUserId: 'app:user:1');
    expect(c.loaderUrl, kDefaultLoaderUrl);
    expect(c.loaderUrl.toString(),
        'https://cdn.vedika.io/chat-widget/v1/loader.js');
    expect(c.isHostedLoader, isTrue);
  });

  test('plain http is refused, https and a bundled file are not', () {
    expect(
      () => VedikaChatConfig(
        loaderUrl: Uri.parse('http://cdn.vedika.io/chat-widget/v1/loader.js'),
        endUserId: 'app:user:1',
      ),
      throwsArgumentError,
    );
    expect(
      () => VedikaChatConfig(
        loaderUrl: Uri.parse('http://localhost:8080/loader.js'),
        endUserId: 'app:user:1',
      ),
      throwsArgumentError,
    );
    expect(
      VedikaChatConfig(
        loaderUrl: Uri.parse('https://cdn.vedika.io/chat-widget/v1/loader.js'),
        endUserId: 'app:user:1',
      ).isHostedLoader,
      isTrue,
    );
  });

  test('a bundled file URL is an explicit opt-in and is not hosted', () {
    final c = VedikaChatConfig(
      loaderUrl: Uri.parse('file:///data/app/chat/loader.js'),
      endUserId: 'app:user:1',
    );
    expect(c.loaderUrl.scheme, 'file');
    expect(c.isHostedLoader, isFalse);
  });

  test('an explicit https loader is hosted', () {
    final c = VedikaChatConfig(
      loaderUrl: Uri.parse('https://chat.example.com/loader.js'),
      endUserId: 'app:user:1',
    );
    expect(c.isHostedLoader, isTrue);
  });
}
