/// Events the chat bundle posts back into native code.
sealed class VedikaChatEvent {
  const VedikaChatEvent(this.kind);

  /// Discriminator: `ready`, `token-expired`, `finish`, `cancel`, `error`,
  /// or `send-result`.
  final String kind;
}

/// Bundle has loaded and is requesting its first token. The wrapper
/// responds by calling the [`VedikaTokenProvider`] and posting the token
/// back via `VedikaChatView.postToken`.
final class VedikaChatReady extends VedikaChatEvent {
  const VedikaChatReady() : super('ready');
}

/// The bundle's token is about to expire; the wrapper should mint a fresh
/// one and post it back. The wrapper also refreshes opportunistically
/// before the bundle asks, so receiving this event means a refresh
/// already failed and is being retried.
final class VedikaChatTokenExpired extends VedikaChatEvent {
  const VedikaChatTokenExpired() : super('token-expired');
}

/// Turn completed successfully. Carries the final message id.
final class VedikaChatFinish extends VedikaChatEvent {
  const VedikaChatFinish(this.messageId) : super('finish');

  final String messageId;
}

/// The user asked to stop mid-turn. The bundle has already called the
/// cancel endpoint; native is just notified.
final class VedikaChatCancel extends VedikaChatEvent {
  const VedikaChatCancel() : super('cancel');
}

/// The bundle acked a send request that the wrapper pushed into the
/// page. Pure telemetry; no action required.
final class VedikaChatSendResult extends VedikaChatEvent {
  const VedikaChatSendResult({required this.ok}) : super('send-result');

  final bool ok;
}

/// The bundle reported a fatal error. The wrapper will not auto-retry.
final class VedikaChatError extends VedikaChatEvent implements Exception {
  const VedikaChatError(this.code, this.message) : super('error');

  final String code;

  final String message;

  @override
  String toString() => 'VedikaChatError($code: $message)';
}
