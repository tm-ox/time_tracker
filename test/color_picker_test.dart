import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/widgets/color_picker.dart';

// Smoke coverage for the template colour picker: opening it, the hex↔picker
// wiring, and the Done/Cancel result contract. The spectrum drag maths are
// exercised on-device; here we lock the plumbing that's easy to break.

Future<void> _openPicker(WidgetTester tester, int initial) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showColorPicker(context, initial: initial, label: 'Primary'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  const initial = 0xFF69E228; // template primary green → hex 69E228

  testWidgets('opens showing the initial colour as hex', (tester) async {
    await _openPicker(tester, initial);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.widgetWithText(TextField, '69E228'), findsOneWidget);
  });

  testWidgets('Cancel resolves to null', (tester) async {
    int? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async => captured = await showColorPicker(
                  context,
                  initial: initial,
                  label: 'Primary',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(captured, isNull);
  });

  testWidgets('typing a hex then Done returns that opaque colour', (
    tester,
  ) async {
    int? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async => captured = await showColorPicker(
                  context,
                  initial: initial,
                  label: 'Primary',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '69E228'), 'FF8800');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(captured, 0xFFFF8800);
  });

  testWidgets('presents as a bottom sheet on narrow, a dialog on wide', (
    tester,
  ) async {
    // Narrow → sheet (grab handle present, no Dialog).
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _openPicker(tester, initial);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Wide → dialog.
    tester.view.physicalSize = const Size(1200, 900);
    await _openPicker(tester, initial);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
