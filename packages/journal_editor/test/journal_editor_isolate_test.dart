// APK02 full-schema encrypted Dart isolate tests; fictional text only.
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:test/test.dart';

const originalTitle = 'Imagined train window';
const originalBody = 'Fictional light and memories. ఈ రోజు 🪷';
const revisedBody = 'Fictional revision two, with preserved history 🌿';

void main() {
  late Directory dir;
  late String dbPath;
  late TestVaultKey key;
  late JournalEditorWorker worker;
  setUp(() async {
    dir = Directory.systemTemp.createTempSync('nj-editor-worker-');
    dbPath = dir.path + Platform.pathSeparator + 'full-journal.db';
    key = TestVaultKey.random();
    worker = await JournalEditorWorker.open(dbPath, key: key, create: true);
  });

  tearDown(() async {
    await worker.close();
    key.destroy();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('worker writes full-journal entry; fresh isolate reopens exact page', () async {
    final journal = await worker.createJournal('Fictional Days');
    final session = await worker.startSession(
      journalId: journal,
      debounce: const Duration(days: 1),
    );
    expect(session.indicator.phase, SavePhase.pristine);
    expect(await session.persistedEntryId(), isNull);
    session.controller.update(title: originalTitle, body: originalBody);
    expect(session.indicator.accessibleLabel, 'Changes not yet saved');
    await session.save();
    expect(session.indicator.phase, SavePhase.saved);
    expect(session.indicator.databaseVersion, 1);
    expect(await worker.integrityCheck(), isTrue);
    final realId = (await session.persistedEntryId())!;
    expect(realId, isNotEmpty);
    expect((await worker.readEntry(realId))!['body'], originalBody);
    expect(await session.closeSafely(), isTrue);

    await worker.close();
    worker = await JournalEditorWorker.open(dbPath, key: key);
    expect((await worker.readEntry(realId))!['title'], originalTitle);
    final loaded = await worker.startSession(
      journalId: journal, existingEntryId: realId);
    expect(loaded.draft, const DraftContent(
      title: originalTitle, body: originalBody,
    ));
    expect(loaded.indicator.databaseVersion, 1);
    expect(loaded.indicator.mayLeaveSafely, isTrue);
    expect(await loaded.closeSafely(), isTrue);
  });

  test('editing loaded page creates one revision in encrypted worker', () async {
    final journal = await worker.createJournal('Pages');
    final first = await worker.startSession(
      journalId: journal, debounce: const Duration(days: 1));
    first.controller.update(title: originalTitle, body: originalBody);
    await first.save();
    final id = (await first.persistedEntryId())!;
    expect(await first.closeSafely(), isTrue);
    final second = await worker.startSession(
      journalId: journal, existingEntryId: id,
      debounce: const Duration(days: 1));
    second.controller.update(title: originalTitle, body: revisedBody);
    await second.save();
    expect(second.indicator.phase, SavePhase.saved);
    expect(second.indicator.databaseVersion, 2);
    expect(await worker.historyCount(id), 1);
    expect((await worker.readEntry(id))!['body'], revisedBody);
    await worker.close();
    worker = await JournalEditorWorker.open(dbPath, key: key);
    expect((await worker.readEntry(id))!['version'], 2);
    expect(await worker.historyCount(id), 1);
  });

  test('two simultaneous editor sessions reject a stale second edit', () async {
    final journal = await worker.createJournal('Entries');
    final created = await worker.startSession(
      journalId: journal, debounce: const Duration(days: 1));
    created.controller.update(title: originalTitle, body: originalBody);
    await created.save();
    final id = (await created.persistedEntryId())!;
    final a = await worker.startSession(
      journalId: journal, existingEntryId: id, debounce: const Duration(days: 1));
    final b = await worker.startSession(
      journalId: journal, existingEntryId: id, debounce: const Duration(days: 1));
    a.controller.update(title: 'First editor', body: 'Editor A fictional text');
    b.controller.update(title: 'Second editor', body: 'Editor B fictional text');
    await a.save();
    expect(a.indicator.phase, SavePhase.saved);
    await b.save();
    expect(b.indicator.phase, SavePhase.conflict);
    expect(b.indicator.mayLeaveSafely, isFalse);
    expect((await worker.readEntry(id))!['body'], 'Editor A fictional text');
    expect(await worker.historyCount(id), 1);
    expect(await b.closeSafely(), isFalse);
    b.controller.abandonFictionalTestDraft();
  });

  test('blank draft never creates a record', () async {
    final journal = await worker.createJournal('Pages');
    final editor = await worker.startSession(journalId: journal);
    await editor.save();
    expect(editor.indicator.phase, SavePhase.pristine);
    expect(await editor.persistedEntryId(), isNull);
    expect(await worker.listEntries(journalId: journal), isEmpty);
    expect(await editor.closeSafely(), isTrue);
  });

  test('on-demand close flushes delayed save before leaving', () async {
    final journal = await worker.createJournal('Pages');
    final editor = await worker.startSession(
      journalId: journal, debounce: const Duration(days: 1));
    editor.controller.update(title: 'Imagined', body: originalBody);
    expect(editor.indicator.hasUnsavedChanges, isTrue);
    expect(await editor.closeSafely(), isTrue);
    expect(editor.indicator.mayLeaveSafely, isTrue);
    final rows = await worker.listEntries();
    expect(rows.length, 1);
    expect(rows.single['body'], originalBody);
  });

  test('reopening with missing/wrong key does not create a new vault', () async {
    final journal = await worker.createJournal('Page');
    final draft = await worker.startSession(
      journalId: journal, debounce: const Duration(days: 1));
    draft.controller.update(title: originalTitle, body: originalBody);
    await draft.save();
    final saved = (await draft.persistedEntryId())!;
    await worker.close();
    final other = TestVaultKey.random();
    try {
      await expectLater(
        JournalEditorWorker.open(dbPath, key: other),
        throwsA(isA<JournalEditorWorkerUnavailable>()),
      );
    } finally {
      other.destroy();
    }
    worker = await JournalEditorWorker.open(dbPath, key: key);
    expect((await worker.readEntry(saved))!['body'], originalBody);
    expect((await worker.listEntries()).length, 1);
  });

  test('existing file cannot be replaced by accidental create request', () async {
    await expectLater(
      JournalEditorWorker.open(dbPath, key: key, create: true),
      throwsA(isA<JournalEditorWorkerUnavailable>()),
    );
    expect(await worker.integrityCheck(), isTrue);
  });

  test('worker failures use generic errors with no diary content', () async {
    final journal = await worker.createJournal('Fictional');
    final page = await worker.startSession(
      journalId: journal, debounce: const Duration(days: 1));
    page.controller.update(title: originalTitle, body: originalBody);
    await page.save();
    final id = (await page.persistedEntryId())!;
    await worker.close();
    await expectLater(
      worker.readEntry(id),
      throwsA(isA<JournalEditorWorkerUnavailable>()),
    );
    worker = await JournalEditorWorker.open(dbPath, key: key);
    expect((await worker.readEntry(id))!['body'], originalBody);
  });

  test('separate journals remain separated and persisted', () async {
    final a = await worker.createJournal('A');
    final b = await worker.createJournal('B');
    final x = await worker.startSession(
      journalId: a, debounce: const Duration(days: 1));
    final y = await worker.startSession(
      journalId: b, debounce: const Duration(days: 1));
    x.controller.update(title: 'First', body: 'Fictional A');
    y.controller.update(title: 'Second', body: 'Fictional B');
    await Future.wait([x.save(), y.save()]);
    expect((await worker.listEntries(journalId: a)).single['title'], 'First');
    expect((await worker.listEntries(journalId: b)).single['title'], 'Second');
    expect((await worker.listEntries()).length, 2);
    expect(await worker.integrityCheck(), isTrue);
  });
}
