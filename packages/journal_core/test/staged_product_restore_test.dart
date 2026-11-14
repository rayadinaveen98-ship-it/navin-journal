// A4.3.4a independent clean-vault restore verification: fictional data only.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late JournalVault source;
  late TestVaultKey originalKey;
  late TestVaultKey newDeviceKey;
  late RecoveryKey recoveryKey;
  late String sourcePath;
  late Uint8List archive;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-full-restore-');
    sourcePath = root.path + Platform.pathSeparator + 'original.sqlite3';
    originalKey = TestVaultKey.random();
    newDeviceKey = TestVaultKey.random();
    recoveryKey = RecoveryKey.random();
    source = JournalVault.open(sourcePath, key: originalKey, create: true);
    final daily = source.createJournal('My Journal');
    final old = source.createJournal('Older Pages');
    final id = source.createEntry(journalId: daily,
      title: 'నా రోజు', body: 'Imaginary bilingual diary. తెలుగు 🌿');
    final v2 = source.editEntry(id: id, expectedVersion: 1,
      journalId: old, title: 'Changed once', body: 'New fictional text',
      eventAtMs: 1699999999999);
    await source.attachMedia(entryId: id, filename: 'moment.png',
      mime: 'image/png', bytes: Uint8List.fromList([0, 10, 20, 30, 128, 255]));
    final v3 = source.trashEntry(id, expectedVersion: v2);
    source.restoreEntry(id, destinationJournalId: daily);
    final trashed = source.createEntry(journalId: old,
      title: 'To Trash', body: 'Not currently visible');
    source.trashEntry(trashed, expectedVersion: 1);
    source.archiveJournal(old, archived: true);
    source.trashJournal(old);
    expect(v3, 3);
    archive = await source.exportEncrypted(recoveryKey: recoveryKey);
  });

  tearDown(() {
    source.close();
    originalKey.destroy();
    newDeviceKey.destroy();
    recoveryKey.destroy();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Directory destination([String name = 'new-device']) =>
    Directory(root.path + Platform.pathSeparator + name);

  Future<void> assertNoRestore(Directory target) async {
    expect(await target.exists(), isFalse);
    expect(await File(target.path).exists(), isFalse);
    expect(await Link(target.path).exists(), isFalse);
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
  }

  test('full archive restores journals, historical moves, revisions, Trash and media', () async {
    final receipt = await StagedProductRestorer().restoreNew(
      encryptedArchive: archive,
      recoveryKey: recoveryKey,
      destinationKey: newDeviceKey,
      destination: destination(),
    );
    expect(receipt.journals, 2);
    expect(receipt.entries, 2);
    expect(receipt.revisions, 4); // one edit + Trash + Restore + another Trash
    expect(receipt.attachments, 1);
    final restored = JournalVault.open(
      destination().path + Platform.pathSeparator + StagedProductRestorer.databaseName,
      key: newDeviceKey);
    try {
      expect(restored.integrityCheck(), isTrue);
      final after = restored.snapshot();
      final original = source.snapshot();
      expect(after['journals'], original['journals']);
      expect(after['entries'], original['entries']);
      expect(after['revisions'], original['revisions']);
      expect(after['attachments'], original['attachments']);
      final originalPages = after['entries'] as List;
      expect(originalPages.any((e) => e['deletedAtMs'] != null), isTrue);
      final media = after['attachments'] as List;
      expect(media.single['name'], 'moment.png');
    } finally {
      restored.close();
    }
    final raw = File(destination().path + Platform.pathSeparator +
      StagedProductRestorer.databaseName).readAsBytesSync();
    expect(String.fromCharCodes(raw).contains('Imaginary bilingual diary'), isFalse);
    expect(String.fromCharCodes(raw).contains('My Journal'), isFalse);
  });

  test('restore works after original encrypted vault and key are lost', () async {
    source.close();
    File(sourcePath).deleteSync();
    originalKey.destroy();
    final result = await StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: destination(),
    );
    expect(result.entries, 2);
    final reopened = JournalVault.open(
      destination().path + Platform.pathSeparator + StagedProductRestorer.databaseName,
      key: newDeviceKey);
    try {
      expect(reopened.listEntries(includeTrash: true).length, 2);
    } finally {
      reopened.close();
    }
  });

  test('wrong recovery key rejects before any temporary files are created', () async {
    final wrong = RecoveryKey.random();
    try {
      await expectLater(StagedProductRestorer().restoreNew(
        encryptedArchive: archive, recoveryKey: wrong,
        destinationKey: newDeviceKey, destination: destination(),
      ), throwsA(isA<ArchiveRejected>()));
      await assertNoRestore(destination());
    } finally {
      wrong.destroy();
    }
  });

  test('tampered ciphertext rejected without a staged destination', () async {
    final edited = Uint8List.fromList(archive);
    edited[edited.length ~/ 2] ^= 1;
    await expectLater(StagedProductRestorer().restoreNew(
      encryptedArchive: edited, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: destination(),
    ), throwsA(isA<ArchiveRejected>()));
    await assertNoRestore(destination());
  });

  test('existing directory or file must not be replaced', () async {
    final dir = destination();
    dir.createSync();
    File(dir.path + Platform.pathSeparator + 'keep.txt').writeAsStringSync('unchanged');
    await expectLater(StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: dir,
    ), throwsA(isA<ProductRestoreRejected>()));
    expect(File(dir.path + Platform.pathSeparator + 'keep.txt')
      .readAsStringSync(), 'unchanged');
    final file = File(destination('occupied-file').path);
    file.writeAsStringSync('must stay intact');
    await expectLater(StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: destination('occupied-file'),
    ), throwsA(isA<ProductRestoreRejected>()));
    expect(file.readAsStringSync(), 'must stay intact');
  });

  test('faults at nine checkpoints discard all staged changes', () async {
    const faults = [
      'after_stage_created',
      'after_encrypted_database_created',
      'after_import_journal',
      'after_import_entry',
      'after_import_revision',
      'after_import_attachment',
      'before_import_commit',
      'after_commit_before_verify',
      'after_verify_before_promotion',
    ];
    for (var i = 0; i < faults.length; i++) {
      final failAt = faults[i];
      final target = destination('failed-$i');
      await expectLater(
        StagedProductRestorer(injectFailure: (checkpoint) {
          if (checkpoint == failAt) throw StateError('Injected fixture fault');
        }).restoreNew(
          encryptedArchive: archive, recoveryKey: recoveryKey,
          destinationKey: newDeviceKey, destination: target,
        ),
        throwsA(isA<ProductRestoreRejected>()),
      );
      await assertNoRestore(target);
    }
  });

  test('late target collision refuses replacement and preserves intruder file', () async {
    final target = destination('collided');
    await expectLater(
      StagedProductRestorer(injectFailure: (checkpoint) {
        if (checkpoint == 'after_verify_before_promotion') {
          target.createSync();
          File(target.path + Platform.pathSeparator + 'keep.txt')
            .writeAsStringSync('do not remove');
        }
      }).restoreNew(
        encryptedArchive: archive, recoveryKey: recoveryKey,
        destinationKey: newDeviceKey, destination: target,
      ),
      throwsA(isA<ProductRestoreRejected>()),
    );
    expect(File(target.path + Platform.pathSeparator + 'keep.txt')
      .readAsStringSync(), 'do not remove');
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
  });

  test('atomic publication exposes readiness only after verified restore', () async {
    final target = destination('ready-for-reader');
    expect(await NativeRestorePublisher.isReady(target), isFalse);
    final receipt = await StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: target,
    );
    expect(receipt.entries, 2);
    expect(await NativeRestorePublisher.isReady(target), isTrue);
    final marker = File(target.path + Platform.pathSeparator +
      NativeRestorePublisher.markerName);
    expect(await marker.readAsString(),
      NativeRestorePublisher.markerContents);
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
  });

  test('race at native no-replace boundary cannot overwrite another writer', () async {
    final target = destination('race-at-kernel-rename');
    final original = File(target.path);
    await expectLater(
      StagedProductRestorer(injectFailure: (checkpoint) {
        if (checkpoint == 'after_durable_stage_before_noreplace') {
          original.writeAsStringSync('preserve competing user data', flush: true);
        }
      }).restoreNew(
        encryptedArchive: archive, recoveryKey: recoveryKey,
        destinationKey: newDeviceKey, destination: target,
      ), throwsA(isA<ProductRestoreRejected>()),
    );
    expect(original.readAsStringSync(), 'preserve competing user data');
    expect(root.listSync().where((x) =>
      x.path.contains('.navin-journal-restore-')), isEmpty);
  });

  test('post-rename sync failure never auto-deletes a committed vault', () async {
    final target = destination('ambiguous-durable-commit');
    await expectLater(
      StagedProductRestorer(injectFailure: (checkpoint) {
        if (checkpoint == 'after_atomic_noreplace_rename') {
          throw StateError('simulated power loss before parent sync');
        }
      }).restoreNew(
        encryptedArchive: archive, recoveryKey: recoveryKey,
        destinationKey: newDeviceKey, destination: target,
      ), throwsA(isA<ProductRestoreRejected>()),
    );
    // After the no-clobber rename succeeded, cleanup MUST NOT delete it.
    // This marker alone is not sufficient: independently reopen + check crypto.
    expect(await NativeRestorePublisher.isReady(target), isTrue);
    final recovered = JournalVault.open(
      target.path + Platform.pathSeparator +
        StagedProductRestorer.databaseName, key: newDeviceKey);
    try {
      expect(recovered.integrityCheck(), isTrue);
      expect(recovered.snapshot()['entries'], source.snapshot()['entries']);
      expect(recovered.snapshot()['revisions'], source.snapshot()['revisions']);
    } finally {
      recovered.close();
    }
  });

  test('simultaneous restores never replace the first successful publication', () async {
    final target = destination('two-writers-same-name');
    final attempts = await Future.wait([
      for (var i = 0; i < 2; i++)
        StagedProductRestorer().restoreNew(
          encryptedArchive: archive, recoveryKey: recoveryKey,
          destinationKey: newDeviceKey, destination: target,
        ).then<Object>((result) => result,
          onError: (Object error, StackTrace _) => error),
    ]);
    expect(attempts.whereType<ProductRestoreReceipt>().length, 1);
    expect(attempts.whereType<ProductRestoreRejected>().length, 1);
    expect(await NativeRestorePublisher.isReady(target), isTrue);
    final recovered = JournalVault.open(
      target.path + Platform.pathSeparator +
      StagedProductRestorer.databaseName, key: newDeviceKey);
    try {
      expect(recovered.integrityCheck(), isTrue);
      expect(recovered.listEntries(includeTrash: true).length, 2);
    } finally {
      recovered.close();
    }
  });

  test('restored vault cannot be opened using the original vault key', () async {
    await StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDeviceKey, destination: destination(),
    );
    expect(() => JournalVault.open(
      destination().path + Platform.pathSeparator + StagedProductRestorer.databaseName,
      key: originalKey,
    ), throwsA(anyOf(isA<VaultUnlockFailed>(), isA<JournalUnavailable>())));
  });

  test('importIntoEmpty cannot merge or overwrite an existing encrypted entry', () async {
    final other = JournalVault.open(
      root.path + Platform.pathSeparator + 'nonempty.sqlite3',
      key: newDeviceKey, create: true,
    );
    try {
      final journal = other.createJournal('Already here');
      final id = other.createEntry(journalId: journal,
        title: 'Keep', body: 'Must not be overwritten');
      final snapshot = await ProductEncryptedArchiveCodec().verify(
        recoveryKey: recoveryKey, archive: archive);
      await expectLater(other.importIntoEmpty(snapshot),
        throwsA(isA<JournalUnavailable>()));
      expect(other.readEntry(id)!['body'], 'Must not be overwritten');
      expect(other.listEntries().length, 1);
    } finally {
      other.close();
    }
  });
}
