// ignore_for_file: deprecated_member_use
// New APK02 installations must offer recovery BEFORE occupying active slot.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_preview/apk02_library_main.dart';
import 'package:navin_journal_preview/fictional_activation_consent_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-new-install-widget-');
  });
  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  testWidgets('new installation offers explicit create or recover without '
      'silently creating an active encrypted journal', (tester) async {
    final key = GlobalKey<Apk02LibraryDiagnosticAppState>();
    await tester.pumpWidget(Apk02LibraryDiagnosticApp(
      key: key,
      debugTestPrivateRoot: root,
      debugTestActivationState: FictionalActivationState.notPrepared,
    ));
    await tester.runAsync(() => key.currentState!.waitForFirstBoot());
    await tester.pump();
    final consent = find.byType(FictionalActivationConsentPanel);
    expect(consent, findsOneWidget);
    await tester.runAsync(() => tester
        .state<FictionalActivationConsentPanelState>(consent).waitForIdle());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-choice')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-new-journal')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('fictional-external-import')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('fictional-activation-consent')),
      findsOneWidget);
    expect(Directory('${root.path}/nj_apk02_library_fixture')
      .existsSync(), isFalse);
    expect(File('${root.path}/nj_apk02_library_fixture.activation-reservation')
      .existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('incomplete existing active directory refuses automatic '
      'new vault/reset and does not open setup that could overwrite',
      (tester) async {
    final occupied = Directory('${root.path}/nj_apk02_library_fixture')
      ..createSync();
    final marker = File('${occupied.path}/unknown-stage')
      ..writeAsStringSync('UNKNOWN CURRENT USER STATE');
    final key = GlobalKey<Apk02LibraryDiagnosticAppState>();
    await tester.pumpWidget(Apk02LibraryDiagnosticApp(
      key: key,
      debugTestPrivateRoot: root,
      debugTestActivationState: FictionalActivationState.notPrepared,
    ));
    await tester.runAsync(() => key.currentState!.waitForFirstBoot());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('No data has been reset'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-new-journal')), findsNothing);
    expect(marker.readAsStringSync(), 'UNKNOWN CURRENT USER STATE');
    expect(File('${occupied.path}/journal.sqlite3').existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pending protected candidate blocks creating a new Library '
      'before approval', (tester) async {
    final key = GlobalKey<Apk02LibraryDiagnosticAppState>();
    await tester.pumpWidget(Apk02LibraryDiagnosticApp(
      key: key,
      debugTestPrivateRoot: root,
      debugTestActivationState:
          FictionalActivationState.awaitingExplicitApproval,
    ));
    await tester.runAsync(() => key.currentState!.waitForFirstBoot());
    await tester.pump();
    final consent = find.byType(FictionalActivationConsentPanel);
    await tester.runAsync(() => tester
        .state<FictionalActivationConsentPanelState>(consent).waitForIdle());
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('first-run-new-journal'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    expect(find.byKey(const ValueKey('first-run-candidate-pending')),
      findsOneWidget);
    expect(Directory('${root.path}/nj_apk02_library_fixture')
        .existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('uncertain retained state blocks creating a new Library '
      'without attempting repair', (tester) async {
    final key = GlobalKey<Apk02LibraryDiagnosticAppState>();
    await tester.pumpWidget(Apk02LibraryDiagnosticApp(
      key: key,
      debugTestPrivateRoot: root,
      debugTestActivationState:
          FictionalActivationState.unsafeOrInterrupted,
    ));
    await tester.runAsync(() => key.currentState!.waitForFirstBoot());
    await tester.pump();
    await tester.pumpAndSettle();
    // The existing safety gate blocks the entire setup screen for unknown or
    // interrupted encrypted state. It is safer than a disabled create button.
    expect(find.textContaining('No data has been reset'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-new-journal')),
      findsNothing);
    expect(find.byType(FictionalActivationConsentPanel), findsNothing);
    expect(Directory('${root.path}/nj_apk02_library_fixture')
      .existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  // Stage 5C pre-device regression: simulated viewports are not hardware QA.
  // Critical create/import/recovery controls must stay reachable when Android
  // accessibility text scaling is set to 200%, on narrow phones and tablets.
  for (final viewport in <({String name, Size size})>[
    (name: 'narrow phone', size: const Size(360, 780)),
    (name: 'tablet', size: const Size(800, 1130)),
  ]) {
    testWidgets('first launch remains usable at 200% text on '
        '${viewport.name}', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final key = GlobalKey<Apk02LibraryDiagnosticAppState>();
      await tester.pumpWidget(Apk02LibraryDiagnosticApp(
        key: key,
        debugTestPrivateRoot: root,
        debugTestActivationState: FictionalActivationState.notPrepared,
      ));
      await tester.runAsync(() => key.currentState!.waitForFirstBoot());
      await tester.pump();
      final consent = find.byType(FictionalActivationConsentPanel);
      await tester.runAsync(() => tester
          .state<FictionalActivationConsentPanelState>(consent)
          .waitForIdle());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('first-run-choice')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('import-safety-warning')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('activation-safety-promise')),
          findsOneWidget);

      for (final actionKey in [
        'first-run-new-journal',
        'import-select-document',
        'import-reopen-candidate',
        'activation-refresh',
      ]) {
        final action = find.byKey(ValueKey(actionKey));
        expect(action, findsOneWidget, reason: actionKey);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final rect = tester.getRect(action);
        expect(rect.width, greaterThan(0), reason: actionKey);
        expect(rect.left, greaterThanOrEqualTo(0),
            reason: 'Offscreen left: $actionKey');
        expect(rect.right, lessThanOrEqualTo(viewport.size.width),
            reason: 'Offscreen right: $actionKey');
        expect(tester.takeException(), isNull,
            reason: 'Overflow/paint exception at $actionKey');
      }
      // Responsive review must never silently occupy the active vault.
      expect(Directory('${root.path}/nj_apk02_library_fixture')
          .existsSync(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

}
