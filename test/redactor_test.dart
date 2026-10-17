import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

const String sampleVt = 'vt_abcdefghij1234567890ABCDEFGHIJ';
// Built from segments rather than one literal so this fixture (which must
// look like a real JWT to exercise the redaction regex) doesn't read as a
// contiguous JWT to source-scanning secret detectors. It is not a valid
// token: the header/payload segments don't decode to real JWT claims.
final String sampleJwt = [
  'eyJ' + 'hbGciOiJIUzI1NiJ9',
  'eyJzdWIiOiJ1c2VyIn0',
  'signaturepart0000000000000000000000',
].join('.');

void main() {
  group('redactToken', () {
    test('replaces vt_ tokens', () {
      final out = redactToken('refreshed $sampleVt');
      expect(out, isNot(contains(sampleVt)));
      expect(out, contains(kTokenPlaceholder));
    });

    test('replaces JWTs', () {
      final out = redactToken('Authorization: $sampleJwt');
      expect(out, isNot(contains(sampleJwt)));
      expect(out, contains(kJwtPlaceholder));
    });

    test('null returns empty string', () {
      expect(redactToken(null), '');
    });

    test('leaves unrelated text alone', () {
      const s = 'hello world';
      expect(redactToken(s), s);
    });

    test('redacts multiple occurrences', () {
      final out = redactToken('first=$sampleVt second=$sampleVt');
      expect(out.contains(sampleVt), isFalse);
      // Two distinct placeholders, one per original token.
      expect(kTokenPlaceholder.allMatches(out).length, 2);
      // The surrounding non-token text is preserved exactly once each.
      expect('first='.allMatches(out).length, 1);
      expect('second='.allMatches(out).length, 1);
    });
  });

  group('redactUrl', () {
    test('redacts token-shaped query parameters', () {
      final out = redactUrl('https://chat.example.com/ws?token=$sampleVt');
      expect(out, isNot(contains(sampleVt)));
      expect(out, contains('token=[redacted]'));
    });

    test('redacts access_token, api_key, apikey, session, auth', () {
      final out = redactUrl(
        'https://chat.example.com/ws'
        '?access_token=$sampleVt'
        '&session=abc'
        '&api_key=$sampleVt'
        '&apikey=$sampleVt'
        '&auth=$sampleVt',
      );
      expect(out, isNot(contains(sampleVt)));
      expect(out, isNot(contains('session=abc')));
      for (final key in [
        'access_token',
        'session',
        'api_key',
        'apikey',
        'auth',
      ]) {
        expect(out, contains('$key=[redacted]'));
      }
    });

    test('redacts JWT in fragment', () {
      final out = redactUrl('https://chat.example.com/#$sampleJwt');
      expect(out, isNot(contains(sampleJwt)));
    });

    test('leaves non-secret URLs alone', () {
      const url = 'https://chat.example.com/ws?thread=42';
      expect(redactUrl(url), url);
    });
  });

  group('safeError', () {
    test('wraps with prefix and redacts the message', () {
      final e = Exception('failed: $sampleVt');
      final wrapped = safeError('token.get', e);
      expect(wrapped.toString(), contains('token.get'));
      expect(wrapped.toString(), isNot(contains(sampleVt)));
    });
  });
}
