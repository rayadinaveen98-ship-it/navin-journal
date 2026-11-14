// Fictional-only portable restore over the real encrypted editor isolate.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/portable_recovery_worker.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory original;
  late Directory recovered;
  late JournalEditorWorker worker;
  late TestVaultKey oldKey;
  late TestVaultKey newKey;
  late RecoveryKey offlineKey;
  late Uint8List archive;
  late String journalId;
  late String entryId;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-portable-worker-');
    original = Directory(root.path + '/original-install');
    recovered = Directory(root.path + '/new-install');
    oldKey = TestVaultKey.random();
    newKey = TestVaultKey.random();
    offlineKey = RecoveryKey.random();
    worker = await JournalEditorWorker.open(
      original.path + '/journal.sqlite3', key: oldKey, create: true);
    journalId = await worker.createJournal('Imaginary Journal');
    final a = await worker.startSession(
      journalId: journalId, debounce: const Duration(days: 1));
    a.controller.update(title: 'Fictional day',
      body: 'An imagined entry · తెలుగు 🌿');
    await a.save();
    expect(a.indicator.phase, SavePhase.saved);
    entryId = (await a.persistedEntryId())!;
    expect(await a.closeSafely(), isTrue);
    final b = await worker.startSession(
      journalId: journalId, existingEntryId: entryId,
      debounce: const Duration(days: 1));
    b.controller.update(title: 'Fictional day revisited',
      body: 'An imagined revision · 🪷');
    await b.save();
    expect(b.indicator.databaseVersion, 2);
    expect(await b.closeSafely(), isTrue);
    archive = await worker.exportRecoveryArchive(offlineKey);
  });

  tearDown(() async {
    await worker.close();
    oldKey.destroy();
    newKey.destroy();
    offlineKey.destroy();
    archive.fillRange(0, archive.length, 0);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('authenticated export contains no recognizable fictional plaintext', () async {
    expect(archive, isNotEmpty);
    final text = String.fromCharCodes(archive);
    expect(text, isNot(contains('Fictional day')));
    expect(text, isNot(contains('తెలుగు')));
    expect(text, isNot(contains('Imaginary Journal')));
    expect(await worker.historyCount(entryId), 1);
  });

  test('restores from off-device recovery key after original vault is deleted', () async {
    final externalKey = offlineKey.exportForOfflineStorage();
    await worker.close();
    original.deleteSync(recursive: true);
    oldKey.destroy();
    final reentered = RecoveryKey.parse(externalKey);
    try {
      final receipt = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive, recoveryKey: reentered,
        destinationKey: newKey, destination: recovered);
      expect(receipt.journals, 1);
      expect(receipt.entries, 1);
      expect(receipt.revisions, 1);
      expect(receipt.attachments, 0);
    } finally {
      reentered.destroy();
    }
    worker = await JournalEditorWorker.open(
      recovered.path + '/journal.sqlite3', key: newKey);
    expect(await worker.integrityCheck(), isTrue);
    expect((await worker.listJournals()).single['id'], journalId);
    expect((await worker.readEntry(entryId))!['version'], 2);
    expect((await worker.readEntry(entryId))!['body'], contains('imagined revision'));
    final history = await worker.readRevisions(entryId);
    expect(history, hasLength(1));
    expect(history.single['version'], 1);
    expect(history.single['body'], contains('తెలుగు'));
  });

  test('wrong recovery key rejects before creating destination', () async {
    final wrong = RecoveryKey.random();
    try {
      await expectLater(
        PortableRecoveryWorker.restoreToNewVault(
          encryptedArchive: archive, recoveryKey: wrong,
          destinationKey: newKey, destination: recovered),
        throwsA(isA<ProductRestoreRejected>()));
      expect(recovered.existsSync(), isFalse);
      expect(root.listSync().where((x) =>
        x.path.contains('.navin-journal-restore-')), isEmpty);
      expect(await worker.integrityCheck(), isTrue);
    } finally {
      wrong.destroy();
    }
  });

  test('tampered archive fails closed without touching original', () async {
    final damaged = Uint8List.fromList(archive);
    damaged[damaged.length ~/ 2] ^= 1;
    try {
      await expectLater(
        PortableRecoveryWorker.restoreToNewVault(
          encryptedArchive: damaged, recoveryKey: offlineKey,
          destinationKey: newKey, destination: recovered),
        throwsA(isA<ProductRestoreRejected>()));
      expect(recovered.existsSync(), isFalse);
      expect((await worker.readEntry(entryId))!['version'], 2);
    } finally {
      damaged.fillRange(0, damaged.length, 0);
    }
  });

  test('occupied destination refuses replacement and remains byte-identical', () async {
    recovered.createSync(recursive: true);
    final keep = File(recovered.path + '/keep-test-data')
      ..writeAsStringSync('unaltered');
    await expectLater(
      PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive, recoveryKey: offlineKey,
        destinationKey: newKey, destination: recovered),
      throwsA(isA<ProductRestoreRejected>()));
    expect(keep.readAsStringSync(), 'unaltered');
    expect(File(recovered.path + '/journal.sqlite3').existsSync(), isFalse);
  });

  test('new database key works, original database key does not', () async {
    await PortableRecoveryWorker.restoreToNewVault(
      encryptedArchive: archive, recoveryKey: offlineKey,
      destinationKey: newKey, destination: recovered);
    await expectLater(
      JournalEditorWorker.open(
        recovered.path + '/journal.sqlite3', key: oldKey),
      throwsA(isA<JournalEditorWorkerUnavailable>()));
    final reopened = await JournalEditorWorker.open(
      recovered.path + '/journal.sqlite3', key: newKey);
    try {
      expect(await reopened.integrityCheck(), isTrue);
      expect(await reopened.historyCount(entryId), 1);
    } finally {
      await reopened.close();
    }
  });
  test('debug ENOSPC before publication leaves no vault or stage, retry succeeds',
      () async {
    await expectLater(
      PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive,
        recoveryKey: offlineKey,
        destinationKey: newKey,
        destination: recovered,
        faultCheckpointForDiagnostics: 'after_ready_marker_write',
      ),
      throwsA(isA<ProductRestoreRejected>()),
    );
    expect(recovered.existsSync(), isFalse);
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
    expect(await worker.integrityCheck(), isTrue);

    final receipt = await PortableRecoveryWorker.restoreToNewVault(
      encryptedArchive: archive,
      recoveryKey: offlineKey,
      destinationKey: newKey,
      destination: recovered,
    );
    expect(receipt.entries, 1);
    final reopened = await JournalEditorWorker.open(
      recovered.path + '/journal.sqlite3', key: newKey);
    try {
      expect(await reopened.integrityCheck(), isTrue);
      expect(await reopened.historyCount(entryId), 1);
    } finally {
      await reopened.close();
    }
  });

  test('debug ENOSPC after rename keeps authenticated vault for safe reopen',
      () async {
    await expectLater(
      PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive,
        recoveryKey: offlineKey,
        destinationKey: newKey,
        destination: recovered,
        faultCheckpointForDiagnostics: 'before_parent_post_rename_fsync',
      ),
      throwsA(isA<ProductRestoreRejected>()),
    );
    expect(recovered.existsSync(), isTrue);
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
    final marker = File(recovered.path + '/.navin-restore-ready-v1');
    expect(marker.readAsStringSync(), 'NJR-RESTORE-PUBLISHED-V1\n');
    final reopened = await JournalEditorWorker.open(
      recovered.path + '/journal.sqlite3', key: newKey);
    try {
      expect(await reopened.integrityCheck(), isTrue);
      expect((await reopened.readEntry(entryId))!['version'], 2);
      expect((await reopened.readRevisions(entryId)), hasLength(1));
    } finally {
      await reopened.close();
    }
  });

  test('unknown diagnostic fault cannot be enabled', () async {
    await expectLater(
      PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive, recoveryKey: offlineKey,
        destinationKey: newKey, destination: recovered,
        faultCheckpointForDiagnostics: 'after_stage_created',
      ),
      throwsA(isA<ProductRestoreRejected>()),
    );
    expect(recovered.existsSync(), isFalse);
  });

  test('background worker can assess an abandoned encrypted stage without promotion',
      () async {
    final parent = Directory(root.path + '/quarantine');
    parent.createSync();
    final candidate = NativeRestorePublisher.stagePrefix + 'workerABC123';
    final stage = Directory(parent.path + '/' + candidate);
    stage.createSync();
    final db = JournalVault.open(stage.path + '/journal.sqlite3',
        key: newKey, create: true);
    try {
      await db.importIntoEmpty(await ProductEncryptedArchiveCodec().verify(
        recoveryKey: offlineKey, archive: archive));
    } finally {
      db.close();
    }
    final before = File(stage.path + '/journal.sqlite3').readAsBytesSync();
    final report = await PortableRecoveryWorker.assessQuarantinedStage(
      privateParent: parent, candidateBasename: candidate,
      encryptedArchive: archive, recoveryKey: offlineKey,
      stagedDatabaseKey: newKey,
    );
    expect(report.status, RestoreAssessmentStatus.verifiedQuarantined);
    expect(report.isAuthenticatedMatch, isTrue);
    expect(report.publicationMarkerObserved, isFalse);
    expect(report.journalCount, 1);
    expect(report.entryCount, 1);
    expect(report.revisionCount, 1);
    expect(stage.existsSync(), isTrue);
    expect(File(stage.path + '/journal.sqlite3').readAsBytesSync(), before);
    expect(await worker.integrityCheck(), isTrue);
  });

  test('background worker assessment rejects wrong archive key without data loss',
      () async {
    final parent = Directory(root.path + '/quarantine');
    parent.createSync();
    final candidate = NativeRestorePublisher.stagePrefix + 'workerABC123';
    final stage = Directory(parent.path + '/' + candidate)..createSync();
    File(stage.path + '/journal.sqlite3').writeAsBytesSync([1, 2, 3]);
    final wrong = RecoveryKey.random();
    try {
      final report = await PortableRecoveryWorker.assessQuarantinedStage(
        privateParent: parent, candidateBasename: candidate,
        encryptedArchive: archive, recoveryKey: wrong,
        stagedDatabaseKey: newKey,
      );
      expect(report.status, RestoreAssessmentStatus.untrustedArchive);
      expect(File(stage.path + '/journal.sqlite3').readAsBytesSync(),
          [1, 2, 3]);
    } finally {
      wrong.destroy();
    }
  });

  test('background worker assessment blocks path traversal and unsafe names',
      () async {
    final report = await PortableRecoveryWorker.assessQuarantinedStage(
      privateParent: root,
      candidateBasename: '../../do-not-read',
      encryptedArchive: archive, recoveryKey: offlineKey,
      stagedDatabaseKey: newKey,
    );
    expect(report.status, RestoreAssessmentStatus.blocked);
    expect(await worker.integrityCheck(), isTrue);
  });

}
