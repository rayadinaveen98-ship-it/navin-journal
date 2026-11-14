// APK02 authenticated inspection of fictional orphan stages. Never publish.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late Directory parent;
  late RecoveryKey offline;
  late TestVaultKey originalKey;
  late TestVaultKey stagedKey;
  late Uint8List ciphertext;
  late String name;
  late Directory stage;

  setUp(() async {
    parent = Directory.systemTemp.createTempSync('nj-assess-fictional-');
    offline = RecoveryKey.random();
    originalKey = TestVaultKey.random();
    stagedKey = TestVaultKey.random();
    final original = JournalVault.open(
      parent.path + '/source.sqlite3', key: originalKey, create: true);
    try {
      final journal = original.createJournal('Imagined mornings');
      final entry = original.createEntry(
        journalId: journal, title: 'Fictional page',
        body: 'Never a real personal diary · తెలుగు',
      );
      original.editEntry(
        id: entry, expectedVersion: 1, journalId: journal,
        eventAtMs: null, title: 'Fictional page revisited',
        body: 'The imaginary second revision',
      );
      await original.attachMedia(
        entryId: entry, filename: 'fictional-data.bin',
        mime: 'application/octet-stream',
        bytes: Uint8List.fromList([0, 1, 9, 255]),
      );
      ciphertext = await original.exportEncrypted(recoveryKey: offline);
    } finally {
      original.close();
    }
    name = NativeRestorePublisher.stagePrefix + 'candidateABC123';
    stage = Directory(parent.path + '/' + name);
  });

  tearDown(() {
    offline.destroy();
    originalKey.destroy();
    stagedKey.destroy();
    ciphertext.fillRange(0, ciphertext.length, 0);
    if (parent.existsSync()) parent.deleteSync(recursive: true);
  });

  Future<void> buildStage({bool marker = true, bool different = false}) async {
    stage.createSync();
    final db = JournalVault.open(stage.path + '/journal.sqlite3',
        key: stagedKey, create: true);
    try {
      final reference = await ProductEncryptedArchiveCodec().verify(
          recoveryKey: offline, archive: ciphertext);
      await db.importIntoEmpty(reference);
      if (different) db.createJournal('Unrelated fictional journal');
    } finally {
      db.close();
    }
    if (marker) {
      File(stage.path + '/' + NativeRestorePublisher.markerName)
          .writeAsStringSync(NativeRestorePublisher.markerContents, flush: true);
    }
  }

  Future<RestoreAssessment> assess({
    RecoveryKey? recovery,
    TestVaultKey? databaseKey,
    String? basename,
  }) => RestoreStagingAssessment.assess(
    privateParent: parent,
    candidateBasename: basename ?? name,
    encryptedArchive: ciphertext,
    recoveryKey: recovery ?? offline,
    stagedDatabaseKey: databaseKey ?? stagedKey,
  );

  test('authenticated match with marker stays quarantined and never publishes',
      () async {
    await buildStage();
    final before = <String, List<int>>{};
    for (final item in stage.listSync(followLinks: false)) {
      before[item.uri.pathSegments.where((s) => s.isNotEmpty).last] =
          File(item.path).readAsBytesSync();
    }
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.verifiedQuarantined);
    expect(report.publicationMarkerObserved, isTrue);
    expect(report.isAuthenticatedMatch, isTrue);
    expect(report.journalCount, 1);
    expect(report.entryCount, 1);
    expect(report.revisionCount, 1);
    expect(report.attachmentCount, 1);
    expect(stage.existsSync(), isTrue);
    for (final item in stage.listSync(followLinks: false)) {
      final base = item.uri.pathSegments.where((s) => s.isNotEmpty).last;
      expect(File(item.path).readAsBytesSync(), before[base],
          reason: 'assessment must not mutate the original stage');
    }
    expect(Directory(parent.path + '/published-vault').existsSync(), isFalse);
  });

  test('valid encrypted stage with NO marker is still not authorized to publish',
      () async {
    await buildStage(marker: false);
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.verifiedQuarantined);
    expect(report.publicationMarkerObserved, isFalse);
    expect(stage.existsSync(), isTrue);
    expect(File(stage.path + '/' + NativeRestorePublisher.markerName)
        .existsSync(), isFalse);
  });

  test('wrong database key gives no valid verdict and changes no source', () async {
    await buildStage();
    final wrong = TestVaultKey.random();
    try {
      final report = await assess(databaseKey: wrong);
      expect(report.status, RestoreAssessmentStatus.notVerified);
      expect(stage.existsSync(), isTrue);
      expect(File(stage.path + '/journal.sqlite3').existsSync(), isTrue);
    } finally {
      wrong.destroy();
    }
  });

  test('wrong recovery key fails before stage is inspected', () async {
    await buildStage();
    final wrong = RecoveryKey.random();
    try {
      final report = await assess(recovery: wrong);
      expect(report.status, RestoreAssessmentStatus.untrustedArchive);
      expect(report.isAuthenticatedMatch, isFalse);
      expect(stage.existsSync(), isTrue);
    } finally {
      wrong.destroy();
    }
  });

  test('valid encrypted but divergent journal never matches archive', () async {
    await buildStage(different: true);
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.notVerified);
    expect(report.journalCount, 0);
    expect(stage.existsSync(), isTrue);
  });

  test('forged marker and damaged sqlite file never justify recovery', () async {
    stage.createSync();
    File(stage.path + '/journal.sqlite3').writeAsBytesSync([1, 2, 3, 4]);
    File(stage.path + '/' + NativeRestorePublisher.markerName)
        .writeAsStringSync(NativeRestorePublisher.markerContents);
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.notVerified);
    expect(report.publicationMarkerObserved, isTrue);
    expect(stage.existsSync(), isTrue);
  });

  test('stage without encrypted database is incomplete not valid', () async {
    stage.createSync();
    File(stage.path + '/' + NativeRestorePublisher.markerName)
        .writeAsStringSync(NativeRestorePublisher.markerContents);
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.incomplete);
    expect(report.publicationMarkerObserved, isTrue);
  });

  test('candidate symlink to another directory is never followed', () async {
    final unrelated = Directory(parent.path + '/do-not-touch')
      ..createSync();
    File(unrelated.path + '/private-fictional.txt').writeAsStringSync('keep');
    Link(stage.path).createSync(unrelated.path);
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.blocked);
    expect(File(unrelated.path + '/private-fictional.txt').readAsStringSync(),
        'keep');
  });

  test('an unknown sidecar or symlink inside a stage blocks assessment',
      () async {
    await buildStage();
    final other = File(parent.path + '/outside-sentinel')..writeAsStringSync('x');
    Link(stage.path + '/journal.sqlite3-extra').createSync(other.path);
    expect((await assess()).status, RestoreAssessmentStatus.blocked);
    expect(other.readAsStringSync(), 'x');
  });

  test('overlarge stage blocked without reading or deleting', () async {
    stage.createSync();
    final tooLarge = File(stage.path + '/journal.sqlite3').openSync(
        mode: FileMode.write);
    try {
      tooLarge.truncateSync(RestoreStagingAssessment.maxStageBytes + 1);
    } finally {
      tooLarge.closeSync();
    }
    final report = await assess();
    expect(report.status, RestoreAssessmentStatus.blocked);
    expect(File(stage.path + '/journal.sqlite3').existsSync(), isTrue);
  });

  test('reject traversal, wrong prefix and missing stage path', () async {
    for (final candidate in [
      '../anything',
      'journal.sqlite3',
      NativeRestorePublisher.stagePrefix + '../outside',
      NativeRestorePublisher.stagePrefix + 'abc',
      'a/b',
    ]) {
      expect((await assess(basename: candidate)).status,
          RestoreAssessmentStatus.blocked);
    }
    expect((await assess(basename:
      NativeRestorePublisher.stagePrefix + 'missingABC123')).status,
        RestoreAssessmentStatus.blocked);
  });
}
