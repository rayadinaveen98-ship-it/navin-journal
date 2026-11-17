// ignore_for_file: deprecated_member_use
// APK02 widget tests: all data fictional; no Android keys or user input.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_preview/connected_writing_studio.dart';
import 'package:navin_journal_preview/fictional_conflict_review_sheet.dart';

const fixture = FictionalWritingPreset(
  'The quiet hour', 'A fictional day. ఈ రోజు ప్రశాంతంగా ఉంది.',
);

class FakeEncryptedPort implements DraftCommitPort {
  int storedVersion = 0;
  DraftContent? stored;
  bool fail = false;
  bool conflict = false;
  int commits = 0;
  Completer<void>? gate;

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    commits++;
    final held = gate;
    if (held != null) await held.future;
    if (conflict || expectedVersion != storedVersion) {
      throw const DraftConflict();
    }
    if (fail) throw StateError('Simulated failure, no acknowledgement');
    if (content.isBlank) throw StateError('Empty page not persisted');
    stored = content;
    storedVersion++;
    return CommitReceipt(entryId, storedVersion);
  }
}

class WidgetHarness {
  final FakeEncryptedPort port;
  final DraftAutosaveController controller;
  final EditorSaveNotifier updates;
  WidgetHarness(this.port, this.controller, this.updates);
}

Future<WidgetHarness> mount(
  WidgetTester tester, {
  required VoidCallback onClose,
  bool scriptOnly = true,
  Future<void> Function(SaveIndicator)? onAcknowledged,
  Future<Map<String, Object?>?> Function()? loadNewestSavedConflict,
  Future<ConflictReviewCopyReceipt> Function()? preserveConflictAsNew,
}) async {
  final port = FakeEncryptedPort();
  late EditorSaveNotifier notifier;
  final controller = DraftAutosaveController(
    entryId: 'fictional-only',
    storage: port,
    debounce: const Duration(days: 1),
    onIndicator: (value) => notifier.acknowledge(value),
  );
  notifier = EditorSaveNotifier(controller.indicator);
  addTearDown(() {
    controller.abandonFictionalTestDraft();
    notifier.dispose();
  });
  await tester.pumpWidget(MaterialApp(home: ConnectedWritingStudio(
    controller: controller,
    saveStatus: notifier,
    fixture: fixture,
    scriptOnly: scriptOnly,
    journalName: 'Fictional Pages',
    onAcknowledged: onAcknowledged,
    onClose: onClose,
    loadNewestSavedConflict: loadNewestSavedConflict,
    preserveConflictAsNew: preserveConflictAsNew,
  )));
  await tester.pumpAndSettle();
  return WidgetHarness(port, controller, notifier);
}

