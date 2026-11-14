// Fictional-only recovery from a user-selected encrypted-document payload.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/portable_recovery_worker.dart';
import 'package:navin_journal_editor/fictional_archive_exporter.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late JournalEditorWorker worker;
  late TestVaultKey firstKey;
  late TestVaultKey recoveredKey;
  late String entryId;
  late String journalId;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nj-fictional-saf-test-');
    firstKey = TestVaultKey.random();
    recoveredKey = TestVaultKey.random();
    worker = await JournalEditorWorker.open(
      temp.path + '/initial.sqlite3', key: firstKey, create: true);
    journalId = await worker.createJournal('Imaginary Telugu notebook');
    final session = await worker.startSession(journalId: journalId);
    session.controller.update(
      title: 'Fictional scene', body: 'A fictional morning · తెలుగు 🌿');
    await session.save();
    expect(session.indicator.phase, SavePhase.saved);
    entryId = (await session.persistedEntryId())!;
    session.controller.update(
      title: 'Revised imaginary scene', body: 'Imagined revision only 🪷');
    await session.save();
    expect(await session.closeSafely(), isTrue);
  });

  tearDown(() async {
    await worker.close();
    firstKey.destroy();
    recoveredKey.destroy();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('user-selected encrypted bytes and manual key restore to a clean '
      'independent vault after source has been removed', () async {
    Uint8List? externalArchive;
    final receipt = await FictionalArchiveExporter.export(
      source: worker,
      writeEncryptedArchive: (ciphertext) async {
        expect(ciphertext.isNotEmpty, isTrue);
        expect(String.fromCharCodes(ciphertext), isNot(contains('Fictional')));
        expect(String.fromCharCodes(ciphertext), isNot(contains('తెలుగు')));
        externalArchive = Uint8List.fromList(ciphertext);
        return true; // Contract of native verified provider readback.
      },
    );
    expect(receipt, isNotNull);
    expect(receipt!.manualRecoveryKey.length, 43);
    expect(receipt.providerReadbackVerified, isTrue);
    expect(receipt.keyCustodyVerified, isFalse);
    expect(receipt.cleanDeviceRestoreVerified, isFalse);
    expect(externalArchive, isNotNull);
    expect(receipt.encryptedArchiveBytes, externalArchive!.length);

    // Simulates a separately retained encrypted document and recovery key;
    // the original database and its device-bound key are gone.
    await worker.close();
    File(temp.path + '/initial.sqlite3').deleteSync();
    firstKey.destroy();
    final independentlyEnteredKey =
        RecoveryKey.parse(receipt.manualRecoveryKey);
    final recovered = Directory(temp.path + '/new-device-fixture');
    try {
      final result = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: externalArchive!,
        recoveryKey: independentlyEnteredKey,
        destinationKey: recoveredKey,
        destination: recovered,
      );
      expect(result.entries, 1);
      expect(result.revisions, 1);
      expect(result.journals, 1);
    } finally {
      independentlyEnteredKey.destroy();
      externalArchive!.fillRange(0, externalArchive!.length, 0);
    }
    worker = await JournalEditorWorker.open(
      recovered.path + '/journal.sqlite3', key: recoveredKey);
    expect(await worker.integrityCheck(), isTrue);
    expect((await worker.readEntry(entryId))!['version'], 2);
    expect((await worker.readEntry(entryId))!['journalId'], journalId);
    final history = await worker.readRevisions(entryId);
    expect(history, hasLength(1));
    expect(history.single['body'], contains('తెలుగు'));
  });

  test('cancelled system document picker never reveals recovery key',
      () async {
    Uint8List? captured;
    final receipt = await FictionalArchiveExporter.export(
      source: worker,
      writeEncryptedArchive: (data) async {
        captured = data;
        return false;
      },
    );
    expect(receipt, isNull);
    expect(captured, isNotNull);
    expect(captured!.every((byte) => byte == 0), isTrue);
    expect((await worker.readEntry(entryId))!['version'], 2);
    expect(await worker.integrityCheck(), isTrue);
  });

  test('provider exception never returns key and wipes transferred payload',
      () async {
    Uint8List? captured;
    await expectLater(
      FictionalArchiveExporter.export(
        source: worker,
        writeEncryptedArchive: (data) async {
          captured = data;
          throw const FileSystemException('simulated provider failure');
        },
      ),
      throwsA(isA<FictionalExportUnavailable>()),
    );
    expect(captured, isNotNull);
    expect(captured!.every((byte) => byte == 0), isTrue);
    expect(await worker.integrityCheck(), isTrue);
  });

  test('closed source fails with no document writer invocation', () async {
    await worker.close();
    var calls = 0;
    await expectLater(FictionalArchiveExporter.export(
      source: worker,
      writeEncryptedArchive: (_) async {
        calls++;
        return true;
      },
    ), throwsA(isA<FictionalExportUnavailable>()));
    expect(calls, 0);
  });
}
