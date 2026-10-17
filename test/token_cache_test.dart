import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  group('VedikaTokenCache', () {
    test('calls the provider on first get', () async {
      var calls = 0;
      final cache = VedikaTokenCache(() async {
        calls++;
        return 'vt_first';
      });
      expect(await cache.get(), 'vt_first');
      expect(calls, 1);
    });

    test('coalesces concurrent calls', () async {
      var calls = 0;
      final pending = Completer<String>();
      final cache = VedikaTokenCache(() async {
        calls++;
        return pending.future;
      });
      final p1 = cache.get();
      final p2 = cache.get();
      pending.complete('vt_shared');
      expect(await Future.wait([p1, p2]), ['vt_shared', 'vt_shared']);
      expect(calls, 1);
    });

    test('returns the cached token within the refresh window', () async {
      var calls = 0;
      final cache = VedikaTokenCache(
        () async {
          calls++;
          return 'vt_stub';
        },
        refreshAfter: const Duration(minutes: 10),
      );
      await cache.get();
      await cache.get();
      await cache.get();
      expect(calls, 1);
    });

    test('refetches after the refresh window expires', () async {
      var calls = 0;
      final cache = VedikaTokenCache(
        () async {
          calls++;
          return 'vt_$calls';
        },
        refreshAfter: Duration.zero,
      );
      expect(await cache.get(), 'vt_1');
      expect(await cache.get(), 'vt_2');
      expect(calls, 2);
    });

    test('throws when the provider returns an empty token', () async {
      final cache = VedikaTokenCache(() async => '');
      await expectLater(cache.get(), throwsA(isA<VedikaTokenMissingError>()));
    });

    test('invalidate forces the next call to refetch', () async {
      var calls = 0;
      final cache = VedikaTokenCache(
        () async {
          calls++;
          return 'vt_$calls';
        },
        refreshAfter: const Duration(minutes: 10),
      );
      expect(await cache.get(), 'vt_1');
      cache.invalidate();
      expect(await cache.get(), 'vt_2');
    });
  });
}
