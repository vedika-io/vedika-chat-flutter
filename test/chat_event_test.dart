import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

void main() {
  group('VedikaChatEvent', () {
    test('discriminators are stable', () {
      expect(const VedikaChatReady().kind, 'ready');
      expect(const VedikaChatTokenExpired().kind, 'token-expired');
      const finish = VedikaChatFinish('msg_42');
      expect(finish.kind, 'finish');
      expect(finish.messageId, 'msg_42');
      expect(const VedikaChatCancel().kind, 'cancel');
      const ok = VedikaChatSendResult(ok: true);
      expect(ok.kind, 'send-result');
      expect(ok.ok, true);
      const err = VedikaChatError('bundle_unavailable', 'no bundle');
      expect(err.kind, 'error');
      expect(err.code, 'bundle_unavailable');
      expect(err.message, 'no bundle');
    });
  });
}
