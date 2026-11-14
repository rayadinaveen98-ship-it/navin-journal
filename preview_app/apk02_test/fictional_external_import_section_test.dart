// ignore_for_file: deprecated_member_use
// Strictly fictional Android document import UI acceptance.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_editor/fictional_archive_importer.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';
import 'package:navin_journal_preview/fictional_external_import_section.dart';

const demoKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  Future<void> tapVisible(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('valid separate key shows only aggregate recovery verdict',
      (tester) async {
    var selected = 0;
    var verified = 0;
    var hidden = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SingleChildScrollView(child: FictionalExternalImportSection(
        selectEncryptedDocument: () async {
          selected++;
          return Uint8List.fromList([11, 22, 33]);
        },
        inspect: (bytes, key) async {
          verified++;
          expect(key, demoKey);
          expect(bytes, [11, 22, 33]);
          bytes.fillRange(0, bytes.length, 0);
          return const FictionalArchiveImportReport(
            journals: 2, entries: 4, revisions: 3, attachments: 1);
        },
        hideProtectedInput: () async { hidden++; },
      )),
    )));
    expect(find.byKey(const ValueKey('import-safety-warning')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    await tapVisible(tester, 'import-select-document');
    expect(selected, 1);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-verify')), findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('import-verify'))).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('import-recovery-key')),
      demoKey);
    await tester.pumpAndSettle();
    await tapVisible(tester, 'import-verify');
    expect(verified, 1);
    expect(find.byKey(const ValueKey('import-verified')), findsOneWidget);
    expect(find.textContaining('2 notebooks · 4 pages'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-not-installed')), findsOneWidget);
    expect(find.text(demoKey), findsNothing);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    expect(hidden, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker cancellation never exposes input or changes vault',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalImportSection(
        selectEncryptedDocument: () async { calls++; return null; },
        inspect: (_, _) async => throw const FictionalArchiveImportRejected(),
        hideProtectedInput: () async {},
      ),
    )));
    await tapVisible(tester, 'import-select-document');
    expect(calls, 1);
    expect(find.textContaining('File selection cancelled'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    expect(find.byKey(const ValueKey('import-verified')), findsNothing);
  });

  testWidgets('invalid key remains disabled without invoking restorer',
      (tester) async {
    var attempted = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalImportSection(
        selectEncryptedDocument: () async => Uint8List.fromList([1, 2, 3]),
        inspect: (_, _) async {
          attempted++;
          throw const FictionalArchiveImportRejected();
        },
        hideProtectedInput: () async {},
      ),
    )));
    await tapVisible(tester, 'import-select-document');
    await tester.enterText(find.byKey(const ValueKey('import-recovery-key')),
      'a-short-invalid-key');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('import-verify'))).onPressed, isNull);
    expect(attempted, 0);
    await tapVisible(tester, 'import-cancel');
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
  });

  testWidgets('invalid/corrupted encrypted archive fails without verified UI',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalImportSection(
        selectEncryptedDocument: () async => Uint8List.fromList([1, 2, 3]),
        inspect: (_, _) async =>
            throw const FictionalArchiveImportRejected(),
        hideProtectedInput: () async {},
      ),
    )));
    await tapVisible(tester, 'import-select-document');
    await tester.enterText(find.byKey(const ValueKey('import-recovery-key')),
      demoKey);
    await tester.pumpAndSettle();
    await tapVisible(tester, 'import-verify');
    expect(find.byKey(const ValueKey('import-verified')), findsNothing);
    expect(find.textContaining('Recovery verification failed'),
      findsOneWidget);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
  });

  testWidgets('backgrounding before key submission discards selected bytes',
      (tester) async {
    Uint8List? chosen;
    var hideCalls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalImportSection(
        selectEncryptedDocument: () async {
          chosen = Uint8List.fromList([1, 2, 3, 4]);
          return chosen;
        },
        inspect: (_, _) async =>
            throw const FictionalArchiveImportRejected(),
        hideProtectedInput: () async { hideCalls++; },
      ),
    )));
    await tapVisible(tester, 'import-select-document');
    final state = tester.state<FictionalExternalImportSectionState>(
      find.byType(FictionalExternalImportSection));
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    expect(chosen, isNotNull);
    expect(chosen!.every((byte) => byte == 0), isTrue);
    expect(hideCalls, 1);
  });

  testWidgets('during file picker duplicate import is disabled',
      (tester) async {
    final pending = Completer<Uint8List?>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalImportSection(
        selectEncryptedDocument: () {
          calls++;
          return pending.future;
        },
        inspect: (_, _) async =>
            throw const FictionalArchiveImportRejected(),
        hideProtectedInput: () async {},
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('import-select-document')));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('import-select-document'))).onPressed, isNull);
    expect(calls, 1);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-progress')), findsNothing);
  });
  testWidgets('explicit fictional candidate retention and later independent '
      'reopen never claim activation', (tester) async {
    var retained = 0;
    var reopened = 0;
    const report = FictionalRetainedRecoveryReport(
      journals: 1, entries: 2, revisions: 3, attachments: 0);
    Future<FictionalRetainedRecoveryReport> retain(
        Uint8List bytes, String key) async {
      retained++;
      expect(key, demoKey);
      expect(bytes, [4, 5, 6, 7]);
      return report;
    }
    Future<FictionalRetainedRecoveryReport> reopen() async {
      reopened++;
      return report;
    }
    Widget app() => MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: FictionalExternalImportSection(
        selectEncryptedDocument: () async =>
            Uint8List.fromList([4, 5, 6, 7]),
        inspect: (_, _) async =>
            throw const FictionalArchiveImportRejected(),
        hideProtectedInput: () async {},
        retainCandidate: retain,
        reopenCandidate: reopen,
      ),
    )));
    await tester.pumpWidget(app());
    await tapVisible(tester, 'import-select-document');
    await tester.enterText(
      find.byKey(const ValueKey('import-recovery-key')), demoKey);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-retain-warning')),
      findsOneWidget);
    await tapVisible(tester, 'import-retain-candidate');
    expect(retained, 1);
    expect(find.byKey(const ValueKey('import-retained-verified')),
      findsOneWidget);
    expect(find.textContaining('QUARANTINED CANDIDATE ONLY'),
      findsOneWidget);
    expect(find.byKey(const ValueKey('import-verified')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tapVisible(tester, 'import-reopen-candidate');
    expect(reopened, 1);
    expect(find.byKey(const ValueKey('import-retained-verified')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('import-retained-not-activated')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('occupied candidate keeps failure neutral and leaves no '
      'success or activated-journal UI', (tester) async {
    var tries = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      SingleChildScrollView(child: FictionalExternalImportSection(
        selectEncryptedDocument: () async => Uint8List.fromList([8, 9]),
        inspect: (_, _) async =>
            throw const FictionalArchiveImportRejected(),
        retainCandidate: (_, _) async {
          tries++;
          throw const FictionalRetainedRecoveryRejected();
        },
        reopenCandidate: () async =>
            throw const FictionalRetainedRecoveryRejected(),
        hideProtectedInput: () async {},
      )),
    )));
    await tapVisible(tester, 'import-select-document');
    await tester.enterText(
      find.byKey(const ValueKey('import-recovery-key')), demoKey);
    await tester.pumpAndSettle();
    await tapVisible(tester, 'import-retain-candidate');
    expect(tries, 1);
    expect(find.textContaining('A reserved candidate'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-retained-verified')),
      findsNothing);
    expect(find.byKey(const ValueKey('import-recovery-key')), findsNothing);
    await tapVisible(tester, 'import-reopen-candidate');
    expect(find.textContaining('could not reopen'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-retained-verified')),
      findsNothing);
    expect(tester.takeException(), isNull);
  });

}
