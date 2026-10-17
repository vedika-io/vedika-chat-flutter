import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'chat_load.dart';

/// Plain "Can't reach chat" screen with a Retry button.
///
/// One heading, one line, one button. It shows no URL, no token and no error
/// detail. The container is a live region, so a screen reader announces it
/// when it appears, and the button is a focusable, labelled control that
/// Enter and Space also activate.
///
/// Built from `widgets.dart` only, so it works under a `MaterialApp`, a
/// `CupertinoApp` or a bare `WidgetsApp`. Text takes the surrounding
/// [DefaultTextStyle], so it follows the host app's light or dark theme.
class VedikaChatOfflineView extends StatelessWidget {
  const VedikaChatOfflineView({super.key, required this.onRetry});

  /// Called when the user presses Retry. Must reload the hosted chat from
  /// the network.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final color = base.color ?? const Color(0xFF111111);
    final plain = base.copyWith(
      color: color,
      decoration: TextDecoration.none,
      fontWeight: FontWeight.w400,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      explicitChildNodes: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  kOfflineHeading,
                  textAlign: TextAlign.center,
                  style: plain.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kOfflineBody,
                textAlign: TextAlign.center,
                style: plain.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 24),
              _RetryButton(onPressed: onRetry, color: color, style: plain),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({
    required this.onPressed,
    required this.color,
    required this.style,
  });

  final VoidCallback onPressed;
  final Color color;
  final TextStyle style;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      focusable: true,
      label: kOfflineRetry,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        autofocus: true,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120, minHeight: 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // A thicker outline shows keyboard focus.
                border: Border.all(
                  color: widget.color,
                  width: _focused ? 3 : 1.5,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Center(
                widthFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    kOfflineRetry,
                    style: widget.style.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
