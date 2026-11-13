import 'dart:io';

import 'package:navin_journal_storage_spike/journal_store.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory folder;
  late String databasePath;
  late JournalStore store;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('navin_spike_');
    databasePath = folder.path + Platform.pathSeparator + 'fictional.db';
    store = JournalStore.open(databasePath);
  });

  tearDown(() {
    store.close();
    folder.deleteSync(recursive: true);
  });

  test('fresh schema and SQLite integrity', () {
    expect(store.sqliteIntegrityCheck(), isTrue);
    expect(store.listJournals(), isEmpty);
  });

  test('journal names reject blank and duplicate active names', () {
    expect(() => store.createJournal('    '), throwsArgumentError);
    final journal = store.createJournal('Personal');
    expect(journal.name, 'Personal');
    expect(() => store.createJournal('personal'), throwsA(isA<Exception>()));
    expect(store.listJournals(), hasLength(1));
    expect(store.sqliteIntegrityCheck(), isTrue);
  });

  test('Telugu/English/emoji content and independent event date', () {
    final journal = store.createJournal('జ్ఞాపకాలు');
    final date = DateTime.utc(2014, 5, 2).millisecondsSinceEpoch;
    const body = 'ఈ రోజు మంచి రోజు. A beautiful day. 🌿 🪷 👨‍👩‍👧';
    final entry = store.createEntry(
      journalId: journal.id,
      title: 'నా జ్ఞాపకం — memory',
      body: body,
      eventAtMs: date,
    );
    expect(entry.title, 'నా జ్ఞాపకం — memory');
    expect(entry.body, body);
    expect(entry.eventAtMs, date);
    expect(entry.createdAtMs, greaterThan(date));
    expect(entry.version, 1);
    expect(store.listEntries(journalId: journal.id).single.id, entry.id);
  });

  test('close/reopen retains committed text, journal, version', () {
    final journal = store.createJournal('Personal');
    final entry = store.createEntry(
      journalId: journal.id,
      title: 'Cinematic ✨',
      body: 'నాకు గుర్తుంది — A small day worth keeping.',
    );
    store.close();
    final reopened = JournalStore.open(databasePath);
    try {
      expect(reopened.getJournal(journal.id)?.name, 'Personal');
      expect(reopened.getEntry(entry.id)?.body, entry.body);
      expect(reopened.getEntry(entry.id)?.version, 1);
      expect(reopened.sqliteIntegrityCheck(), isTrue);
    } finally {
      reopened.close();
    }
    store = JournalStore.open(databasePath);
  });

  test('empty untouched draft never becomes entry', () {
    final journal = store.createJournal('Personal');
    expect(
      () => store.createEntry(journalId: journal.id, body: ' \n ', title: ' '),
      throwsArgumentError,
    );
    expect(store.listEntries(), isEmpty);
  });

  test('transactional edit creates prior revision, retains event date', () {
    final j = store.createJournal('Personal');
    final event = DateTime.utc(2015, 2, 10).millisecondsSinceEpoch;
    final entry = store.createEntry(
      journalId: j.id, title: 'A', body: 'before', eventAtMs: event,
    );
    final updated = store.editEntry(
      id: entry.id, expectedVersion: entry.version, journalId: j.id,
      title: 'B', body: 'after', eventAtMs: event,
    );
    expect(updated.version, 2);
    expect(updated.body, 'after');
    expect(updated.id, entry.id);
    final previous = store.listRevisions(entry.id);
    expect(previous, hasLength(1));
    expect(previous.single.version, 1);
    expect(previous.single.body, 'before');
    expect(previous.single.eventAtMs, event);
    expect(store.sqliteIntegrityCheck(), isTrue);
  });

  test('unchanged edit does not manufacture revision', () {
    final j = store.createJournal('Personal');
    final entry = store.createEntry(journalId: j.id, body: 'unchanged');
    final same = store.editEntry(
      id: entry.id, expectedVersion: 1, journalId: j.id,
      title: '', body: 'unchanged', eventAtMs: null,
    );
    expect(same.version, 1);
    expect(store.listRevisions(entry.id), isEmpty);
  });

  test('stale version rejected without overwriting content', () {
    final j = store.createJournal('Personal');
    final e = store.createEntry(journalId: j.id, body: 'first');
    store.editEntry(
      id: e.id, expectedVersion: 1, journalId: j.id,
      title: '', body: 'second', eventAtMs: null,
    );
    expect(
      () => store.editEntry(
        id: e.id, expectedVersion: 1, journalId: j.id,
        title: '', body: 'stale', eventAtMs: null,
      ),
      throwsA(isA<ConflictException>()),
    );
    expect(store.getEntry(e.id)?.body, 'second');
    expect(store.listRevisions(e.id), hasLength(1));
  });

  test('two independent SQLite connections detect stale version', () {
    final j = store.createJournal('Personal');
    final e = store.createEntry(journalId: j.id, body: 'first');
    final another = JournalStore.open(databasePath);
    try {
      final stale = another.getEntry(e.id)!;
      store.editEntry(
        id: e.id, expectedVersion: 1, journalId: j.id,
        title: '', body: 'written by connection one', eventAtMs: null,
      );
      expect(
        () => another.editEntry(
          id: e.id, expectedVersion: stale.version, journalId: j.id,
          title: '', body: 'overwriting conflict', eventAtMs: null,
        ),
        throwsA(isA<ConflictException>()),
      );
      expect(another.getEntry(e.id)?.body, 'written by connection one');
    } finally {
      another.close();
    }
  });

  test('injected mid-transaction failure rolls back entry and revision', () {
    final j = store.createJournal('Personal');
    final e = store.createEntry(journalId: j.id, body: 'safe baseline');
    final broken = JournalStore.open(
      databasePath,
      failureHook: (point) {
        if (point == 'after_revision_before_update') {
          throw StateError('simulated interrupted write');
        }
      },
    );
    try {
      expect(
        () => broken.editEntry(
          id: e.id, expectedVersion: 1, journalId: j.id,
          title: '', body: 'incomplete change', eventAtMs: null,
        ),
        throwsStateError,
      );
      expect(store.getEntry(e.id)?.body, 'safe baseline');
      expect(store.getEntry(e.id)?.version, 1);
      expect(store.listRevisions(e.id), isEmpty);
      expect(store.sqliteIntegrityCheck(), isTrue);
    } finally {
      broken.close();
    }
  });

  test('journal move keeps ID and prior journal revision', () {
    final one = store.createJournal('Personal');
    final two = store.createJournal('Travel');
    final e = store.createEntry(journalId: one.id, body: 'Before');
    final moved = store.editEntry(
      id: e.id, expectedVersion: 1, journalId: two.id,
      title: '', body: 'Before', eventAtMs: null,
    );
    expect(moved.id, e.id);
    expect(moved.journalId, two.id);
    expect(store.listEntries(journalId: one.id), isEmpty);
    expect(store.listEntries(journalId: two.id), hasLength(1));
    expect(store.listRevisions(e.id).single.journalId, one.id);
  });

  test('Trash and restore retain content, ID and revision history', () {
    final j = store.createJournal('Personal');
    final e = store.createEntry(journalId: j.id, body: 'Please keep me');
    store.trashEntry(e.id, expectedVersion: 1);
    expect(store.listEntries(), isEmpty);
    expect(store.getEntry(e.id)?.deletedAtMs, isNotNull);
    expect(
      () => store.trashEntry(e.id, expectedVersion: 1),
      throwsA(isA<StateError>()),
    );
    store.restoreEntry(e.id);
    final restored = store.getEntry(e.id)!;
    expect(restored.id, e.id);
    expect(restored.body, 'Please keep me');
    expect(restored.deletedAtMs, isNull);
    expect(restored.version, 3);
    expect(store.listRevisions(e.id), hasLength(2));
  });

  test('journal Trash/restore hides child entries but preserves individual Trash', () {
    final j = store.createJournal('Travel');
    final a = store.createEntry(journalId: j.id, body: 'Visible');
    final b = store.createEntry(journalId: j.id, body: 'Individually trashed');
    store.trashEntry(b.id, expectedVersion: 1);
    store.trashJournal(j.id);
    expect(store.listJournals(), isEmpty);
    expect(store.listEntries(), isEmpty);
    store.restoreJournal(j.id);
    expect(store.listJournals(), hasLength(1));
    expect(store.listEntries(journalId: j.id).single.id, a.id);
    expect(store.getEntry(b.id)?.deletedAtMs, isNotNull);
  });

  test('orphan restore needs explicit destination; no silent reassignment', () {
    final source = store.createJournal('Travel');
    final target = store.createJournal('Reflections');
    final e = store.createEntry(journalId: source.id, body: 'Memory');
    store.trashEntry(e.id, expectedVersion: 1);
    store.trashJournal(source.id);
    expect(() => store.restoreEntry(e.id), throwsStateError);
    expect(store.getEntry(e.id)?.deletedAtMs, isNotNull);
    store.restoreEntry(e.id, destinationJournalId: target.id);
    expect(store.getEntry(e.id)?.journalId, target.id);
    expect(store.getEntry(e.id)?.body, 'Memory');
  });

  test('archive is not Trash and blocks new writing until unarchived', () {
    final j = store.createJournal('Ideas');
    store.archiveJournal(j.id, archived: true);
    expect(store.listJournals(), isEmpty);
    expect(store.listJournals(includeArchived: true), hasLength(1));
    expect(() => store.createEntry(journalId: j.id, body: 'not now'), throwsStateError);
    store.archiveJournal(j.id, archived: false);
    expect(store.createEntry(journalId: j.id, body: 'now').body, 'now');
  });

  test('long mixed Unicode entry is lossless after reopen', () {
    final j = store.createJournal('Personal');
    final body = List.filled(2500, 'తెలుగు + English 🌌\n').join();
    final e = store.createEntry(journalId: j.id, body: body);
    store.close();
    final reopened = JournalStore.open(databasePath);
    try {
      expect(reopened.getEntry(e.id)?.body, body);
      expect(reopened.sqliteIntegrityCheck(), isTrue);
    } finally {
      reopened.close();
    }
    store = JournalStore.open(databasePath);
  });

  test('newer schema rejected without resetting saved data', () {
    final journal = store.createJournal('Personal');
    store.close();
    final raw = sqlite3.open(databasePath);
    raw.userVersion = 99;
    raw.dispose();
    expect(() => JournalStore.open(databasePath), throwsStateError);
    final reset = sqlite3.open(databasePath);
    reset.userVersion = 1;
    reset.dispose();
    store = JournalStore.open(databasePath);
    expect(store.getJournal(journal.id)?.name, 'Personal');
  });

  test('parameter binding treats SQL-like text as harmless data', () {
    final j = store.createJournal("Memories'); DROP TABLE entries;--");
    final e = store.createEntry(
      journalId: j.id, body: "'); DELETE FROM journals; --",
    );
    expect(store.getEntry(e.id)?.body, "'); DELETE FROM journals; --");
    expect(store.sqliteIntegrityCheck(), isTrue);
  });
}
