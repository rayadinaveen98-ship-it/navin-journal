// The physical Keyboard Lab is nonpersistent and accepts only fictional QA.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_keyboard_lab/fictional_keyboard_lab.dart';

void main() {
  testWidgets('lab starts empty, private-writing warning remains visible',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    final state = tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab));
    expect(state.titleInput.text, isEmpty);
    expect(state.bodyInput.text, isEmpty);
    expect(find.byKey(const ValueKey('lab-no-private-warning')),
      findsOneWidget);
    expect(find.textContaining('Nothing here is saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-body')), findsOneWidget);
    expect(state.sanitizedChecklist,
      contains('NO user-entered text is included.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual typing updates transient controllers, reset erases',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    final state = tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab));
    await tester.enterText(find.byKey(const ValueKey('lab-title')),
      fictionalKeyboardTitle);
    await tester.enterText(find.byKey(const ValueKey('lab-body')),
      fictionalKeyboardBody);
    await tester.pump();
    expect(state.titleInput.text, fictionalKeyboardTitle);
    expect(state.bodyInput.text, fictionalKeyboardBody);
    expect(state.sanitizedChecklist, isNot(contains(fictionalKeyboardTitle)));
    expect(state.sanitizedChecklist, isNot(contains(fictionalKeyboardBody)));
    await tester.ensureVisible(find.byKey(const ValueKey('lab-reset')));
    await tester.tap(find.byKey(const ValueKey('lab-reset')));
    await tester.pumpAndSettle();
    expect(state.titleInput.text, isEmpty);
    expect(state.bodyInput.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live composing state does not claim native keyboard tested',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    final state = tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab));
    const prefix = 'తెలు';
    state.bodyInput.value = const TextEditingValue(
      text: prefix,
      selection: TextSelection.collapsed(offset: prefix.length),
      composing: TextRange(start: 0, end: prefix.length),
    );
    await tester.pump();
    expect(state.isComposing, isTrue);
    expect(find.text('Keyboard composition is in progress'), findsOneWidget);

    state.bodyInput.value = const TextEditingValue(
      text: 'తెలుగు',
      selection: TextSelection.collapsed(offset: 6),
    );
    await tester.pump();
    expect(state.isComposing, isFalse);
    expect(find.text('No active keyboard composing range'), findsOneWidget);
    expect(state.sanitizedChecklist, contains('NOT VERIFIED'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('checklist records only user-selected checks, no input content',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    final state = tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab));
    await tester.enterText(find.byKey(const ValueKey('lab-body')),
      'NEVER_COPY_PERSONAL_CONTENT_QA_ONLY');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('lab-check-teluguComposition')));
    await tester.tap(
      find.byKey(const ValueKey('lab-check-teluguComposition')));
    await tester.pumpAndSettle();
    expect(state.sanitizedChecklist, contains(
      'Telugu Gboard composition and conjuncts: USER CHECKED'));
    expect(state.sanitizedChecklist,
      contains('200% font scale and reflow: NOT VERIFIED'));
    expect(state.sanitizedChecklist,
      isNot(contains('NEVER_COPY_PERSONAL_CONTENT_QA_ONLY')));
    expect(find.text('User-marked: 1 / 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inserting sample is explicitly not evidence of typing',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    final state = tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab));
    await tester.ensureVisible(find.byKey(const ValueKey('lab-insert-sample')));
    await tester.tap(find.byKey(const ValueKey('lab-insert-sample')));
    await tester.pumpAndSettle();
    expect(state.bodyInput.text, fictionalKeyboardBody);
    expect(find.text('Inserted by the app: NOT a real keyboard test.'),
      findsOneWidget);
    expect(state.sanitizedChecklist, isNot(contains(fictionalKeyboardBody)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('relaunch discards unpersisted temporary rehearsal text',
      (tester) async {
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    await tester.enterText(find.byKey(const ValueKey('lab-title')),
      'Temporary purely fictional rehearsal');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const FictionalKeyboardLabApp());
    expect(tester.state<FictionalKeyboardLabState>(
      find.byType(FictionalKeyboardLab)).titleInput.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone tablet landscape and 200% text layout stays reachable',
      (tester) async {
    for (final size in [
      const Size(360, 720),
      const Size(800, 1100),
      const Size(1100, 800),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 250),
          ),
          child: const FictionalKeyboardLab(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('lab-body')));
      expect(find.byKey(const ValueKey('lab-body')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('lab-copy-checklist')));
      expect(find.byKey(const ValueKey('lab-copy-checklist')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
