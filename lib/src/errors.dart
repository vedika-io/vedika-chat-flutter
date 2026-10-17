/// Base class for all typed exceptions thrown by the wrapper.
sealed class VedikaChatException implements Exception {
  const VedikaChatException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// The [VedikaTokenProvider] returned an empty or null token.
final class VedikaTokenMissingError extends VedikaChatException {
  const VedikaTokenMissingError()
      : super('VedikaTokenProvider returned an empty token');
}

/// The [VedikaTokenProvider] threw or completed with an error.
final class VedikaTokenProviderError extends VedikaChatException {
  const VedikaTokenProviderError(this.cause) : super('token provider failed');

  final Object cause;

  @override
  String toString() =>
      '$runtimeType($message): $cause';
}

/// The chat was opened before a config was supplied, or was opened twice.
final class VedikaChatStateError extends VedikaChatException {
  const VedikaChatStateError(super.message);
}
