// Read-only fictional recovery assessment copy: phone/tablet and safety.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_preview/recovery_assessment_review.dart';

Future<void> showReport(
  WidgetTester tester,
  RestoreAssessment report, {
  bool dark = false,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RecoveryAssessmentReview(assessment: report, dark: dark),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void noDestructiveActions(WidgetTester tester) {
  expect(find.byKey(const ValueKey('recovery-no-destructive-action')),
      findsOneWidget);
  expect(find.textContaining('No recovery or deletion'), findsOneWidget);
  expect(find.byType(FilledButton), findsNothing);
  expect(find.byType(TextButton), findsNothing);
  expect(find.byType(OutlinedButton), findsNothing);
  expect(find.byType(IconButton), findsNothing);
}

void main() {
  testWidgets('matched archive reports counts but explicitly stays quarantined',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.verifiedQuarantined,
      publicationMarkerObserved: true,
      journalCount: 2, entryCount: 4,
      revisionCount: 1, attachmentCount: 3,
    ));
    expect(find.text('Encrypted records match'), findsOneWidget);
    expect(find.textContaining('still quarantined'), findsOneWidget);
    expect(find.textContaining('2 journals'), findsOneWidget);
    expect(find.textContaining('3 attachments'), findsOneWidget);
    expect(tester.takeException(), isNull);
    noDestructiveActions(tester);
  });

  testWidgets('untrusted backup never discloses a candidate count', (tester) async {
    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.untrustedArchive,
      publicationMarkerObserved: true,
    ));
    expect(find.text('Backup not authenticated'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-assessment-counts')),
        findsNothing);
    noDestructiveActions(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incomplete and mismatched candidates clearly refuse recovery',
      (tester) async {
    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.incomplete,
      publicationMarkerObserved: false,
    ));
    expect(find.text('Interrupted restore detected'), findsOneWidget);
    expect(find.textContaining('left untouched'), findsOneWidget);
    noDestructiveActions(tester);

    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.notVerified,
      publicationMarkerObserved: true,
    ));
    expect(find.text('Journal contents not verified'), findsOneWidget);
    expect(find.textContaining('remain untouched'), findsOneWidget);
    noDestructiveActions(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unrecognized file candidate blocks any automatic cleanup',
      (tester) async {
    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.blocked,
      publicationMarkerObserved: true,
    ));
    expect(find.text('Unrecognized restore files'), findsOneWidget);
    expect(find.textContaining('No automatic recovery'), findsOneWidget);
    noDestructiveActions(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark tablet assessment remains readable and action-free',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await showReport(tester, const RestoreAssessment(
      status: RestoreAssessmentStatus.verifiedQuarantined,
      publicationMarkerObserved: false,
      journalCount: 1, entryCount: 1,
    ), dark: true);
    expect(find.textContaining('TEST DATA ONLY'), findsOneWidget);
    expect(find.textContaining('1 journals'), findsOneWidget);
    noDestructiveActions(tester);
    expect(tester.takeException(), isNull);
  });
}
