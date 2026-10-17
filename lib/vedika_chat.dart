/// Vedika chat Flutter wrapper.
///
/// Hosts the published Vedika chat bundle inside a native
/// [WebView](https://pub.dev/packages/webview_flutter) and forwards chat
/// credentials to the bundle through a [`VedikaTokenProvider`].
///
/// The bundle is the streaming UI and the SSE framer; this package does no
/// network streaming of its own. It is a thin Flutter wrapper that opens the same
/// Vedika chat the web lane ships.
///
/// ```dart
/// import 'package:vedika_chat/vedika_chat.dart';
///
/// final chat = VedikaChatController(
///   tokenProvider: () async => yourBackend.mintChatToken(),
/// );
/// chat.open(
///   // `loaderUrl` defaults to the hosted loader, so chat updates reach the
///   // app without a release.
///   VedikaChatConfig(endUserId: 'app:user:42'),
/// );
/// ```
library;

export 'src/bridge_protocol.dart';
export 'src/chat_config.dart';
export 'src/chat_event.dart';
export 'src/chat_load.dart';
export 'src/chat_offline_view.dart';
export 'src/chat_theme.dart';
export 'src/errors.dart';
export 'src/redactor.dart';
export 'src/token_provider.dart';
export 'src/vedika_chat_controller.dart';
export 'src/vedika_chat_view.dart';
