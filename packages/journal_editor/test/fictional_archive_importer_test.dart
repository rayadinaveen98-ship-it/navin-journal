// The imported encrypted file and manual key are fictional test fixtures.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_editor/fictional_archive_importer.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late TestVaultKey databaseKey;
  late JournalEditorWorker worker;
  late String pageId;
  late Uint8List archive;
  late String manualKey;
  late Map<String, Object?> sourcePage;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-import-fixture-');
    databaseKey = TestVaultKey.random();
    worker = await JournalEditorWorker.open(
      '${root.path}/source.sqlite3',
      key: databaseKey, create: true,
    );
    final journal = await worker.createJournal('Imagined notebook');
    final session = await worker.startSession(journalId: journal);
    session.controller.update(
      title: 'Fictional Telugu morning', body: 'ఊహించిన కథ 🌿 v1');
    await session.save();
    expect(session.indicator.phase, SavePhase.saved);
    pageId = (await session.persistedEntryId())!;
    session.controller.update(
      title: 'Imagined morning updated', body: 'ఊహించిన కథ 🌿 v2');
    await session.save();
    expect(await session.closeSafely(), isTrue);
    sourcePage = (await worker.readEntry(pageId))!;
    final key = RecoveryKey.random();
    try {
      manualKey = key.exportForOfflineStorage();
      archive = await worker.exportRecoveryArchive(key);
    } finally {
      key.destroy();
    }
  });

  tearDown(() async {
    await worker.close();
    databaseKey.destroy();
    archive.fillRange(0, archive.length, 0);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('separately held encrypted document + manually reentered key '
      'restore into independent throwaway vault without modifying source',
      () async {
    final imported = Uint8List.fromList(archive);
    final result = await FictionalArchiveImporter.inspect(
      encryptedArchive: imported,
      manuallyEnteredRecoveryKey: manualKey,
      trustedPrivateRoot: root,
    );
    expect(result.journals, 1);
    expect(result.entries, 1);
    expect(result.revisions, 1);
    expect(result.attachments, 0);
    expect(result.activeVaultReplaced, isFalse);
    expect(result.importedVaultRetained, isFalse);
    expect(result.independentlyRecoverableBackupVerified, isFalse);
    expect(imported.every((b) => b == 0), isTrue);
    expect(await worker.readEntry(pageId), sourcePage);
    expect(await worker.integrityCheck(), isTrue);
    expect(root.listSync().where((f) =>
        f.path.contains('.nj-fictional-import-review-')), isEmpty);
  });

  test('wrong manual key rejects and preserves source and unknown stages',
      () async {
    final unknown = Directory('${root.path}/.navin-journal-restore-unknown');
    unknown.createSync();
    final fixture = File('${unknown.path}/do-not-touch')..writeAsStringSync(
      'unknown interrupted restore marker');
    final wrong = RecoveryKey.random();
    final key = wrong.exportForOfflineStorage();
    wrong.destroy();
    final imported = Uint8List.fromList(archive);
    await expectLater(
      FictionalArchiveImporter.inspect(
        encryptedArchive: imported,
        manuallyEnteredRecoveryKey: key,
        trustedPrivateRoot: root,
      ),
      throwsA(isA<FictionalArchiveImportRejected>()),
    );
    expect(imported.every((b) => b == 0), isTrue);
    expect(fixture.readAsStringSync(), 'unknown interrupted restore marker');
    expect(await worker.readEntry(pageId), sourcePage);
    expect(await worker.integrityCheck(), isTrue);
  });

  test('tampered file fails closed without overwriting vault', () async {
    final tampered = Uint8List.fromList(archive);
    tampered[tampered.length ~/ 2] ^= 1;
    await expectLater(
      FictionalArchiveImporter.inspect(
        encryptedArchive: tampered,
        manuallyEnteredRecoveryKey: manualKey,
        trustedPrivateRoot: root,
      ),
      throwsA(isA<FictionalArchiveImportRejected>()),
    );
    expect(tampered.every((b) => b == 0), isTrue);
    expect(await worker.readEntry(pageId), sourcePage);
    expect(await worker.integrityCheck(), isTrue);
  });

  test('invalid key and missing private root never touch active vault',
      () async {
    final badKeyBytes = Uint8List.fromList(archive);
    await expectLater(FictionalArchiveImporter.inspect(
      encryptedArchive: badKeyBytes,
      manuallyEnteredRecoveryKey: 'not-a-valid-recovery-key',
      trustedPrivateRoot: root,
    ), throwsA(isA<FictionalArchiveImportRejected>()));
    expect(badKeyBytes.every((b) => b == 0), isTrue);
    final missingRootBytes = Uint8List.fromList(archive);
    await expectLater(FictionalArchiveImporter.inspect(
      encryptedArchive: missingRootBytes,
      manuallyEnteredRecoveryKey: manualKey,
      trustedPrivateRoot: Directory('${root.path}/not-existing'),
    ), throwsA(isA<FictionalArchiveImportRejected>()));
    expect(missingRootBytes.every((b) => b == 0), isTrue);
    expect(await worker.readEntry(pageId), sourcePage);
  });
}
