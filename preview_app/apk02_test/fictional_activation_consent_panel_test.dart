// ignore_for_file: deprecated_member_use
// Fictional-only user approval gate: a picker/import is NOT activation consent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';
import 'package:navin_journal_preview/fictional_activation_consent_panel.dart';

void main() {
  Widget shell({
    required Future<FictionalActivationState> Function() inspect,
    required Future<FictionalActivationReceipt> Function() approve,
    Future<void> Function()? onActivated,
  }) => MaterialApp(home: Scaffold(body: SingleChildScrollView(
    child: FictionalActivationConsentPanel(
      inspect: inspect,
      activateApproved: approve,
      onActivated: onActivated,
    ),
  )));

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('no candidate: never offers an activation button',
      (tester) async {
    var activated = 0;
    await tester.pumpWidget(shell(
      inspect: () async => FictionalActivationState.notPrepared,
      approve: () async {
        activated++;
        throw const FictionalActivationRejected();
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activation-not-prepared')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('activation-approve')), findsNothing);
    expect(activated, 0);
  });

  testWidgets('typed phrase AND separate acknowledgment required before '
      'activation callback', (tester) async {
    var activated = 0;
    var completed = 0;
    await tester.pumpWidget(shell(
      inspect: () async => FictionalActivationState.awaitingExplicitApproval,
      approve: () async {
        activated++;
        return const FictionalActivationReceipt(
          journals: 2, entries: 3, revisions: 4, attachments: 1);
      },
      onActivated: () async { completed++; },
    ));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('activation-approve'));
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('activation-confirmation')),
      'ACTIVATE FICTIONAL JOURNAL');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    // A typo, even with acknowledgment, must prevent invoking the service.
    await tester.enterText(
      find.byKey(const ValueKey('activation-confirmation')), 'ACTIVATE');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(activated, 0);
    await tester.enterText(
      find.byKey(const ValueKey('activation-confirmation')),
      'ACTIVATE FICTIONAL JOURNAL');
    await tester.pumpAndSettle();
    await tap(tester, 'activation-approve');
    expect(activated, 1);
    expect(completed, 1);
    expect(find.byKey(const ValueKey('activation-verified')), findsOneWidget);
    expect(find.textContaining('2 notebooks · 3 pages'), findsOneWidget);
    expect(find.byKey(const ValueKey('activation-confirmation')),
      findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('occupied/uncertain destination can never be approved',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(shell(
      inspect: () async =>
          FictionalActivationState.unsafeOrInterrupted,
      approve: () async {
        calls++;
        throw const FictionalActivationRejected();
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activation-blocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('activation-approve')), findsNothing);
    expect(calls, 0);
  });

  testWidgets('failed ambiguous activation does not announce success or '
      'suggest deletion or automatic retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(shell(
      inspect: () async =>
          FictionalActivationState.awaitingExplicitApproval,
      approve: () async {
        calls++;
        throw const FictionalActivationRejected();
      },
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activation-confirmation')),
      'ACTIVATE FICTIONAL JOURNAL');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tap(tester, 'activation-approve');
    expect(calls, 1);
    expect(find.byKey(const ValueKey('activation-verified')), findsNothing);
    expect(find.byKey(const ValueKey('activation-blocked')), findsOneWidget);
    expect(find.textContaining('Do not retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('activation-approve')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight activation blocks duplicate submission',
      (tester) async {
    final pending = Completer<FictionalActivationReceipt>();
    var calls = 0;
    await tester.pumpWidget(shell(
      inspect: () async =>
          FictionalActivationState.awaitingExplicitApproval,
      approve: () {
        calls++;
        return pending.future;
      },
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activation-confirmation')),
      'ACTIVATE FICTIONAL JOURNAL');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('activation-approve')));
    await tester.pump();
    expect(calls, 1);
    expect(find.byKey(const ValueKey('activation-approve')), findsNothing);
    pending.complete(const FictionalActivationReceipt(
      journals: 1, entries: 1, revisions: 0, attachments: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('activation-verified')), findsOneWidget);
  });
}
