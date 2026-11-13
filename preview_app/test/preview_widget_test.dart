// ignore_for_file: deprecated_member_use
// Design-preview integration smoke tests. No private content or persistence.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_preview/main.dart';

void sizePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

Future<void> startSample(WidgetTester tester) async {
  await tester.pumpWidget(const JournalPreviewApp());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('explore-preview')));
  await tester.tap(find.byKey(const ValueKey('explore-preview')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('start-preview')));
  await tester.tap(find.byKey(const ValueKey('start-preview')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('welcome and setup lead to sample Today without account', (tester) async {
    sizePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JournalPreviewApp());
    expect(find.textContaining('DESIGN PREVIEW'), findsWidgets);
    expect(find.byKey(const ValueKey('explore-preview')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('explore-preview')));
    await tester.tap(find.byKey(const ValueKey('explore-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal-name-field')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('start-preview')));
    await tester.tap(find.byKey(const ValueKey('start-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nav-today')), findsOneWidget);
    expect(find.byKey(const ValueKey('write-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four navigation destinations work at phone width', (tester) async {
    sizePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startSample(tester);
    await tester.tap(find.byKey(const ValueKey('nav-journals')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every story has'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-memories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('memory-calendar')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memory-gallery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-discover')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-input')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search-input')), 'train');
    await tester.pumpAndSettle();
    expect(find.text('A train window'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sample reader opens and back returns to browsing', (tester) async {
    sizePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startSample(tester);
    await tester.tap(find.byKey(const ValueKey('entry-0')));
    await tester.pumpAndSettle();
    expect(find.text('The quiet hour'), findsOneWidget);
    expect(find.textContaining('fictional demo content'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('write-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('writer explicitly refuses to silently discard preview text', (tester) async {
    sizePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startSample(tester);
    await tester.tap(find.byKey(const ValueKey('write-entry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('NOT SAVED'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('preview-body')),
      'This is only imaginary test content.');
    await tester.tap(find.byKey(const ValueKey('close-writer')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this preview page?'), findsOneWidget);
    await tester.tap(find.text('Keep reviewing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview-body')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-writer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard demo text'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('write-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Midnight Archive theme changes without losing navigation', (tester) async {
    sizePhone(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startSample(tester);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Settings').last);
    expect(text.data, 'Settings');
    expect(Theme.of(tester.element(find.byKey(const ValueKey('theme-dark')))).brightness,
      Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet layout uses quiet sidebar with the same destinations', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await startSample(tester);
    expect(find.byKey(const ValueKey('nav-journals')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-discover')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-memories')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Moments that'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
