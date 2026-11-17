// Stage 5D.1-E3: encrypted editor worker V3 integration, fictional data only.
// Never use this fixture as a private journal or treat it as device certification.
import 'dart:io';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_archive_v3.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late TestVaultKey sourceKey;
  late TestVaultKey restoreKey;
  late RecoveryKey recoveryKey;
  late JournalEditorWorker worker;
  late String dbPath;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-stage5d1-e3-');
    sourceKey = TestVaultKey.random();
    restoreKey = TestVaultKey.random();
    recoveryKey = RecoveryKey.random();
    dbPath = '${root.path}${Platform.pathSeparator}journal.sqlite3';
    worker = await JournalEditorWorker.open(
      dbPath, key: sourceKey, create: true,
    );
  });

  tearDown(() async {
    await worker.close();
    sourceKey.destroy();
    restoreKey.destroy();
    recoveryKey.destroy();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('worker V3 archive retains conflicted copy provenance through '
      'independent encrypted clean-vault restore', () async {
    final journalId = await worker.createJournal('Fictional Telugu notebook');
    final created = await worker.startSession(
      journalId: journalId, debounce: const Duration(days: 1),
    );
    created.controller.update(
      title: 'Imagined afternoon', body: 'మొదటి కల్పిత పేజీ 🌿',
    );
    await created.save();
    final originalId = (await created.persistedEntryId())!;

    // V2 must remain usable for a vault that has no conflict-copy receipts.
    final legacyArchive = await worker.exportRecoveryArchive(recoveryKey);
    final legacy = await ProductArchiveV3Codec().verify(
      recoveryKey: recoveryKey, archive: legacyArchive,
    );
    expect(legacy.hasAuthenticatedConflictProvenance, isFalse);

    final winner = await worker.startSession(
      journalId: journalId, existingEntryId: originalId,
      debounce: const Duration(days: 1),
    );
    final loser = await worker.startSession(
      journalId: journalId, existingEntryId: originalId,
      debounce: const Duration(days: 1),
    );
    winner.controller.update(
      title: 'Newest imaginary version',
      body: 'A newer encrypted revision, never overwritten',
    );
    await winner.save();
    loser.controller.update(
      title: 'Separate fictional version',
      body: 'రెండవ కల్పిత పేజీ 🪷',
    );
    await loser.save();
    expect(loser.controller.hasUnresolvedConflict, isTrue);
    final preserved = await loser.preserveConflictCopyAsNew();
    expect(preserved.matchesCurrentDraft, isTrue);
    expect(loser.indicator.phase, SavePhase.conflict);
    expect((await worker.readEntry(originalId))!['version'], 2);
    expect(await worker.historyCount(originalId), 1);

    // A V2 export with receipts is prohibited: it would lose provenance.
    await expectLater(worker.exportRecoveryArchive(recoveryKey),
        throwsA(isA<JournalEditorWorkerUnavailable>()));

    final archive = await worker.exportRecoveryArchiveV3(recoveryKey);
    final verified = await ProductArchiveV3Codec().verify(
      recoveryKey: recoveryKey, archive: archive,
    );
    expect(verified.archiveFormat, ProductArchiveV3Codec.format);
    expect(verified.hasAuthenticatedConflictProvenance, isTrue);
    final receipts = verified.snapshot['conflictCopyReceipts'] as List;
    expect(receipts, hasLength(1));
    expect(receipts.single['operationId'], loser.sessionId);
    expect(receipts.single['copyEntryId'], preserved.entryId);

    // The existing vault is never the restore target, even if occupied.
    final target = Directory(
      '${root.path}${Platform.pathSeparator}fresh-encrypted-recovery',
    );
    await StagedProductRestorer().restoreV3New(
      encryptedArchive: archive,
      recoveryKey: recoveryKey,
      destinationKey: restoreKey,
      destination: target,
    );
    final reopened = JournalVault.open(
      '${target.path}${Platform.pathSeparator}'
      '${StagedProductRestorer.databaseName}',
      key: restoreKey,
    );
    try {
      expect(reopened.integrityCheck(), isTrue);
      expect(reopened.readEntry(originalId)!['body'],
          'A newer encrypted revision, never overwritten');
      expect(reopened.listRevisions(originalId), hasLength(1));
      expect(reopened.readEntry(preserved.entryId)!['body'],
          'రెండవ కల్పిత పేజీ 🪷');
      expect(reopened.conflictCopiesForSource(originalId).single['operationId'],
          loser.sessionId);
      expect(StagedProductRestorer.equivalentSnapshots(
          verified.snapshot, reopened.snapshotV3()), isTrue);
    } finally {
      reopened.close();
    }
    expect(await worker.integrityCheck(), isTrue);
    expect((await worker.readEntry(originalId))!['version'], 2);
  });

  test('worker V3 without receipts is valid; wrong-key verification '
      'rejects without creating a destination', () async {
    final id = await worker.createJournal('Empty fictional book');
    final editor = await worker.startSession(journalId: id);
    editor.controller.update(
      title: 'Fictional book', body: 'Only invented writing',
    );
    await editor.save();
    final archive = await worker.exportRecoveryArchiveV3(recoveryKey);
    final verified = await ProductArchiveV3Codec().verify(
      recoveryKey: recoveryKey, archive: archive,
    );
    expect(verified.hasAuthenticatedConflictProvenance, isTrue);
    expect(verified.snapshot['conflictCopyReceipts'], isEmpty);

    final wrong = RecoveryKey.random();
    final destination = Directory(
      '${root.path}${Platform.pathSeparator}wrong-key-must-not-exist',
    );
    try {
      await expectLater(StagedProductRestorer().restoreV3New(
        encryptedArchive: archive, recoveryKey: wrong,
        destinationKey: restoreKey, destination: destination,
      ), throwsA(isA<ArchiveRejected>()));
      expect(destination.existsSync(), isFalse);
    } finally {
      wrong.destroy();
    }
  });
}
