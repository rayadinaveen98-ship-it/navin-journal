// V3 external encrypted recovery proof (FICTIONAL DATA ONLY).
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_editor/fictional_v3_external_transfer.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_archive_v3.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late TestVaultKey sourceKey;
  late JournalEditorWorker worker;
  late String journalId;
  late String sourceId;
  late String preservedId;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-v3-saf-proof-');
    sourceKey = TestVaultKey.random();
    worker = await JournalEditorWorker.open(
      '${root.path}${Platform.pathSeparator}source.sqlite3',
      key: sourceKey,
      create: true,
    );
    journalId = await worker.createJournal('Only imaginary content');
    final created = await worker.startSession(
      journalId: journalId, debounce: const Duration(days: 1));
    created.controller.update(
      title: 'Imagined source', body: 'Fictional Telugu మొదటి పేజీ 🌿');
    await created.save();
    sourceId = (await created.persistedEntryId())!;
    final winner = await worker.startSession(
      journalId: journalId, existingEntryId: sourceId,
      debounce: const Duration(days: 1));
    final loser = await worker.startSession(
      journalId: journalId, existingEntryId: sourceId,
      debounce: const Duration(days: 1));
    winner.controller.update(
      title: 'Original newer revision', body: 'Never overwrite this page');
    await winner.save();
    loser.controller.update(
      title: 'Imaginary second version',
      body: 'Preserved fictional Telugu రెండవ పేజీ 🪷');
    await loser.save();
    expect(loser.indicator.phase, SavePhase.conflict);
    final receipt = await loser.preserveConflictCopyAsNew();
    expect(receipt.matchesCurrentDraft, isTrue);
    preservedId = receipt.entryId;
  });

  tearDown(() async {
    await worker.close();
    sourceKey.destroy();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('V3 document and separate manual key authenticate and restore '
      'original, history, copy and encrypted provenance', () async {
    Uint8List? transferred;
    final proof = await FictionalV3ExternalTransfer.export(
      source: worker,
      writeEncryptedArchive: (bytes) async {
        transferred = Uint8List.fromList(bytes);
        return true; // Simulated native provider write + exact readback.
      },
    );
    expect(proof, isNotNull);
    expect(proof!.providerReadbackVerified, isTrue);
    expect(proof.cleanDeviceRestoreVerified, isFalse);
    expect(proof.keyCustodyVerified, isFalse);
    expect(proof.manualRecoveryKey.length, 43);
    final bytes = transferred!;
    expect(String.fromCharCodes(bytes).contains('Preserved fictional'),
        isFalse);
    final recovery = RecoveryKey.parse(proof.manualRecoveryKey);
    try {
      final verified = await ProductArchiveV3Codec().verify(
        recoveryKey: recovery, archive: bytes);
      expect(verified.archiveFormat, ProductArchiveV3Codec.format);
      expect(verified.hasAuthenticatedConflictProvenance, isTrue);
      expect(verified.snapshot['conflictCopyReceipts'], hasLength(1));
    } finally {
      recovery.destroy();
    }

    // No original device key is sent into the V3 importer.
    final report = await FictionalV3ExternalTransfer.inspect(
      encryptedArchive: bytes,
      manuallyEnteredRecoveryKey: proof.manualRecoveryKey,
      trustedPrivateRoot: root,
    );
    expect(report.journals, 1);
    expect(report.entries, 2);
    expect(report.revisions, 1);
    expect(report.attachments, 0);
    expect(report.conflictReceipts, 1);
    expect(report.activeVaultReplaced, isFalse);
    expect(report.retainedForFutureUse, isFalse);
    expect(report.privateDataReady, isFalse);
    expect(report.newDeviceKeyCustodyVerified, isFalse);
    expect(bytes.every((b) => b == 0), isTrue);
    expect(root.listSync().where((file) =>
        file.path.contains('.nj-fictional-v3-import-review-')), isEmpty);
    expect((await worker.readEntry(sourceId))!['body'],
        'Never overwrite this page');
    expect((await worker.readEntry(preservedId))!['body'],
        'Preserved fictional Telugu రెండవ పేజీ 🪷');
    expect((await worker.fictionalConflictCopiesForSource(sourceId)).single
        ['copyEntryId'], preservedId);
  });

  test('wrong key rejects before staging, preserves unknown data and wipes '
      'owned ciphertext', () async {
    Uint8List? out;
    final receipt = await FictionalV3ExternalTransfer.export(
      source: worker,
      writeEncryptedArchive: (bytes) async {
        out = Uint8List.fromList(bytes);
        return true;
      },
    );
    expect(receipt, isNotNull);
    final sentinel = Directory('${root.path}/unknown-recovery-state')
      ..createSync();
    final sentinelFile = File('${sentinel.path}/do-not-touch')
      ..writeAsStringSync('preexisting confidential file');
    final other = RecoveryKey.random();
    final wrongKey = other.exportForOfflineStorage();
    other.destroy();
    await expectLater(FictionalV3ExternalTransfer.inspect(
      encryptedArchive: out!,
      manuallyEnteredRecoveryKey: wrongKey,
      trustedPrivateRoot: root,
    ), throwsA(isA<FictionalV3TransferRejected>()));
    expect(out!.every((b) => b == 0), isTrue);
    expect(sentinelFile.readAsStringSync(), 'preexisting confidential file');
    expect(root.listSync().where((f) =>
        f.path.contains('.nj-fictional-v3-import-review-')), isEmpty);
    expect((await worker.readEntry(sourceId))!['version'], 2);
  });

  test('cancel and provider failure never reveal key; ciphertext wiped',
      () async {
    Uint8List? transient;
    final cancelled = await FictionalV3ExternalTransfer.export(
      source: worker,
      writeEncryptedArchive: (bytes) async {
        transient = bytes;
        return false;
      },
    );
    expect(cancelled, isNull);
    expect(transient, isNotNull);
    expect(transient!.every((b) => b == 0), isTrue);
    await expectLater(FictionalV3ExternalTransfer.export(
      source: worker,
      writeEncryptedArchive: (bytes) async {
        transient = bytes;
        throw const FileSystemException('provider interrupted');
      },
    ), throwsA(isA<FictionalV3TransferRejected>()));
    expect(transient!.every((b) => b == 0), isTrue);
    expect((await worker.readEntry(sourceId))!['version'], 2);
  });

  test('authenticated older V2 archive explicitly cannot masquerade as V3',
      () async {
    final oldKey = TestVaultKey.random();
    final oldWorker = await JournalEditorWorker.open(
      '${root.path}/legacy-only.sqlite3', key: oldKey, create: true,
    );
    final backupKey = RecoveryKey.random();
    Uint8List? bytes;
    try {
      final journal = await oldWorker.createJournal('Legacy fictional');
      final editor = await oldWorker.startSession(journalId: journal);
      editor.controller.update(title: 'Legacy', body: 'V2 fiction only');
      await editor.save();
      bytes = await oldWorker.exportRecoveryArchive(backupKey);
      final owned = Uint8List.fromList(bytes);
      await expectLater(FictionalV3ExternalTransfer.inspect(
        encryptedArchive: owned,
        manuallyEnteredRecoveryKey: backupKey.exportForOfflineStorage(),
        trustedPrivateRoot: root,
      ), throwsA(isA<FictionalV3TransferRejected>()));
      expect(owned.every((b) => b == 0), isTrue);
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      backupKey.destroy();
      await oldWorker.close();
      oldKey.destroy();
    }
  });
}
