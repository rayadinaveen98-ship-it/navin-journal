// Real Linux SIGKILL and simulated ENOSPC tests, all fictional data only.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late TestVaultKey sourceKey;
  late TestVaultKey newDatabaseKey;
  late RecoveryKey recoveryKey;
  late Uint8List archive;
  late String savedId;
  late String originalDbPath;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-kill-restore-fictional-');
    originalDbPath =
        root.path + Platform.pathSeparator + 'original-encrypted.sqlite3';
    sourceKey = TestVaultKey.random();
    newDatabaseKey = TestVaultKey.random();
    recoveryKey = RecoveryKey.random();
    final original = JournalVault.open(
      originalDbPath, key: sourceKey, create: true,
    );
    try {
      final journal = original.createJournal('Fictional memory album');
      savedId = original.createEntry(
        journalId: journal,
        title: 'An invented morning',
        body: 'A made-up entry. తెలుగు. 🍃',
      );
      original.editEntry(
        id: savedId, expectedVersion: 1,
        journalId: journal, eventAtMs: null,
        title: 'An invented morning, revisited',
        body: 'An imaginary later chapter. 🌷',
      );
      await original.attachMedia(
        entryId: savedId, filename: 'fictional.bin',
        mime: 'application/octet-stream',
        bytes: Uint8List.fromList([7, 9, 11, 13, 0, 255]),
      );
      archive = await original.exportEncrypted(recoveryKey: recoveryKey);
    } finally {
      original.close();
    }
  });

  tearDown(() async {
    sourceKey.destroy();
    newDatabaseKey.destroy();
    recoveryKey.destroy();
    archive.fillRange(0, archive.length, 0);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Directory destination(String name) =>
      Directory(root.path + Platform.pathSeparator + name);

  Future<void> assertUnpublished(Directory target) async {
    expect(await FileSystemEntity.type(target.path, followLinks: false),
        FileSystemEntityType.notFound);
    expect(await NativeRestorePublisher.isReady(target), isFalse);
    expect(File(originalDbPath).existsSync(), isTrue);
  }

  test('simulated ENOSPC before promotion rejects and cleans owned stages',
      () async {
    const beforePublication = [
      'after_stage_created',
      'after_import_attachment',
      'after_commit_before_verify',
      'after_verify_before_promotion',
      'before_ready_marker_write',
      'after_ready_marker_write',
      'before_staged_file_fsync',
      'before_staging_dir_fsync',
      'before_parent_pre_rename_fsync',
      'after_durable_stage_before_noreplace',
    ];
    for (var i = 0; i < beforePublication.length; i++) {
      final failurePoint = beforePublication[i];
      final target = destination('disk-full-before-$i');
      var reached = false;
      await expectLater(
        StagedProductRestorer(injectFailure: (point) {
          if (point == failurePoint) {
            reached = true;
            throw FileSystemException(
              'Simulated ENOSPC; no physical disk has been filled',
              target.path,
              const OSError('No space left on device', 28),
            );
          }
        }).restoreNew(
          encryptedArchive: archive,
          recoveryKey: recoveryKey,
          destinationKey: newDatabaseKey,
          destination: target,
        ),
        throwsA(isA<ProductRestoreRejected>()),
        reason: failurePoint,
      );
      expect(reached, isTrue, reason: failurePoint);
      await assertUnpublished(target);
      expect(await RestoreStagingInventory.inspect(root), isEmpty,
          reason: failurePoint);
    }
    final good = destination('after-space-restored');
    final receipt = await StagedProductRestorer().restoreNew(
      encryptedArchive: archive, recoveryKey: recoveryKey,
      destinationKey: newDatabaseKey, destination: good,
    );
    expect(receipt.entries, 1);
    expect(await NativeRestorePublisher.isReady(good), isTrue);
  });

  test('simulated ENOSPC after no-replace preserves ambiguously committed vault',
      () async {
    final target = destination('disk-full-after-rename');
    var reached = false;
    await expectLater(
      StagedProductRestorer(injectFailure: (point) {
        if (point == 'before_parent_post_rename_fsync') {
          reached = true;
          throw FileSystemException(
            'Simulated disk full after rename',
            target.path,
            const OSError('No space left on device', 28),
          );
        }
      }).restoreNew(
        encryptedArchive: archive, recoveryKey: recoveryKey,
        destinationKey: newDatabaseKey, destination: target,
      ),
      throwsA(isA<ProductRestoreRejected>()),
    );
    expect(reached, isTrue);
    expect(await NativeRestorePublisher.isReady(target), isTrue);
    final recovered = JournalVault.open(
      target.path + Platform.pathSeparator +
          StagedProductRestorer.databaseName,
      key: newDatabaseKey,
    );
    try {
      expect(recovered.integrityCheck(), isTrue);
      expect(recovered.readEntry(savedId)!['version'], 2);
      expect(recovered.listRevisions(savedId), hasLength(1));
      expect(recovered.snapshot()['attachments'], hasLength(1));
    } finally {
      recovered.close();
    }
    expect(await RestoreStagingInventory.inspect(root), isEmpty);
  });

  test('orphan inventory is read-only and never trusts copied marker or links',
      () async {
    final partial = Directory(root.path + Platform.pathSeparator +
        NativeRestorePublisher.stagePrefix + 'partial');
    partial.createSync();
    File(partial.path + '/journal.sqlite3').writeAsBytesSync([3, 5, 7]);

    final forged = Directory(root.path + Platform.pathSeparator +
        NativeRestorePublisher.stagePrefix + 'forged');
    forged.createSync();
    File(forged.path + '/journal.sqlite3').writeAsBytesSync([1, 2, 3]);
    File(forged.path + '/' + NativeRestorePublisher.markerName)
        .writeAsStringSync(NativeRestorePublisher.markerContents);

    final suspicious = File(root.path + Platform.pathSeparator +
        NativeRestorePublisher.stagePrefix + 'a-file');
    suspicious.writeAsStringSync('do not delete');
    final symlink = Link(root.path + Platform.pathSeparator +
        NativeRestorePublisher.stagePrefix + 'a-symlink');
    symlink.createSync(forged.path);

    final items = await RestoreStagingInventory.inspect(root);
    expect(items, hasLength(4));
    expect(items.where((v) => v.kind ==
        StagingObservationKind.suspiciousNonDirectory), hasLength(2));
    final observedPartial = items.singleWhere(
      (v) => v.path == partial.path);
    expect(observedPartial.encryptedDatabaseObserved, isTrue);
    expect(observedPartial.publicationMarkerObserved, isFalse);
    final observedForged = items.singleWhere(
      (v) => v.path == forged.path);
    expect(observedForged.potentiallyCompleteButUnverified, isTrue);

    // Listing is NOT proof of integrity or permission to remove content.
    expect(suspicious.readAsStringSync(), 'do not delete');
    expect(symlink.existsSync(), isTrue);
    expect(File(forged.path + '/journal.sqlite3').existsSync(), isTrue);
    expect(File(partial.path + '/journal.sqlite3').existsSync(), isTrue);
  });

  test('orphan inventory refuses to claim completeness when over safety cap',
      () async {
    for (var i = 0; i <= RestoreStagingInventory.maxCandidates; i++) {
      Directory(root.path + Platform.pathSeparator +
          NativeRestorePublisher.stagePrefix + 'overflow-$i').createSync();
    }
    await expectLater(
      RestoreStagingInventory.inspect(root),
      throwsA(isA<StagingInventoryLimitExceeded>()),
    );
    expect(Directory(root.path + Platform.pathSeparator +
        NativeRestorePublisher.stagePrefix + 'overflow-0').existsSync(),
        isTrue);
  });

  test('real child SIGKILL leaves partial restore quarantined or preserves '
      'published encrypted revision', () async {
    if (!Platform.isLinux) return;
    const killPoints = [
      'after_stage_created',
      'after_commit_before_verify',
      'after_ready_marker_write',
      'after_atomic_noreplace_rename',
    ];

    for (var i = 0; i < killPoints.length; i++) {
      final checkpoint = killPoints[i];
      final target = destination('killed-$i');
      final input = File(root.path + Platform.pathSeparator +
          'sigkill-input-$i.json');
      input.writeAsStringSync(jsonEncode({
        'archiveBase64': base64Encode(archive),
        'recoveryKey': recoveryKey.exportForOfflineStorage(),
        'databaseKeyHex': newDatabaseKey.hex,
        'targetDirectory': target.path,
      }), flush: true);
      final helper = File(Directory.current.path + Platform.pathSeparator +
          'test/fixtures/restore_sigkill_child.dart');
      expect(helper.existsSync(), isTrue);
      final process = await Process.start(
        Platform.resolvedExecutable,
        [helper.path, input.path, checkpoint],
        workingDirectory: Directory.current.path,
        runInShell: false,
      );
      final code = await process.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          throw StateError('Restore fixture timed out at $checkpoint');
        },
      );
      expect(code, -ProcessSignal.sigkill.signalNumber,
          reason: 'must be a real OS-level SIGKILL: $checkpoint');
      expect(File(input.path + '.witness').readAsStringSync(),
          checkpoint);

      final orphans = await RestoreStagingInventory.inspect(root);
      if (checkpoint == 'after_atomic_noreplace_rename') {
        // The kernel already published: cleanup MUST preserve this target.
        expect(orphans, isEmpty);
        expect(await NativeRestorePublisher.isReady(target), isTrue);
        final recovered = JournalVault.open(
          target.path + Platform.pathSeparator +
              StagedProductRestorer.databaseName,
          key: newDatabaseKey,
        );
        try {
          expect(recovered.integrityCheck(), isTrue);
          expect(recovered.readEntry(savedId)!['version'], 2);
          expect(recovered.snapshot()['attachments'], hasLength(1));
          expect(recovered.listRevisions(savedId), hasLength(1));
        } finally {
          recovered.close();
        }
      } else {
        await assertUnpublished(target);
        expect(orphans, hasLength(1), reason: checkpoint);
        if (checkpoint == 'after_ready_marker_write') {
          expect(orphans.single.potentiallyCompleteButUnverified, isTrue);
        } else {
          expect(orphans.single.publicationMarkerObserved, isFalse);
        }
        // Deliberately NO auto-delete: an interrupted stage is quarantined.
        final stillThere = Directory(orphans.single.path);
        expect(stillThere.existsSync(), isTrue);
        stillThere.deleteSync(recursive: true); // disposable test fixture only
      }
      input.deleteSync();
      File(input.path + '.witness').deleteSync();
    }
    expect(await RestoreStagingInventory.inspect(root), isEmpty);
  });
}
