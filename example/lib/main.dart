import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vedika_chat/vedika_chat.dart';

/// Minimal example app that hosts the published Vedika chat bundle
/// inside a WebView. `runExample()` calls a host-defined backend
/// to mint a short-lived `vt_` chat token.
///
/// Replace `mintToken()` with a real backend call in your app. The
/// token stays in memory: the wrapper only forwards it into the
/// bundle.
Future<String> mintToken(VedikaTokenRequest req) async {
  // The default behaviour in this example keeps the wrapper alive by
  // returning a synthetic token. The bundle will reject it; the host
  // app sees a `VedikaChatError` event on the controller's stream and
  // can render a fallback UI.
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return 'vt_example_${req.endUserId}_${DateTime.now().millisecondsSinceEpoch}';
}

class VedikaTokenRequest {
  const VedikaTokenRequest({required this.endUserId, this.threadId});
  final String endUserId;
  final String? threadId;
}

void main() {
  runApp(const VedikaChatExampleApp());
}

class VedikaChatExampleApp extends StatelessWidget {
  const VedikaChatExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedika chat example',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final VedikaChatController _controller;
  VedikaChatEvent? _status;
  StreamSubscription<VedikaChatEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _controller = VedikaChatController(
      tokenProvider: () => mintToken(
        const VedikaTokenRequest(endUserId: 'app:user:demo'),
      ),
    );
    _sub = _controller.events.listen((event) {
      if (mounted) setState(() => _status = event);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vedika chat'),
        actions: [
          IconButton(
            tooltip: 'Stop',
            onPressed: _controller.stop,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.bolt_outlined, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('status: ${_status?.kind ?? 'idle'}')),
              ],
            ),
          ),
          Expanded(
            child: VedikaChatView(
              controller: _controller,
              config: VedikaChatConfig(
                loaderUrl: Uri.parse(
                  'https://cdn.vedika.io/chat-widget/v1/loader.js',
                ),
                endUserId: 'app:user:demo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
