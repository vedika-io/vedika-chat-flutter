import 'dart:async';

import 'chat_config.dart';
import 'chat_event.dart';
import 'errors.dart';
import 'redactor.dart';
import 'token_provider.dart';

/// Owns a chat session: opens the bundle, hands tokens to it, forwards
/// lifecycle events out, and exposes a small surface for the host app
/// (track ready/cancel/error, dispose).
///
/// The streaming wire (UI Message Stream v1) runs inside the bundle.
/// The wrapper does not parse SSE on its own.
class VedikaChatController {
  VedikaChatController({
    required VedikaTokenProvider tokenProvider,
    Duration? tokenRefreshAfter,
  })  : _cache = VedikaTokenCache(tokenProvider, refreshAfter: tokenRefreshAfter),
        _events = StreamController<VedikaChatEvent>.broadcast(),
        _tokens = StreamController<String>.broadcast();

  /// In-memory cache used by [refreshToken] to coalesce concurrent
  /// mints and respect the refresh window.
  final VedikaTokenCache _cache;
  final StreamController<VedikaChatEvent> _events;
  final StreamController<String> _tokens;

  /// Whether [open] has been called with a valid config.
  bool get isOpen => _config != null;

  /// Last config passed to [open]. `null` until the first call.
  VedikaChatConfig? _config;
  VedikaChatConfig? get config => _config;

  VedikaChatEvent? _lastEvent;
  VedikaChatEvent? get lastEvent => _lastEvent;

  /// Broadcast stream of parsed bundle events.
  Stream<VedikaChatEvent> get events => _events.stream;

  /// Broadcast stream of token values passed back into the bundle.
  Stream<String> get tokenUpdates => _tokens.stream;

  /// Open a chat with the given [config].
  ///
  /// Idempotent within a single controller instance: calling [open]
  /// again closes the previous session and starts over.
  Future<void> open(VedikaChatConfig config) async {
    _config = config;
    _emit(const VedikaChatReady());
  }

  /// Mint a fresh token through the provider and forward it to the
  /// bundle. Called by [VedikaChatView] on first-ready, on
  /// [VedikaChatTokenExpired] and as a proactive refresh.
  Future<String> refreshToken() async {
    try {
      final value = await _cache.get();
      _tokens.add(value);
      return value;
    } on VedikaChatException {
      rethrow;
    } catch (e) {
      throw VedikaTokenProviderError(safeError('provider', e));
    }
  }

  /// Stop the current turn. The wrapper asks the bundle to cancel via
  /// the cancel channel; the bundle owns the cancel endpoint.
  Future<void> stop() async {
    if (!isOpen) return;
    _emit(const VedikaChatCancel());
  }

  /// Tear down. Safe to call more than once.
  Future<void> dispose() async {
    if (_events.isClosed) return;
    await _events.close();
    if (_tokens.isClosed) return;
    await _tokens.close();
  }

  /// Push an event coming from the bundle into the public stream. Used
  /// by [VedikaChatView]; not part of the host-facing API.
  void reportEvent(VedikaChatEvent event) {
    _emit(event);
  }

  void _emit(VedikaChatEvent event) {
    _lastEvent = event;
    if (!_events.isClosed) _events.add(event);
  }
}
