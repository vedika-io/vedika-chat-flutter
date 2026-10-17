import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  group('StaticTokenProvider', () {
    test('returns the issued token', () async {
      final tp = StaticTokenProvider('vt_initial');
      expect(tp.token, 'vt_initial');
      await expectLater(tp(), completion('vt_initial'));
    });

    test('throws when token is empty', () async {
      final tp = StaticTokenProvider('');
      await expectLater(
        Future(() async => tp()),
        throwsA(isA<VedikaTokenMissingError>()),
      );
    });

    test('setToken replaces the value and emits a change', () async {
      final tp = StaticTokenProvider('vt_one');
      final changes = <String>[];
      final sub = tp.changes.listen(changes.add);
      tp.setToken('vt_two');
      // Let the broadcast stream drain.
      await Future<void>.delayed(Duration.zero);
      expect(tp.token, 'vt_two');
      expect(changes, ['vt_two']);
      await sub.cancel();
      await tp.close();
    });
  });
}
