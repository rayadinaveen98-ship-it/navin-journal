// APK02 editor integration: scripted fictional records only.
import 'dart:async';
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_editor/journal_core_draft_port.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:test/test.dart';

const first = DraftContent(
  title: 'The quiet hour',
  body: 'A fictional memory. ఈ రోజు ప్రశాంతంగా ఉంది 🪷',
);
const changed = DraftContent(
  title: 'A little more light',
  body: 'Fictional second version with Telugu తెలుగు.',
);

void main() {
  late Directory temp;
  late String dbPath;
  late TestVaultKey key;
  late JournalVault vault;
  late String journalId;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nj-edit-');
    dbPath = temp.path + Platform.pathSeparator + 'journal.sqlite3';
    key = TestVaultKey.random();
    vault = JournalVault.open(dbPath, key: key, create: true);
    journalId = vault.createJournal('Fictional Journal');
  });

  tearDown(() {
    vault.close();
    key.destroy();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  JournalCoreDraftPort port({String? existing, void Function(int)? failAck}) =>
      JournalCoreDraftPort(
        vault: vault,
        journalId: journalId,
        sessionId: newEditorSessionId(),
        existingEntryId: existing,
        afterCommitBeforeAck: failAck,
      );

  test('save first fictional entry and reopen same encrypted vault', () async {
    final p = port();
    final editor = JournalEditorSession.open(
      port: p, debounce: const Duration(days: 1));
    expect(editor.indicator.phase, SavePhase.pristine);
    expect(editor.persistedEntryId, isNull);
    editor.controller.update(title: first.title, body: first.body);
    expect(editor.indicator.hasUnsavedChanges, isTrue);
    expect(editor.indicator.accessibleLabel, 'Changes not yet saved');
    await editor.save();
    expect(editor.indicator.phase, SavePhase.saved);
    expect(editor.indicator.mayLeaveSafely, isTrue);
    final persisted = editor.persistedEntryId!;
    expect(vault.readEntry(persisted)!['body'], first.body);
    expect(vault.listEntries().length, 1);
    expect(await editor.closeSafely(), isTrue);
    vault.close();
    vault = JournalVault.open(dbPath, key: key);
    expect(vault.readEntry(persisted)!['title'], first.title);
    final loaded = JournalEditorSession.open(port: port(existing: persisted));
    expect(loaded.draft, first);
    expect(loaded.indicator.phase, SavePhase.saved);
    expect(loaded.indicator.databaseVersion, 1);
    expect(await loaded.closeSafely(), isTrue);
  });

  test('editing loaded entry commits one historical revision', () async {
    final id = vault.createEntry(
      journalId: journalId, title: first.title, body: first.body);
    final page = JournalEditorSession.open(port: port(existing: id));
    page.controller.update(title: changed.title, body: changed.body);
    await page.save();
    expect(page.indicator.databaseVersion, 2);
    expect(vault.readEntry(id)!['body'], changed.body);
    expect(vault.listRevisions(id).single['body'], first.body);
    expect(await page.closeSafely(), isTrue);
  });

  test('lost first-creation ACK can retry without duplicate entry', () async {
    var firstAck = true;
    final p = port(failAck: (version) {
      if (version == 1 && firstAck) {
        firstAck = false;
        throw StateError('Simulated lost transport ACK');
      }
    });
    final page = JournalEditorSession.open(
      port: p, debounce: const Duration(days: 1));
    page.controller.update(title: first.title, body: first.body);
    await page.save();
    expect(page.indicator.phase, SavePhase.error);
    expect(page.indicator.mayLeaveSafely, isFalse);
    expect(vault.listEntries().length, 1);
    final id = p.persistedEntryId!;
    await page.controller.retry();
    expect(page.indicator.phase, SavePhase.saved);
    expect(page.indicator.databaseVersion, 1);
    expect(p.persistedEntryId, id);
    expect(vault.listEntries().length, 1);
    expect(vault.listRevisions(id), isEmpty);
  });

  test('lost edit ACK is idempotent without duplicate revision', () async {
    final id = vault.createEntry(journalId: journalId,
      title: first.title, body: first.body);
    var lost = true;
    final p = port(existing: id, failAck: (version) {
      if (version == 2 && lost) {
        lost = false;
        throw StateError('Ack never reached UI');
      }
    });
    final page = JournalEditorSession.open(port: p,
      debounce: const Duration(days: 1));
    page.controller.update(title: changed.title, body: changed.body);
    await page.save();
    expect(page.indicator.phase, SavePhase.error);
    expect(vault.entryVersion(id), 2);
    expect(vault.listRevisions(id).length, 1);
    await page.controller.retry();
    expect(page.indicator.phase, SavePhase.saved);
    expect(page.indicator.databaseVersion, 2);
    expect(vault.entryVersion(id), 2);
    expect(vault.listRevisions(id).length, 1);
  });

  test('external edit is a conflict, never a silent last-write-wins', () async {
    final id = vault.createEntry(journalId: journalId,
      title: first.title, body: first.body);
    final page = JournalEditorSession.open(port: port(existing: id),
      debounce: const Duration(days: 1));
    page.controller.update(title: changed.title, body: changed.body);
    vault.editEntry(id: id, expectedVersion: 1, journalId: journalId,
      title: 'External', body: 'Other version', eventAtMs: null);
    await page.save();
    expect(page.indicator.phase, SavePhase.conflict);
    expect(page.indicator.mayLeaveSafely, isFalse);
    expect(() => page.controller.retry(), throwsA(isA<DraftConflict>()));
    expect(await page.closeSafely(), isFalse);
    expect(vault.readEntry(id)!['body'], 'Other version');
    expect(vault.listRevisions(id).length, 1);
    page.controller.abandonFictionalTestDraft();
  });

  test('nothing is persisted for untouched blank editor', () async {
    final page = JournalEditorSession.open(port: port());
    await page.save();
    expect(page.indicator.phase, SavePhase.pristine);
    expect(page.indicator.mayLeaveSafely, isTrue);
    expect(vault.listEntries(), isEmpty);
    expect(await page.closeSafely(), isTrue);
  });

  test('fully erased existing page fails closed and cannot be left as saved', () async {
    final id = vault.createEntry(journalId: journalId,
      title: first.title, body: first.body);
    final page = JournalEditorSession.open(port: port(existing: id),
      debounce: const Duration(days: 1));
    page.controller.update(title: '', body: '');
    await page.save();
    expect(page.indicator.phase, SavePhase.error);
    expect(page.indicator.mayLeaveSafely, isFalse);
    expect(await page.closeSafely(), isFalse);
    expect(vault.readEntry(id)!['body'], first.body);
    page.controller.abandonFictionalTestDraft();
  });

  test('IME composition defers autosave until composition ends', () async {
    final page = JournalEditorSession.open(
      port: port(), debounce: const Duration(milliseconds: 15));
    page.controller.startComposition();
    page.controller.update(title: first.title, body: first.body);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(vault.listEntries(), isEmpty);
    expect(page.indicator.phase, SavePhase.dirty);
    page.controller.endComposition();
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(page.indicator.phase, SavePhase.saved);
    expect(vault.listEntries().single['body'], first.body);
    expect(await page.closeSafely(), isTrue);
  });

  test('explicit close flushes pending changes before allowing navigation', () async {
    final page = JournalEditorSession.open(port: port(),
      debounce: const Duration(days: 1));
    page.controller.update(title: first.title, body: first.body);
    expect(page.indicator.hasUnsavedChanges, isTrue);
    expect(await page.closeSafely(), isTrue);
    expect(page.indicator.mayLeaveSafely, isTrue);
    expect(vault.listEntries().single['body'], first.body);
  });

  test('archived or unavailable destination fails save without false ACK', () async {
    final page = JournalEditorSession.open(port: port(),
      debounce: const Duration(days: 1));
    page.controller.update(title: first.title, body: first.body);
    vault.archiveJournal(journalId, archived: true);
    await page.save();
    expect(page.indicator.phase, SavePhase.error);
    expect(page.indicator.mayLeaveSafely, isFalse);
    expect(vault.listEntries(), isEmpty);
    vault.archiveJournal(journalId, archived: false);
    await page.controller.retry();
    expect(page.indicator.phase, SavePhase.saved);
    expect(vault.listEntries().length, 1);
  });

  test('existing entry event date survives an unrelated text edit', () async {
    const eventAtMs = 1700000000000;
    final id = vault.createEntry(journalId: journalId,
      title: first.title, body: first.body, eventAtMs: eventAtMs);
    final page = JournalEditorSession.open(port: port(existing: id),
      debounce: const Duration(days: 1));
    page.controller.update(title: changed.title, body: changed.body);
    await page.save();
    expect(page.indicator.phase, SavePhase.saved);
    expect(vault.readEntry(id)!['eventAtMs'], eventAtMs);
  });

  test('new sessions use independent opaque IDs', () {
    final ids = {for (var i = 0; i < 20; i++) newEditorSessionId()};
    expect(ids.length, 20);
    expect(ids.every((id) => RegExp(r'^edit-[0-9a-f]{32}$').hasMatch(id)),
      isTrue);
  });

  test('changes arriving during prior ACK cannot be mislabeled saved', () async {
    final p = port();
    final gate = Completer<void>();
    final delayed = _DelayedFirstAck(p, gate.future);
    final changes = <SavePhase>[];
    final controller = DraftAutosaveController(
      entryId: p.sessionId, storage: delayed,
      debounce: const Duration(days: 1),
      onIndicator: (indicator) => changes.add(indicator.phase));
    controller.update(title: first.title, body: first.body);
    final flush = controller.flush();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(vault.listEntries().length, 1);
    controller.update(title: changed.title, body: changed.body);
    expect(controller.indicator.phase, SavePhase.dirty);
    expect(controller.indicator.hasUnsavedChanges, isTrue);
    gate.complete();
    await flush;
    expect(controller.indicator.phase, SavePhase.saved);
    expect(controller.indicator.databaseVersion, 2);
    final id = p.persistedEntryId!;
    expect(vault.readEntry(id)!['body'], changed.body);
    expect(vault.listRevisions(id).length, 1);
    expect(changes, contains(SavePhase.dirty));
    expect(await controller.closeSafely(), isTrue);
  });
}

class _DelayedFirstAck implements DraftCommitPort {
  final JournalCoreDraftPort delegate;
  final Future<void> gate;
  bool _first = true;
  _DelayedFirstAck(this.delegate, this.gate);

  @override
  Future<CommitReceipt> commit({
    required String entryId,
    required int expectedVersion,
    required DraftContent content,
  }) async {
    final receipt = await delegate.commit(
      entryId: entryId,
      expectedVersion: expectedVersion,
      content: content);
    if (_first) {
      _first = false;
      await gate;
    }
    return receipt;
  }
}
