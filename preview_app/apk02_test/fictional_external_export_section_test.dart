// ignore_for_file: deprecated_member_use
// No private data and no real Android SAF transaction in widget tests.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_preview/fictional_external_export_section.dart';
import 'package:navin_journal_editor/fictional_archive_exporter.dart';

const safeKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'; // 43 chars.

void main() {
  testWidgets('manual key appears only after verified external write, '
      'and explicitly is not a clean-device backup', (tester) async {
    var hidden = 0;
    var saves = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: FictionalExternalExportSection(
        export: () async {
          saves++;
          return const FictionalArchiveExportReceipt(
            manualRecoveryKey: safeKey,
            encryptedArchiveBytes: 4123,
            providerReadbackVerified: true,
          );
        },
        hideKey: () async { hidden++; },
      ),
    ))));
    expect(find.byKey(const ValueKey('external-recovery-key')), findsNothing);
    expect(find.textContaining('does not establish recoverability'),
      findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.byKey(const ValueKey('external-export-success')), findsOneWidget);
    expect(find.text(safeKey), findsOneWidget);
    expect(find.textContaining('NOT A VERIFIED BACKUP'), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('external-export-dismiss-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('external-export-dismiss-key')));
    await tester.pumpAndSettle();
    expect(find.text(safeKey), findsNothing);
    expect(hidden, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker cancellation reveals no key, retry remains available',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalExportSection(
        export: () async { calls++; return null; },
        hideKey: () async {},
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('Export cancelled'), findsOneWidget);
    expect(find.byKey(const ValueKey('external-recovery-key')), findsNothing);
    expect(tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('external-export-start'))).onPressed,
      isNotNull);
  });

  testWidgets('failed provider readback hides key and warns about partial file',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalExportSection(
        export: () async => throw const FictionalExportUnavailable(),
        hideKey: () async {},
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('partial or unusable'), findsOneWidget);
    expect(find.byKey(const ValueKey('external-export-success')), findsNothing);
    expect(find.byKey(const ValueKey('external-recovery-key')), findsNothing);
  });

  testWidgets('invalid receipt never reveals key or a verified success',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalExportSection(
        export: () async => const FictionalArchiveExportReceipt(
          manualRecoveryKey: safeKey,
          encryptedArchiveBytes: 4123,
          providerReadbackVerified: false,
        ),
        hideKey: () async {},
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('external-recovery-key')), findsNothing);
    expect(find.byKey(const ValueKey('external-export-success')), findsNothing);
  });

  testWidgets('duplicate export blocked during active system picker',
      (tester) async {
    final release = Completer<FictionalArchiveExportReceipt?>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalExportSection(
        export: () {
          calls++;
          return release.future;
        },
        hideKey: () async {},
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pump();
    expect(find.byKey(const ValueKey('external-export-progress')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('external-export-start'))).onPressed,
      isNull);
    expect(calls, 1);
    release.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('external-export-progress')), findsNothing);
  });

  testWidgets('background immediately forgets key without keeping text',
      (tester) async {
    var hidden = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      FictionalExternalExportSection(
        export: () async => const FictionalArchiveExportReceipt(
          manualRecoveryKey: safeKey,
          encryptedArchiveBytes: 42,
          providerReadbackVerified: true,
        ),
        hideKey: () async { hidden++; },
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('external-export-start')));
    await tester.pumpAndSettle();
    expect(find.text(safeKey), findsOneWidget);
    final state = tester.state<FictionalExternalExportSectionState>(
      find.byType(FictionalExternalExportSection));
    state.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.text(safeKey), findsNothing);
    expect(hidden, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(hidden, greaterThanOrEqualTo(2));
  });
}
