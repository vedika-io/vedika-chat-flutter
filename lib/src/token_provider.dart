import 'dart:async';

import 'errors.dart';

/// A function that returns a short-lived Vedika chat token.
///
/// Equivalent to the `tokenProvider` hook documented in
/// React Native, iOS and Android wrappers. Implementations
/// typically call the customer's backend, which then mints a `vt_`
/// token via `POST /api/v1/embed/tokens` on the Vedika API.
///
/// Tokens are short-lived (15 minutes by default). The wrapper refreshes
/// tokens opportunistically and on `VedikaChatTokenExpired` events.
typedef VedikaTokenProvider = Future<String> Function();

/// Static [VedikaTokenProvider] that always returns the same value.
///
/// Use only in tests or in environments where a long-lived credential is
/// acceptable. Production callers should mint tokens through a backend.
class StaticTokenProvider {
  StaticTokenProvider(this._token);

  String _token;
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  /// Currently issued token.
  String get token => _token;

  /// Replace the issued token. Future `token()` calls return the new value
  /// and a change event is emitted on [changes].
  void setToken(String value) {
    _token = value;
    _changes.add(value);
  }

  /// Broadcast stream of token values, one per `setToken` call.
  Stream<String> get changes => _changes.stream;

  Future<String> call() async {
    if (_token.isEmpty) {
      throw const VedikaTokenMissingError();
    }
    return _token;
  }

  Future<void> close() async {
    await _changes.close();
  }
}

/// In-memory cache that calls a [VedikaTokenProvider] at most once per
/// refresh window. Mirrors the React Native `TokenCache` so the
/// behaviour is identical across the M-RN and M-FL lanes.
///
/// The cache is single-use: each [VedikaChatController] creates its
/// own instance so a stale token cannot leak across chat sessions.
class VedikaTokenCache {
  VedikaTokenCache(this._provider, {Duration? refreshAfter})
      : _refreshAfter = refreshAfter ?? const Duration(minutes: 10);

  final VedikaTokenProvider _provider;
  final Duration _refreshAfter;
  String? _cached;
  DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String>? _inflight;

  /// Return a token, reusing the cached one if it is still fresh.
  /// Concurrent callers share a single in-flight request.
  Future<String> get() async {
    final now = DateTime.now();
    if (_cached != null && now.difference(_cachedAt) < _refreshAfter) {
      return _cached!;
    }
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final future = () async {
      try {
        final value = await _provider();
        if (value.isEmpty) {
          throw const VedikaTokenMissingError();
        }
        _cached = value;
        _cachedAt = DateTime.now();
        return value;
      } finally {
        _inflight = null;
      }
    }();
    _inflight = future;
    return future;
  }

  /// Force the next [get] to call the provider again.
  void invalidate() {
    _cached = null;
    _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
