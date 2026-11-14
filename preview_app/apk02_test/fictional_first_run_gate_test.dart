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
}
