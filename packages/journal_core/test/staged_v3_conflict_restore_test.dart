// Stage 5D.1-E2 — fictional-only encrypted V3 snapshot/restore acceptance.
import 'dart:io';

import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_archive_v3.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late JournalVault source;
  late TestVaultKey sourceKey;
  late TestVaultKey targetKey;
  late RecoveryKey recoveryKey;
  late String sourcePath;
  late String journal;
  late String original;
  late String copyId;

  const operationId = 'fictional-v3-operation-0123456789abcdef';

  setUp(() {
    root = Directory.systemTemp.createTempSync('nj-v3-fictional-');
    sourcePath = '${root.path}${Platform.pathSeparator}source.sqlite3';
    sourceKey = TestVaultKey.random();
    targetKey = TestVaultKey.random();
    recoveryKey = RecoveryKey.random();
    source = JournalVault.open(sourcePath, key: sourceKey, create: true);
    journal = source.createJournal('Fictional private-like pages');
    original = source.createEntry(journalId: journal,
      title: 'Before', body: 'Original Telugu తెలుగు');
    source.editEntry(id: original, expectedVersion: 1,
      journalId: journal, title: 'Newest saved version',
      body: 'Winner — no destructive overwrite', eventAtMs: null);
    copyId = source.preserveConflictCopy(
      operationId: operationId, sourceEntryId: original,
      journalId: journal, expectedOriginalVersion: 1,
      title: 'Conflicting imaginary draft',
      body: 'Losing unsaved draft 🪷 తెలుగు');
  });

  tearDown(() {
    source.close();
    sourceKey.destroy();
    targetKey.destroy();
    recoveryKey.destroy();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Directory target([String name = 'new-device']) =>
      Directory('${root.path}${Platform.pathSeparator}$name');
  String databasePath(Directory dest) =>
      '${dest.path}${Platform.pathSeparator}${StagedProductRestorer.databaseName}';

  test('authenticated V3 export restores receipts, history and original',
      () async {
    expect(() => source.snapshot(), throwsA(isA<JournalUnavailable>()));
    final before = source.snapshotV3();
    await ProductSnapshotV3Codec().validate(before);
    expect((before['conflictCopyReceipts'] as List).length, 1);

    final archive = await source.exportEncryptedV3(recoveryKey: recoveryKey);
    final verified = await ProductArchiveV3Codec().verify(
      recoveryKey: recoveryKey, archive: archive);
    expect(verified.hasAuthenticatedConflictProvenance, isTrue);
    expect(verified.snapshot['conflictCopyReceipts'],
        before['conflictCopyReceipts']);

    final saved = await StagedProductRestorer().restoreV3New(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: targetKey, destination: target());
    expect(saved.entries, 2);
    expect(saved.revisions, 1);
    final reopened = JournalVault.open(databasePath(target()), key: targetKey);
    try {
      expect(reopened.integrityCheck(), isTrue);
      final after = reopened.snapshotV3();
      expect(StagedProductRestorer.equivalentSnapshots(before, after), isTrue);
      expect(reopened.readEntry(original)!['body'],
          'Winner — no destructive overwrite');
      expect(reopened.readEntry(copyId)!['body'],
          'Losing unsaved draft 🪷 తెలుగు');
      expect(reopened.conflictCopiesForSource(original).single['copyEntryId'],
          copyId);
      expect(reopened.listRevisions(original).length, 1);
      // Same opaque operation ID with exact content returns committed copy.
      expect(reopened.preserveConflictCopy(
        operationId: operationId, sourceEntryId: original,
        journalId: journal, expectedOriginalVersion: 1,
        title: 'Conflicting imaginary draft',
        body: 'Losing unsaved draft 🪷 తెలుగు'), copyId);
      expect(reopened.listEntries(journalId: journal).length, 2);
      expect(() => reopened.snapshot(), throwsA(isA<JournalUnavailable>()));
    } finally {
      reopened.close();
    }
    // Cryptographic bytes are not plaintext SQLite or journal writing.
    final bytes = File(databasePath(target())).readAsBytesSync();
    expect(String.fromCharCodes(bytes).contains('Losing unsaved draft'), isFalse);
    expect(String.fromCharCodes(bytes).contains(operationId), isFalse);
  });

  test('revised and trashed copy keeps authentic historical provenance',
      () async {
    final otherJournal = source.createJournal('Older fiction');
    source.editEntry(id: copyId, expectedVersion: 1,
      journalId: otherJournal, title: 'Copy edited later',
      body: 'Updated fictional text', eventAtMs: null);
    source.trashEntry(copyId, expectedVersion: 2);
    final before = source.snapshotV3();
    final archive = await source.exportEncryptedV3(recoveryKey: recoveryKey);
    await StagedProductRestorer().restoreV3New(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: targetKey, destination: target());
    final reopened = JournalVault.open(databasePath(target()), key: targetKey);
    try {
      expect(StagedProductRestorer.equivalentSnapshots(
          before, reopened.snapshotV3()), isTrue);
      final receipt = reopened.conflictCopiesForSource(original).single;
      expect(receipt['copyEntryId'], copyId);
      expect(receipt['copyVersion'], 3);
      expect(receipt['copyDeletedAtMs'], isNotNull);
      expect(reopened.readEntry(original)!['version'], 2);
      expect(reopened.listRevisions(original).length, 1);
    } finally {
      reopened.close();
    }
  });

  test('receipt import fault rolls back every entry, revision and ledger',
      () async {
    final dest = target('rollback');
    final injectPath = databasePath(dest);
    final importing = JournalVault.open(injectPath,
      key: targetKey, create: true, injectFailure: (at) {
        if (at == 'after_import_conflict_receipt') {
          throw StateError('Injected incomplete receipt import');
        }
      });
    try {
      await expectLater(importing.importV3IntoEmpty(source.snapshotV3()),
          throwsStateError);
      final after = importing.snapshotV3();
      expect(after['journals'], isEmpty);
      expect(after['entries'], isEmpty);
      expect(after['revisions'], isEmpty);
      expect(after['conflictCopyReceipts'], isEmpty);
    } finally {
      importing.close();
    }
    final reopened = JournalVault.open(injectPath, key: targetKey);
    try {
      expect(reopened.integrityCheck(), isTrue);
      expect(reopened.snapshotV3()['entries'], isEmpty);
    } finally {
      reopened.close();
    }
  });

  test('V3 restore faults before publication leave no visible target',
      () async {
    final archive = await source.exportEncryptedV3(recoveryKey: recoveryKey);
    final dest = target('injected');
    await expectLater(
      StagedProductRestorer(injectFailure: (at) {
        if (at == 'after_import_conflict_receipt') {
          throw StateError('Injected rollback before publication');
        }
      }).restoreV3New(
        encryptedArchive: archive, recoveryKey: recoveryKey,
        destinationKey: targetKey, destination: dest,
      ), throwsA(isA<ProductRestoreRejected>()),
    );
    expect(await dest.exists(), isFalse);
    expect(root.listSync().where(
      (item) => item.path.contains('.navin-journal-restore-')), isEmpty);
  });

  test('V3 cannot overwrite an occupied destination or nonempty vault',
      () async {
    final archive = await source.exportEncryptedV3(recoveryKey: recoveryKey);
    final occupied = target('occupied');
    occupied.createSync();
    final sentinel = File('${occupied.path}${Platform.pathSeparator}keep.txt');
    sentinel.writeAsStringSync('Must survive');
    await expectLater(StagedProductRestorer().restoreV3New(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: targetKey, destination: occupied,
    ), throwsA(isA<ProductRestoreRejected>()));
    expect(sentinel.readAsStringSync(), 'Must survive');

    final targetVault = JournalVault.open(databasePath(target('nonempty')),
      key: targetKey, create: true);
    try {
      targetVault.createJournal('Existing');
      await expectLater(targetVault.importV3IntoEmpty(source.snapshotV3()),
          throwsA(isA<JournalUnavailable>()));
      expect(targetVault.listJournals().single['name'], 'Existing');
      expect(targetVault.snapshotV3()['conflictCopyReceipts'], isEmpty);
    } finally {
      targetVault.close();
    }
  });

  test('wrong V3 key or V2-only archive is rejected before staging',
      () async {
    final archive = await source.exportEncryptedV3(recoveryKey: recoveryKey);
    final wrong = RecoveryKey.random();
    try {
      await expectLater(StagedProductRestorer().restoreV3New(
        encryptedArchive: archive, recoveryKey: wrong,
        destinationKey: targetKey, destination: target('wrong'),
      ), throwsA(isA<ArchiveRejected>()));
      expect(target('wrong').existsSync(), isFalse);
    } finally {
      wrong.destroy();
    }
    // An older archive with no receipts remains readable by the V2 path;
    // never pretend its provenance can be recovered from a format it lacks.
    final legacySource = JournalVault.open(databasePath(target('legacy-source')),
      key: targetKey, create: true);
    try {
      final id = legacySource.createJournal('Legacy');
      legacySource.createEntry(journalId: id, title: 'Page', body: 'Fictional');
      final v2 = await legacySource.exportEncrypted(recoveryKey: recoveryKey);
      final inspected = await ProductArchiveV3Codec().verify(
        recoveryKey: recoveryKey, archive: v2);
      expect(inspected.hasAuthenticatedConflictProvenance, isFalse);
      await expectLater(StagedProductRestorer().restoreV3New(
        encryptedArchive: v2, recoveryKey: recoveryKey,
        destinationKey: targetKey, destination: target('wrong-format'),
      ), throwsA(isA<ArchiveRejected>()));
      expect(target('wrong-format').existsSync(), isFalse);
    } finally {
      legacySource.close();
    }
  });

  test('V3 WAL snapshot does not mix two committed versions or receipts',
      () async {
    final concurrent = JournalVault.open(sourcePath, key: sourceKey);
    try {
      final frozen = source.snapshotV3(onAfterJournals: () {
        concurrent.editEntry(id: original, expectedVersion: 2,
          journalId: journal, title: 'Later update',
          body: 'Another committed version', eventAtMs: null);
      });
      await ProductSnapshotV3Codec().validate(frozen);
      final entry = (frozen['entries'] as List)
          .firstWhere((e) => e['id'] == original) as Map;
      expect(entry['version'], 2);
      expect((frozen['conflictCopyReceipts'] as List).single
          ['competingOriginalVersion'], 2);
      final current = source.snapshotV3();
      final changed = (current['entries'] as List)
          .firstWhere((e) => e['id'] == original) as Map;
      expect(changed['version'], 3);
      expect(source.conflictCopiesForSource(original).length, 1);
    } finally {
      concurrent.close();
    }
  });
}
