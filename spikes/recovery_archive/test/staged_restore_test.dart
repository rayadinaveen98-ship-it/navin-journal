import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:navin_journal_recovery_archive_spike/staged_restore.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late Directory destination;
  late RecoveryKey recoveryKey;
  late TestVaultKey destinationKey;
  late RecoveryArchiveCodec codec;

  const entries = [
    PortableEntry(
      id: 'test-a',
      title: 'నిన్నటి జ్ఞాపకం 🪷',
      body: 'Fictional first entry · తెలుగు + English and emoji 🎬',
    ),
    PortableEntry(
      id: 'test-b',
      title: 'Another fictional day',
      body: 'FICTIONAL_RESTORED_SENTINEL_PRIVATE_NOT_REAL',
    ),
  ];

  PortableAttachment image() => PortableAttachment(
        id: 'media-a',
        name: 'lotus-sample.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );

  Future<Uint8List> archive({
    List<PortableEntry> content = entries,
    List<PortableAttachment>? files,
  }) =>
      codec.export(
        key: recoveryKey,
        entries: content,
        attachments: files ?? [image()],
        createdAtUtc: DateTime.utc(2026, 11, 13),
      );

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('nj_a4_2_restore_');
    destination = Directory(
        sandbox.path + Platform.pathSeparator + 'a-different-device-vault');
    recoveryKey = RecoveryKey.random();
    destinationKey = TestVaultKey.random();
    codec = RecoveryArchiveCodec();
  });

  tearDown(() {
    recoveryKey.destroy();
    destinationKey.destroy();
    sandbox.deleteSync(recursive: true);
  });

  Future<void> assertNoStageOrDestination() async {
    expect(destination.existsSync(), isFalse);
    expect(
      sandbox.listSync().where((f) => f.path.contains('.nj-restore-stage-')),
      isEmpty,
    );
  }

  test('clean destination receives exact independently encrypted entries and media',
      () async {
    final encrypted = await archive();
    final keyExport = recoveryKey.exportForOfflineStorage();
    final carriedKey = RecoveryKey.parse(keyExport);
    try {
      final receipt = await StagedRecoveryRestorer().restoreNew(
        encryptedArchive: encrypted,
        recoveryKey: carriedKey,
        destinationKey: destinationKey,
        destination: destination,
      );
      expect(receipt.directory, destination.path);
      expect(receipt.entries, 2);
      expect(receipt.attachments, 1);
    } finally {
      carriedKey.destroy();
    }
    final vault = RestoredTestVault.open(destination.path, key: destinationKey);
    try {
      expect(vault.integrityCheck(), isTrue);
      expect(vault.readEntries(), entries);
      final media = vault.readAttachments().single;
      expect(media.id, 'media-a');
      expect(media.name, 'lotus-sample.png');
      expect(media.mimeType, 'image/png');
      expect(media.bytes, image().bytes);
      expect(vault.readHashes()['media-a'], isNotEmpty);
    } finally {
      vault.close();
    }
    expect(
      sandbox.listSync().where((f) => f.path.contains('.nj-restore-stage-')),
      isEmpty,
    );
  });

  test('encrypted database bytes contain no fictional entry or media filename',
      () async {
    await StagedRecoveryRestorer().restoreNew(
      encryptedArchive: await archive(),
      recoveryKey: recoveryKey,
      destinationKey: destinationKey,
      destination: destination,
    );
    final db = File(destination.path + Platform.pathSeparator +
        RestoredTestVault.databaseName);
    final bytes = db.readAsBytesSync();
    for (final sentinel in [
      'FICTIONAL_RESTORED_SENTINEL_PRIVATE_NOT_REAL',
      'lotus-sample.png',
      'Another fictional day',
    ]) {
      expect(_contains(bytes, utf8.encode(sentinel)), isFalse);
    }
    expect(bytes.take(16).toList(), isNot(utf8.encode('SQLite format 3\u0000')));
  });

  test('wrong password-equivalent recovery key rejects before any disk staging',
      () async {
    final wrong = RecoveryKey.random();
    try {
      await expectLater(
        StagedRecoveryRestorer().restoreNew(
          encryptedArchive: await archive(),
          recoveryKey: wrong,
          destinationKey: destinationKey,
          destination: destination,
        ),
        throwsA(isA<ArchiveRejected>()),
      );
      await assertNoStageOrDestination();
    } finally {
      wrong.destroy();
    }
  });

  test('tampered archive rejects without a destination or staging files',
      () async {
    final encrypted = await archive();
    final container = jsonDecode(utf8.decode(encrypted)) as Map;
    final tag = base64Decode(container['tag'] as String);
    tag[0] ^= 1;
    container['tag'] = base64Encode(tag);
    await expectLater(
      StagedRecoveryRestorer().restoreNew(
        encryptedArchive: Uint8List.fromList(utf8.encode(jsonEncode(container))),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<ArchiveRejected>()),
    );
    await assertNoStageOrDestination();
  });

  test('existing destination cannot be overwritten or even opened', () async {
    destination.createSync();
    final protected = File(destination.path + Platform.pathSeparator + 'keep.txt');
    protected.writeAsStringSync('existing data must remain intact');
    await expectLater(
      StagedRecoveryRestorer().restoreNew(
        encryptedArchive: await archive(),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<RestoreRejected>()),
    );
    expect(protected.readAsStringSync(), 'existing data must remain intact');
    expect(destination.listSync(), hasLength(1));
  });

  test('an ordinary file at destination prevents restore', () async {
    final present = File(destination.path);
    present.writeAsStringSync('untouched');
    await expectLater(
      StagedRecoveryRestorer().restoreNew(
        encryptedArchive: await archive(),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<RestoreRejected>()),
    );
    expect(present.readAsStringSync(), 'untouched');
  });

  for (final checkpoint in [
    'after_stage_created',
    'after_encrypted_database_created',
    'after_entry',
    'after_attachment',
    'before_commit',
    'after_commit_before_verify',
    'after_verify_before_promotion',
  ]) {
    test('injected $checkpoint failure cleans up all staged files', () async {
      var reached = false;
      await expectLater(
        StagedRecoveryRestorer(injectFailure: (location) {
          if (location == checkpoint) {
            reached = true;
            throw StateError('Simulated restore failure');
          }
        }).restoreNew(
          encryptedArchive: await archive(),
          recoveryKey: recoveryKey,
          destinationKey: destinationKey,
          destination: destination,
        ),
        throwsA(isA<RestoreRejected>()),
      );
      expect(reached, isTrue);
      await assertNoStageOrDestination();
    });
  }

  test('late destination collision rejects without erasing other data',
      () async {
    final marker = File(destination.path + Platform.pathSeparator + 'original');
    await expectLater(
      StagedRecoveryRestorer(injectFailure: (phase) {
        if (phase == 'after_verify_before_promotion') {
          destination.createSync();
          marker.writeAsStringSync('never erase this user data');
        }
      }).restoreNew(
        encryptedArchive: await archive(),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<RestoreRejected>()),
    );
    expect(marker.readAsStringSync(), 'never erase this user data');
    expect(
      sandbox.listSync().where((f) => f.path.contains('.nj-restore-stage-')),
      isEmpty,
    );
  });

  test('restored vault cannot be read with a mismatched encryption key',
      () async {
    await StagedRecoveryRestorer().restoreNew(
      encryptedArchive: await archive(),
      recoveryKey: recoveryKey,
      destinationKey: destinationKey,
      destination: destination,
    );
    final wrong = TestVaultKey.random();
    try {
      expect(
        () => RestoredTestVault.open(destination.path, key: wrong),
        throwsA(isA<RestoreRejected>()),
      );
    } finally {
      wrong.destroy();
    }
    final correct =
        RestoredTestVault.open(destination.path, key: destinationKey);
    try {
      expect(correct.readEntries(), entries);
    } finally {
      correct.close();
    }
  });

  test('empty verified archive restores to an empty encrypted vault',
      () async {
    final empty = await archive(content: [], files: []);
    final receipt = await StagedRecoveryRestorer().restoreNew(
      encryptedArchive: empty,
      recoveryKey: recoveryKey,
      destinationKey: destinationKey,
      destination: destination,
    );
    expect(receipt.entries, 0);
    expect(receipt.attachments, 0);
    final vault = RestoredTestVault.open(destination.path, key: destinationKey);
    try {
      expect(vault.readEntries(), isEmpty);
      expect(vault.readAttachments(), isEmpty);
      expect(vault.integrityCheck(), isTrue);
    } finally {
      vault.close();
    }
  });

  test('missing parent rejects before creating any destination directory',
      () async {
    destination = Directory(sandbox.path + '/missing/fresh');
    await expectLater(
      StagedRecoveryRestorer().restoreNew(
        encryptedArchive: await archive(),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<RestoreRejected>()),
    );
    expect(Directory(sandbox.path + '/missing').existsSync(), isFalse);
  });

  test('wrong archive version rejects without touching an existing vault',
      () async {
    destination.createSync();
    final protected = File(destination.path + '/original.txt')
      ..writeAsStringSync('my original data');
    final json = jsonDecode(utf8.decode(await archive())) as Map;
    json['format'] = 'NJR-RECOVERY-99';
    await expectLater(
      StagedRecoveryRestorer().restoreNew(
        encryptedArchive: Uint8List.fromList(utf8.encode(jsonEncode(json))),
        recoveryKey: recoveryKey,
        destinationKey: destinationKey,
        destination: destination,
      ),
      throwsA(isA<ArchiveRejected>()),
    );
    expect(protected.readAsStringSync(), 'my original data');
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var same = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        same = false;
        break;
      }
    }
    if (same) return true;
  }
  return false;
}
