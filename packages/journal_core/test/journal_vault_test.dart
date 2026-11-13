// Journal Core integration regression tests. FICTIONAL FIXTURES ONLY.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String dbPath;
  late TestVaultKey dbKey;
  late JournalVault vault;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nj-core-fixtures-');
    dbPath = temp.path + Platform.pathSeparator + 'journal.sqlite3';
    dbKey = TestVaultKey.random();
    vault = JournalVault.open(dbPath, key: dbKey, create: true);
  });
  tearDown(() {
    vault.close();
    dbKey.destroy();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('encrypted create/write/close/reopen keeps Telugu and English text', () {
    final journal = vault.createJournal('My Journal');
    final id = vault.createEntry(
      journalId: journal,
      title: 'నా రోజు ✨',
      body: 'Today was quiet. ఈ రోజు చాలా ప్రశాంతంగా ఉంది.',
    );
    expect(vault.readEntry(id)!['version'], 1);
    expect(vault.integrityCheck(), isTrue);
    vault.close();
    final bytes = File(dbPath).readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('Today was quiet'), isFalse);
    expect(String.fromCharCodes(bytes).contains('My Journal'), isFalse);
    expect(String.fromCharCodes(bytes).contains('SQLite format 3'), isFalse);
    vault = JournalVault.open(dbPath, key: dbKey);
    expect(vault.readEntry(id)!['title'], 'నా రోజు ✨');
    expect(vault.readEntry(id)!['body'], contains('ఈ రోజు'));
    expect(vault.integrityCheck(), isTrue);
  });

  test('revisions preserve previous content and no-op edits stay version 1', () {
    final journal = vault.createJournal('Seasons');
    final id = vault.createEntry(journalId: journal,
      title: 'Original', body: 'First fictional line');
    expect(vault.editEntry(id: id, expectedVersion: 1, journalId: journal,
      title: 'Original', body: 'First fictional line', eventAtMs: null), 1);
    expect(vault.listRevisions(id), isEmpty);
    expect(vault.editEntry(id: id, expectedVersion: 1, journalId: journal,
      title: 'Revised', body: 'Second fictional line', eventAtMs: 1700000000000), 2);
    expect(vault.entryVersion(id), 2);
    final history = vault.listRevisions(id);
    expect(history.length, 1);
    expect(history.single['title'], 'Original');
    expect(history.single['body'], 'First fictional line');
    expect(history.single['journalId'], journal);
    expect(vault.readEntry(id)!['eventAtMs'], 1700000000000);
  });

  test('stale optimistic edits are rejected without altering last good value', () {
    final journal = vault.createJournal('Test');
    final id = vault.createEntry(journalId: journal,
      title: 'A', body: 'Before');
    vault.editEntry(id: id, expectedVersion: 1, journalId: journal,
      title: 'B', body: 'After', eventAtMs: null);
    expect(
      () => vault.editEntry(id: id, expectedVersion: 1, journalId: journal,
        title: 'C', body: 'Stale', eventAtMs: null),
      throwsA(isA<JournalConflict>()),
    );
    expect(vault.readEntry(id)!['body'], 'After');
    expect(vault.listRevisions(id).length, 1);
  });

  test('injected fault after revision rolls back both SQL changes', () {
    vault.close();
    vault = JournalVault.open(dbPath, key: dbKey, injectFailure: (at) {
      if (at == 'after_revision_before_update') {
        throw StateError('Simulated transaction interruption');
      }
    });
    final journal = vault.createJournal('Test');
    final id = vault.createEntry(journalId: journal,
      title: 'Before', body: 'Safe value');
    expect(
      () => vault.editEntry(id: id, expectedVersion: 1, journalId: journal,
        title: 'Changed', body: 'Should rollback', eventAtMs: null),
      throwsStateError,
    );
    expect(vault.readEntry(id)!['body'], 'Safe value');
    expect(vault.entryVersion(id), 1);
    expect(vault.listRevisions(id), isEmpty);
    expect(vault.integrityCheck(), isTrue);
  });

  test('move journal, Trash and restore keep continuous revision history', () async {
    final a = vault.createJournal('A');
    final b = vault.createJournal('B');
    final id = vault.createEntry(journalId: a,
      title: 'Past', body: 'A first sample');
    final edited = vault.editEntry(id: id, expectedVersion: 1,
      journalId: b, title: 'Moved', body: 'A second sample', eventAtMs: null);
    expect(edited, 2);
    final trashed = vault.trashEntry(id, expectedVersion: edited);
    expect(trashed, 3);
    expect(vault.listEntries(), isEmpty);
    expect(vault.listEntries(includeTrash: true).length, 1);
    vault.archiveJournal(b, archived: true);
    expect(() => vault.restoreEntry(id), throwsA(isA<JournalUnavailable>()));
    final restored = vault.restoreEntry(id, destinationJournalId: a);
    expect(restored, 4);
    final snapshot = vault.snapshot();
    await ProductSnapshotCodec().validate(snapshot);
    final row = vault.readEntry(id)!;
    expect(row['journalId'], a);
    expect(row['deletedAtMs'], isNull);
    expect(vault.listRevisions(id).map((x) => x['version']), [1, 2, 3]);
    expect(vault.integrityCheck(), isTrue);
  });

  test('archive and Trash journal state preserved in whole snapshot', () async {
    final journal = vault.createJournal('History');
    vault.archiveJournal(journal, archived: true);
    expect(() => vault.createEntry(journalId: journal, title: 'X',
      body: 'Cannot write to archived'), throwsA(isA<JournalUnavailable>()));
    vault.trashJournal(journal);
    final state = vault.snapshot();
    await ProductSnapshotCodec().validate(state);
    expect((state['journals'] as List).single['archived'], isTrue);
    expect((state['journals'] as List).single['deletedAtMs'], isNotNull);
    vault.restoreJournal(journal);
    vault.archiveJournal(journal, archived: false);
    expect(vault.createEntry(journalId: journal,
      title: 'Now', body: 'Writable again'), isNotEmpty);
  });

  test('media is linked and encrypted with authenticated backup', () async {
    final journal = vault.createJournal('Photos');
    final id = vault.createEntry(journalId: journal,
      title: 'Imaginary sunset', body: 'A fictional photograph');
    final media = Uint8List.fromList([0, 20, 30, 40, 42, 100, 128, 255]);
    final mediaId = await vault.attachMedia(
      entryId: id, filename: 'sample.png', mime: 'image/png', bytes: media);
    final state = vault.snapshot();
    await ProductSnapshotCodec().validate(state);
    final attachment = (state['attachments'] as List).single;
    expect(attachment['id'], mediaId);
    expect(attachment['entryId'], id);
    final key = RecoveryKey.random();
    try {
      final result = await vault.exportEncrypted(recoveryKey: key);
      final recovered = await ProductEncryptedArchiveCodec().verify(
        recoveryKey: key, archive: result);
      expect(recovered['entries'], state['entries']);
      expect((recovered['attachments'] as List).single['name'], 'sample.png');
      final outside = String.fromCharCodes(result);
      expect(outside.contains('Imaginary sunset'), isFalse);
      expect(outside.contains('sample.png'), isFalse);
    } finally {
      key.destroy();
    }
  });

  test('wrong database key cannot open/overwrite valid encrypted journal', () {
    final journal = vault.createJournal('Safe');
    final id = vault.createEntry(
      journalId: journal, title: 'Only private sample', body: 'Unchanged');
    vault.close();
    final before = File(dbPath).readAsBytesSync();
    final other = TestVaultKey.random();
    try {
      expect(() => JournalVault.open(dbPath, key: other),
        throwsA(anyOf(isA<VaultUnlockFailed>(), isA<JournalUnavailable>())));
    } finally {
      other.destroy();
    }
    expect(File(dbPath).readAsBytesSync(), orderedEquals(before));
    vault = JournalVault.open(dbPath, key: dbKey);
    expect(vault.readEntry(id)!['title'], 'Only private sample');
  });

  test('existing vault is never overwritten by a create request', () {
    expect(() => JournalVault.open(dbPath, key: dbKey, create: true),
      throwsStateError);
    expect(vault.integrityCheck(), isTrue);
  });

  test('archive includes every revision and attachment, even Trash', () async {
    final a = vault.createJournal('Stories');
    final id = vault.createEntry(journalId: a,
      title: 'First', body: 'First text');
    final version = vault.editEntry(id: id, expectedVersion: 1, journalId: a,
      title: 'Second', body: 'Second text', eventAtMs: null);
    await vault.attachMedia(entryId: id,
      filename: 'day.png', mime: 'image/png', bytes: Uint8List.fromList([1,2,3,4]));
    vault.trashEntry(id, expectedVersion: version);
    final key = RecoveryKey.random();
    try {
      final bytes = await vault.exportEncrypted(recoveryKey: key);
      final verified = await ProductEncryptedArchiveCodec().verify(
        recoveryKey: key, archive: bytes);
      expect((verified['entries'] as List).length, 1);
      expect((verified['revisions'] as List).length, 2);
      expect((verified['attachments'] as List).length, 1);
      expect((verified['entries'] as List).single['deletedAtMs'], isNotNull);
    } finally {
      key.destroy();
    }
  });

  test('transactional snapshot cannot blend external writer revisions', () async {
    final journal = vault.createJournal('One');
    final id = vault.createEntry(journalId: journal,
      title: 'Before', body: 'Before text');
    final writer = JournalVault.open(dbPath, key: dbKey);
    try {
      final frozen = vault.snapshot(onAfterJournals: () {
        writer.editEntry(id: id, expectedVersion: 1, journalId: journal,
          title: 'After', body: 'After text', eventAtMs: null);
      });
      await ProductSnapshotCodec().validate(frozen);
      final entry = (frozen['entries'] as List).single;
      expect(entry['version'], 1);
      expect(entry['title'], 'Before');
      expect(frozen['revisions'], isEmpty);
      expect(writer.readEntry(id)!['version'], 2);
      final fresh = vault.snapshot();
      expect((fresh['entries'] as List).single['version'], 2);
      expect((fresh['revisions'] as List).length, 1);
    } finally {
      writer.close();
    }
  });

  test('recovery archive wrong key cannot expose snapshot', () async {
    final a = vault.createJournal('Memories');
    vault.createEntry(journalId: a, title: 'Private fiction',
      body: 'Only imagined material');
    final recovery = RecoveryKey.random();
    final other = RecoveryKey.random();
    try {
      final archive = await vault.exportEncrypted(recoveryKey: recovery);
      await expectLater(
        ProductEncryptedArchiveCodec().verify(
          recoveryKey: other, archive: archive),
        throwsA(isA<ArchiveRejected>()),
      );
    } finally {
      recovery.destroy();
      other.destroy();
    }
  });
}
