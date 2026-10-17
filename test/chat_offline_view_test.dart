import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vedika_chat/vedika_chat.dart';

Widget host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(data: const MediaQueryData(), child: child),
    );

void main() {
  testWidgets('shows the heading, one line and one Retry button', (tester) async {
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () {})));

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(texts, [
      "Can't reach chat",
      'Check your connection and try again.',
      'Retry',
    ]);
  });

  testWidgets('renders no URL and no token-shaped text', (tester) async {
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () {})));
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.data, isNot(contains('http')));
      expect(t.data, isNot(contains('vt_')));
    }
  });

  testWidgets('tapping Retry calls onRetry once per tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () => taps++)));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('Enter and Space activate Retry from the keyboard', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () => taps++)));
    await tester.pump(); // let autofocus settle

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('the container is a live region and the heading is a header', (tester) async {
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () {})));
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.header == true),
      findsOneWidget,
    );
  });

  testWidgets('Retry is a labelled, focusable button with a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () => taps++)));
    await tester.pump();

    final node = tester.getSemantics(find.bySemanticsLabel('Retry'));
    expect(
      node,
      containsSemantics(
        label: 'Retry',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );

    tester.semantics.tap(find.semantics.byLabel('Retry'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('the Retry button meets the 48 point touch target', (tester) async {
    await tester.pumpWidget(host(VedikaChatOfflineView(onRetry: () {})));
    final size = tester.getSize(find.byType(DecoratedBox).last);
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });
}