void main() {
  testWidgets('script-only editor is read-only and shows explicit preview notice',
      (tester) async {
    final harness = await mount(tester, onClose: () {});
    expect(find.textContaining('FICTIONAL DATA ONLY'), findsOneWidget);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('connected-title'))).readOnly, isTrue);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('connected-body'))).readOnly, isTrue);
    expect(harness.controller.indicator.phase, SavePhase.pristine);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scripted sample saves and only then declares Saved locally',
      (tester) async {
    var acknowledgements = 0;
    final harness = await mount(tester,
      onClose: () {},
      onAcknowledged: (state) async {
        expect(state.databaseVersion, 1);
        expect(state.mayLeaveSafely, isTrue);
        acknowledgements++;
      },
    );
    expect(find.text('Nothing to save'), findsOneWidget);
    await tester.ensureVisible(find.byKey(
      const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    expect(harness.port.stored, DraftContent(
      title: fixture.title, body: fixture.body));
    expect(find.text('Saved locally · version 1'), findsOneWidget);
    expect(acknowledgements, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save blocks closing, retry enables safe exit',
      (tester) async {
    var closed = false;
    final harness = await mount(tester,
      onClose: () => closed = true);
    harness.port.fail = true;
    await tester.ensureVisible(find.byKey(
      const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    expect(harness.controller.indicator.phase, SavePhase.error);
    expect(harness.controller.indicator.mayLeaveSafely, isFalse);
    expect(find.textContaining('Save failed'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(find.text('Your changes are not safely saved'), findsOneWidget);
    expect(closed, isFalse);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    harness.port.fail = false;
    await tester.ensureVisible(find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(find.text('Saved locally · version 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict cannot be silently marked saved or dismissed',
      (tester) async {
    var closed = false;
    final harness = await mount(tester,
      onClose: () => closed = true);
    harness.port.conflict = true;
    await tester.ensureVisible(find.byKey(
      const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    expect(harness.controller.indicator.phase, SavePhase.conflict);
    expect(find.textContaining('Edit conflict'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(find.text('Your changes are not safely saved'), findsOneWidget);
    expect(find.textContaining('Automatic saves are paused'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    expect(closed, isFalse);
    expect(harness.port.stored, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit after a conflict never resumes automatic or manual save',
      (tester) async {
    var callbacks = 0;
    var closed = false;
    final harness = await mount(tester,
      onClose: () => closed = true,
      scriptOnly: false,
      onAcknowledged: (_) async { callbacks++; },
    );
    harness.port.conflict = true;
    await tester.enterText(
      find.byKey(const ValueKey('connected-title')), 'Fiction conflict');
    await tester.enterText(
      find.byKey(const ValueKey('connected-body')), 'One imagined edit');
    await tester.ensureVisible(find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.controller.hasUnresolvedConflict, isTrue);
    expect(harness.controller.indicator.phase, SavePhase.conflict);
    final attempts = harness.port.commits;
    expect(callbacks, 0);

    harness.port.conflict = false;
    await tester.enterText(
      find.byKey(const ValueKey('connected-body')),
      'A different fictional continuation');
    await tester.pump();
    expect(harness.controller.indicator.phase, SavePhase.conflict);
    expect(harness.controller.draft.body,
      'A different fictional continuation');
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.commits, attempts);
    expect(callbacks, 0);
    expect(harness.port.stored, isNull);
    expect(find.textContaining('Edit conflict'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Automatic saves are paused'), findsOneWidget);
    expect(find.text('Retry saving'), findsNothing);
    expect(closed, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty editor can close without falsely creating a page',
      (tester) async {
    var closed = false;
    final harness = await mount(tester,
      onClose: () => closed = true);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(harness.port.stored, isNull);
    expect(harness.controller.indicator.phase, SavePhase.pristine);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fictional actual TextFields update the same autosave controller',
      (tester) async {
    final harness = await mount(tester,
      onClose: () {}, scriptOnly: false);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('connected-body'))).readOnly, isFalse);
    await tester.enterText(find.byKey(const ValueKey('connected-title')),
      'Fictional manual test');
    await tester.enterText(find.byKey(const ValueKey('connected-body')),
      'Only imagined test content');
    await tester.pump();
    expect(harness.controller.indicator.phase, SavePhase.dirty);
    await tester.ensureVisible(find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.stored!.title, 'Fictional manual test');
    expect(harness.port.stored!.body, 'Only imagined test content');
    expect(harness.controller.indicator.phase, SavePhase.saved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synthetic Telugu composition stays editable in memory and blocks close',
      (tester) async {
    var closed = false;
    final harness = await mount(tester, onClose: () => closed = true);
    final view = tester.state<ConnectedWritingStudioState>(
      find.byType(ConnectedWritingStudio));

    const partial = 'తెలు';
    view.titleInput.text = 'కల్పితమైన పేజీ';
    view.bodyInput.value = TextEditingValue(
      text: partial,
      selection: TextSelection.collapsed(offset: partial.length),
      composing: TextRange(start: 0, end: partial.length),
    );
    await tester.pump();
    expect(harness.controller.isComposing, isTrue);
    expect(harness.controller.indicator.phase, SavePhase.dirty);
    expect(harness.port.commits, 0);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('connected-body'))).readOnly, isTrue);

    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(find.text('Your changes are not safely saved'), findsOneWidget);
    expect(find.textContaining('Finish the current keyboard composition'),
      findsOneWidget);
    expect(closed, isFalse);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    const complete = 'తెలుగు కథ 🌿 ఒక ఊహించిన రోజు';
    view.bodyInput.value = TextEditingValue(
      text: complete,
      selection: TextSelection.collapsed(offset: complete.length),
    );
    await tester.pump();
    expect(harness.controller.isComposing, isFalse);
    expect(harness.port.commits, 0);
    await tester.ensureVisible(find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.stored?.body, complete);
    expect(find.text('Saved locally · version 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit save of partial Telugu composition never confirms '
      'complete page, but final composed text can be verified', (tester) async {
    var confirmations = 0;
    final harness = await mount(tester,
      onClose: () {},
      onAcknowledged: (_) async { confirmations++; },
    );
    final view = tester.state<ConnectedWritingStudioState>(
      find.byType(ConnectedWritingStudio));
    view.titleInput.text = 'ఊహించిన పేజీ';
    const partial = 'తె';
    view.bodyInput.value = TextEditingValue(
      text: partial,
      selection: TextSelection.collapsed(offset: partial.length),
      composing: TextRange(start: 0, end: partial.length),
    );
    await tester.pump();
    expect(harness.controller.isComposing, isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    // Acknowledged partial content may be kept for power-loss recovery, but
    // the user-level explicit Save-and-verify promise is not fulfilled yet.
    expect(harness.port.stored?.body, partial);
    expect(harness.port.storedVersion, 1);
    expect(confirmations, 0);
    expect(harness.controller.isComposing, isTrue);
    expect(find.textContaining('Unfinished keyboard composition'),
      findsOneWidget);
    expect(find.textContaining('Finish typing and save again'),
      findsOneWidget);
    expect(tester.takeException(), isNull);

    const complete = 'తెలుగు 🌿 కల్పిత జ్ఞాపకం';
    view.bodyInput.value = TextEditingValue(
      text: complete,
      selection: TextSelection.collapsed(offset: complete.length),
    );
    await tester.pump();
    expect(harness.controller.isComposing, isFalse);
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.stored?.body, complete);
    expect(harness.port.storedVersion, 2);
    expect(confirmations, 1);
    expect(find.textContaining('Unfinished keyboard composition'),
      findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed partial composition write cannot emit an explicit '
      'verification callback or false completion message', (tester) async {
    var confirmations = 0;
    final harness = await mount(tester,
      onClose: () {},
      onAcknowledged: (_) async { confirmations++; },
    );
    harness.port.fail = true;
    final view = tester.state<ConnectedWritingStudioState>(
      find.byType(ConnectedWritingStudio));
    view.titleInput.text = 'Fictional Telugu failed write';
    const partial = 'తె';
    view.bodyInput.value = TextEditingValue(
      text: partial,
      selection: TextSelection.collapsed(offset: partial.length),
      composing: TextRange(start: 0, end: partial.length),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.stored, isNull);
    expect(harness.controller.indicator.phase, SavePhase.error);
    expect(confirmations, 0);
    expect(find.textContaining('Unfinished keyboard composition'),
      findsOneWidget);
    expect(find.textContaining('the page is not verified'),
      findsOneWidget);
    expect(find.text('Saved locally · version 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated Android background transitions share one real ACK',
      (tester) async {
    final harness = await mount(tester, onClose: () {});
    final view = tester.state<ConnectedWritingStudioState>(
      find.byType(ConnectedWritingStudio));
    harness.port.gate = Completer<void>();
    view.titleInput.text = 'A fictional interrupted afternoon';
    view.bodyInput.text = 'ఒక ఊహించిన జ్ఞాపకం · imagined only';
    await tester.pump();
    expect(harness.controller.indicator.phase, SavePhase.dirty);

    view.didChangeAppLifecycleState(AppLifecycleState.inactive);
    view.didChangeAppLifecycleState(AppLifecycleState.hidden);
    view.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(harness.port.commits, 1);
    expect(harness.controller.indicator.phase, SavePhase.saving);
    expect(harness.controller.indicator.mayLeaveSafely, isFalse);
    expect(find.text('Saved locally · version 1'), findsNothing);

    harness.port.gate!.complete();
    await tester.pumpAndSettle();
    expect(harness.port.commits, 1);
    expect(harness.port.stored?.body, 'ఒక ఊహించిన జ్ఞాపకం · imagined only');
    expect(harness.controller.indicator.phase, SavePhase.saved);
    expect(find.text('Saved locally · version 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed background save never shows a false acknowledgement',
      (tester) async {
    var closed = false;
    final harness = await mount(tester, onClose: () => closed = true);
    final view = tester.state<ConnectedWritingStudioState>(
      find.byType(ConnectedWritingStudio));
    harness.port.fail = true;
    view.titleInput.text = 'Fictional draft during pause';
    view.bodyInput.text = 'అసంపూర్ణ ఊహించిన కథ';
    await tester.pump();
    view.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(harness.controller.indicator.phase, SavePhase.error);
    expect(harness.controller.indicator.mayLeaveSafely, isFalse);
    expect(find.textContaining('Save failed'), findsOneWidget);
    // The safety copy explains the words "Saved locally"; only the exact
    // acknowledged status label is authoritative.
    expect(find.text('Saved locally · version 1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('connected-back')));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Your changes are not safely saved'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    harness.port.fail = false;
    await tester.ensureVisible(find.byKey(const ValueKey('connected-save')));
    await tester.tap(find.byKey(const ValueKey('connected-save')));
    await tester.pumpAndSettle();
    expect(harness.port.stored?.body, 'అసంపూర్ణ ఊహించిన కథ');
    expect(harness.controller.indicator.phase, SavePhase.saved);
    expect(harness.port.storedVersion, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone and tablet layouts avoid overflow with status and buttons',
      (tester) async {
    for (final size in [const Size(360, 740), const Size(1024, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final harness = await mount(tester, onClose: () {});
      await tester.ensureVisible(find.byKey(
        const ValueKey('connected-save')));
      expect(find.byKey(const ValueKey('connected-save-status')), findsOneWidget);
      expect(tester.takeException(), isNull);
      harness.controller.abandonFictionalTestDraft();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('fictional conflict review shows saved versus unsaved and '
      'never mistakes a separate copy for an original save', (tester) async {
    var copies = 0;
    var originalSaveAcks = 0;
    final harness = await mount(tester,
      onClose: () {},
      onAcknowledged: (_) async { originalSaveAcks++; },
      loadNewestSavedConflict: () async => {
        'title': 'Newest verified original',
        'body': 'Original fictional revision remains here',
        'version': 2,
      },
      preserveConflictAsNew: () async {
        copies++;
        return const ConflictReviewCopyReceipt(
          entryId: 'independently-verified-fictional-copy',
          matchesCurrentDraft: true,
        );
      },
    );
    harness.port.conflict = true;
    await tester.ensureVisible(find.byKey(
        const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    expect(harness.controller.hasUnresolvedConflict, isTrue);
    await tester.ensureVisible(find.byKey(
        const ValueKey('connected-review-conflict')));
    await tester.tap(find.byKey(
        const ValueKey('connected-review-conflict')));
    await tester.pumpAndSettle();
    expect(find.text('Newest saved page · read only'), findsOneWidget);
    expect(find.text('Your unsaved draft · not backed up'), findsOneWidget);
    expect(find.text('Newest verified original'), findsOneWidget);
    expect(find.descendant(
      of: find.byType(FictionalConflictReviewSheet),
      matching: find.text(fixture.body),
    ), findsOneWidget);
    expect(copies, 0);
    await tester.ensureVisible(find.byKey(
        const ValueKey('conflict-preserve-new-page')));
    await tester.tap(find.byKey(
        const ValueKey('conflict-preserve-new-page')));
    await tester.pumpAndSettle();
    expect(copies, 1);
    expect(originalSaveAcks, 0);
    expect(harness.port.stored, isNull);
    expect(harness.controller.indicator.phase, SavePhase.conflict);
    expect(find.textContaining('The original page was not changed'),
        findsWidgets);
    expect(tester.widget<FilledButton>(find.byKey(
        const ValueKey('conflict-preserve-new-page'))).onPressed, isNull);
    await tester.ensureVisible(find.byKey(
        const ValueKey('conflict-keep-editing')));
    await tester.tap(find.byKey(const ValueKey('conflict-keep-editing')));
    await tester.pumpAndSettle();
    expect(harness.controller.hasUnresolvedConflict, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown copy acknowledgment never auto-retries after '
      'closing and reopening conflict review', (tester) async {
    var attempts = 0;
    final harness = await mount(tester,
      onClose: () {},
      loadNewestSavedConflict: () async => {
        'title': 'Verified different original',
        'body': 'Safe existing fictional page',
        'version': 3,
      },
      preserveConflictAsNew: () async {
        attempts++;
        throw StateError('Simulated lost storage acknowledgment');
      },
    );
    harness.port.conflict = true;
    await tester.ensureVisible(find.byKey(
        const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('connected-review-conflict')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(
        const ValueKey('conflict-preserve-new-page')));
    await tester.tap(find.byKey(
        const ValueKey('conflict-preserve-new-page')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('could not confirm'), findsWidgets);
    await tester.ensureVisible(find.byKey(
        const ValueKey('conflict-keep-editing')));
    await tester.tap(find.byKey(const ValueKey('conflict-keep-editing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('connected-review-conflict')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(
        const ValueKey('conflict-preserve-new-page'))).onPressed, isNull);
    expect(attempts, 1);
    expect(harness.controller.indicator.phase, SavePhase.conflict);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished Telugu composition disables conflict preservation',
      (tester) async {
    final harness = await mount(tester,
      onClose: () {},
      loadNewestSavedConflict: () async => {
        'title': 'Saved fictional Telugu',
        'body': 'కల్పితము',
        'version': 2,
      },
      preserveConflictAsNew: () async =>
          const ConflictReviewCopyReceipt(
            entryId: 'never-attempted',
            matchesCurrentDraft: true,
          ),
    );
    harness.port.conflict = true;
    await tester.ensureVisible(find.byKey(
        const ValueKey('insert-fictional-sample')));
    await tester.tap(find.byKey(const ValueKey('insert-fictional-sample')));
    await tester.pumpAndSettle();
    final view = tester.state<ConnectedWritingStudioState>(
        find.byType(ConnectedWritingStudio));
    const partial = 'తెలు';
    view.bodyInput.value = const TextEditingValue(
      text: partial,
      selection: TextSelection.collapsed(offset: 4),
      composing: TextRange(start: 0, end: 4),
    );
    await tester.pump();
    expect(harness.controller.isComposing, isTrue);
    await tester.tap(find.byKey(
        const ValueKey('connected-review-conflict')));
    await tester.pumpAndSettle();
    expect(find.text('Finish typing before saving a separate page.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(
        const ValueKey('conflict-preserve-new-page'))).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

}
