import 'dart:async';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:test/test.dart';

class FakeRecord {
  DraftContent content;
  int version;
  FakeRecord(this.content, this.version);
}

class MemoryCommitPort implements DraftCommitPort {
  final Map<String, FakeRecord> records = {};
  int calls = 0;
  int failuresRemaining = 0;
  bool forceConflict = false;
  Completer<void>? gate;

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('Simulated offline write failure with no private data');
    }
    if (forceConflict) throw const DraftConflict();
    final current = records[entryId];
    if ((current?.version ?? 0) != expectedVersion) {
      throw const DraftConflict();
    }
    final updated = expectedVersion + 1;
    records[entryId] = FakeRecord(content, updated);
    return CommitReceipt(entryId, updated);
  }
}

class BrokenReceiptPort implements DraftCommitPort {
  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    return CommitReceipt('some-other-entry', expectedVersion);
  }
}

const _pause = Duration(milliseconds: 80);

void main() {
  late MemoryCommitPort port;
  late DraftAutosaveController controller;
  final indicators = <SaveIndicator>[];

  DraftAutosaveController make({
    DraftCommitPort? store,
    DraftContent initial = DraftContent.blank,
    int version = 0,
    Duration debounce = const Duration(milliseconds: 25),
  }) {
    return DraftAutosaveController(
      entryId: 'fictional-e1',
      storage: store ?? port,
      debounce: debounce,
      initial: initial,
      committedVersion: version,
      onIndicator: indicators.add,
    );
  }

  setUp(() {
    port = MemoryCommitPort();
    indicators.clear();
    controller = make();
  });

  tearDown(() => controller.abandonFictionalTestDraft());

  test('fresh untouched draft is pristine and never writes', () async {
    expect(controller.indicator.phase, SavePhase.pristine);
    expect(controller.indicator.mayLeaveSafely, isTrue);
    await controller.flush();
    expect(port.calls, 0);
    expect(await controller.closeSafely(), isTrue);
  });

  test('rapid edits coalesce into one acknowledged database commit', () async {
    controller.update(title: 'First', body: '');
    controller.update(title: 'Latest', body: 'Latest body');
    await Future<void>.delayed(_pause);
    expect(port.calls, 1);
    expect(port.records['fictional-e1']?.content.title, 'Latest');
    expect(controller.indicator.phase, SavePhase.saved);
    expect(controller.indicator.databaseVersion, 1);
  });

  test('draft exposes dirty before successful commit and saved afterward',
      () async {
    controller.update(title: '', body: 'Fictional note');
    expect(controller.indicator.phase, SavePhase.dirty);
    expect(controller.indicator.hasUnsavedChanges, isTrue);
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.saved);
    expect(controller.indicator.hasUnsavedChanges, isFalse);
  });

  test('actual multilingual string survives in test storage unchanged', () async {
    const sample = 'ఈ రోజు 🌿 Today is peaceful. 👨‍👩‍👧';
    controller.update(title: 'జ్ఞాపకం', body: sample);
    await controller.flush();
    expect(port.records['fictional-e1']?.content.body, sample);
    expect(port.records['fictional-e1']?.content.title, 'జ్ఞాపకం');
  });

  test('pending write can never mark latest unsaved draft as saved', () async {
    port.gate = Completer<void>();
    controller.update(title: '', body: 'Previous revision');
    final pending = controller.flush();
    expect(controller.indicator.phase, SavePhase.saving);
    expect(controller.indicator.mayLeaveSafely, isFalse);
    controller.update(title: '', body: 'Newer revision');
    expect(controller.indicator.phase, SavePhase.dirty);
    expect(controller.indicator.hasUnsavedChanges, isTrue);
    port.gate!.complete();
    await pending;
    expect(port.records['fictional-e1']?.content.body, 'Newer revision');
    expect(port.calls, 2);
    expect(controller.indicator.phase, SavePhase.saved);
    expect(controller.indicator.databaseVersion, 2);
  });

  test('two flush requests share the same in-flight write', () async {
    port.gate = Completer<void>();
    controller.update(title: '', body: 'Only once');
    final first = controller.flush();
    final second = controller.flush();
    expect(port.calls, 1);
    port.gate!.complete();
    await Future.wait([first, second]);
    expect(port.calls, 1);
    expect(controller.indicator.databaseVersion, 1);
  });

  test('storage failure leaves draft untouched and visible error state',
      () async {
    port.failuresRemaining = 1;
    controller.update(title: '', body: 'Never silently discard');
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.error);
    expect(controller.indicator.hasUnsavedChanges, isTrue);
    expect(controller.indicator.mayLeaveSafely, isFalse);
    expect(controller.draft.body, 'Never silently discard');
    expect(port.records, isEmpty);
  });

  test('manual retry after failure commits same draft without loss',
      () async {
    port.failuresRemaining = 1;
    controller.update(title: 'Test', body: 'Retry me');
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.error);
    await controller.retry();
    expect(controller.indicator.phase, SavePhase.saved);
    expect(port.records['fictional-e1']?.content.body, 'Retry me');
    expect(port.calls, 2);
  });

  test('close request refuses to lose unsaved data on save failure',
      () async {
    port.failuresRemaining = 1;
    controller.update(title: '', body: 'Keep this');
    expect(await controller.closeSafely(), isFalse);
    expect(controller.draft.body, 'Keep this');
    await controller.retry();
    expect(await controller.closeSafely(), isTrue);
  });

  test('stale external version becomes a conflict, not a blind overwrite',
      () async {
    port.forceConflict = true;
    controller.update(title: '', body: 'Potential conflict');
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.conflict);
    expect(controller.indicator.mayLeaveSafely, isFalse);
    expect(() => controller.retry(), throwsA(isA<DraftConflict>()));
    expect(port.records, isEmpty);
  });

  test('composition defers debounce until IME composition ends', () async {
    controller.startComposition();
    controller.update(title: '', body: 'తె');
    await Future<void>.delayed(_pause);
    expect(port.calls, 0);
    expect(controller.indicator.phase, SavePhase.dirty);
    controller.update(title: '', body: 'తెలుగు');
    controller.endComposition();
    await Future<void>.delayed(_pause);
    expect(port.records['fictional-e1']?.content.body, 'తెలుగు');
    expect(controller.indicator.phase, SavePhase.saved);
  });

  test('explicit lifecycle flush works while IME composition is open',
      () async {
    controller.startComposition();
    controller.update(title: '', body: 'Partial fictional composition');
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.saved);
    expect(port.records['fictional-e1']?.content.body,
        'Partial fictional composition');
  });

  test('blank new draft does not create empty persistent records', () async {
    controller.update(title: ' ', body: '\n ');
    await controller.flush();
    expect(port.records, isEmpty);
    expect(controller.indicator.phase, SavePhase.pristine);
    expect(controller.indicator.mayLeaveSafely, isTrue);
  });

  test('existing saved entry can be intentionally cleared and committed',
      () async {
    controller.abandonFictionalTestDraft();
    final existing = const DraftContent(title: 'Old', body: 'Old body');
    port.records['fictional-e1'] = FakeRecord(existing, 7);
    controller = make(initial: existing, version: 7);
    controller.update(title: '', body: '');
    await controller.flush();
    expect(controller.indicator.databaseVersion, 8);
    expect(port.records['fictional-e1']?.content.isBlank, isTrue);
    expect(controller.indicator.phase, SavePhase.saved);
  });

  test('lifecycle close flushes immediately before debounce expiry',
      () async {
    controller = make(debounce: const Duration(minutes: 3));
    controller.update(title: '', body: 'Paused app snapshot');
    expect(port.calls, 0);
    expect(await controller.closeSafely(), isTrue);
    expect(port.records['fictional-e1']?.content.body, 'Paused app snapshot');
    expect(port.calls, 1);
  });

  test('unchanged input never creates artificial database revisions',
      () async {
    controller.update(title: '', body: 'One');
    await controller.flush();
    controller.update(title: '', body: 'One');
    await controller.flush();
    expect(port.calls, 1);
    expect(controller.indicator.databaseVersion, 1);
  });

  test('returning to saved snapshot before debounce cancels pending save',
      () async {
    controller.update(title: '', body: 'Saved');
    await controller.flush();
    controller.update(title: '', body: 'Temporary');
    controller.update(title: '', body: 'Saved');
    await Future<void>.delayed(_pause);
    expect(port.calls, 1);
    expect(controller.indicator.phase, SavePhase.saved);
    expect(controller.indicator.mayLeaveSafely, isTrue);
  });

  test('invalid storage receipt never produces saved status', () async {
    controller.abandonFictionalTestDraft();
    controller = make(store: BrokenReceiptPort());
    controller.update(title: '', body: 'Invalid ack');
    await controller.flush();
    expect(controller.indicator.phase, SavePhase.error);
    expect(controller.indicator.mayLeaveSafely, isFalse);
  });

  test('abandoning test draft cancels debounce without writing', () async {
    controller.update(title: '', body: 'Fictional pending');
    controller.abandonFictionalTestDraft();
    await Future<void>.delayed(_pause);
    expect(port.calls, 0);
    expect(() => controller.update(title: '', body: 'Later'), throwsStateError);
  });

  test('save indicator never exposes title or body in accessible text',
      () async {
    const fictionalSecret = 'FICTIONAL_SENTINEL_NEVER_LOG_THIS';
    controller.update(title: fictionalSecret, body: fictionalSecret);
    await controller.flush();
    for (final state in indicators) {
      expect(state.accessibleLabel, isNot(contains(fictionalSecret)));
    }
  });

  test('controllers refuse invalid IDs and initial new entry state', () {
    expect(
      () => DraftAutosaveController(entryId: ' ', storage: port),
      throwsArgumentError,
    );
    expect(
      () => DraftAutosaveController(
        entryId: 'fictional',
        storage: port,
        initial: const DraftContent(title: 'not persisted', body: ''),
      ),
      throwsArgumentError,
    );
    expect(
      () => DraftAutosaveController(
        entryId: 'fictional',
        storage: port,
        committedVersion: -1,
      ),
      throwsArgumentError,
    );
  });
}
