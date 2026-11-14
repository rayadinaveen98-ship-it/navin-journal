// Stage 5A retained candidate — fictional encrypted fixtures only.
// The fake protector below is deliberately NOT cryptography or Android Keystore.
// It exercises alias/AAD custody semantics in Linux tests; Android requires
// FlutterAndroidKeyProtector and a separate hardware acceptance gate.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

class InsecureFakeDeviceProtector implements DeviceKeyProtector {
  final Map<String, Uint8List> _keys = {};
  final Map<String, Uint8List> _aad = {};

  @override
  Future<void> provision(String alias) async {
    if (_keys.containsKey(alias)) throw StateError('Alias collision');
    _keys[alias] = Uint8List(32);
  }

  @override
  Future<WrappedSecret> wrap(String alias, Uint8List dek, Uint8List aad) async {
    if (!_keys.containsKey(alias) || dek.length != 32 || aad.isEmpty) {
      throw StateError('Unknown alias');
    }
    _keys[alias] = Uint8List.fromList(dek);
    _aad[alias] = Uint8List.fromList(aad);
    // FICTITIOUS: holds plaintext in RAM, no encryption. Test-only provider.
    return WrappedSecret(List<int>.filled(12, 0), dek.toList(),
      List<int>.filled(16, 1));
  }

  @override
  Future<Uint8List> unwrap(
      String alias, WrappedSecret wrapped, Uint8List aad) async {
    final previous = _keys[alias];
    final context = _aad[alias];
    if (previous == null || context == null ||
        !_equal(aad, context) ||
        !_equal(Uint8List.fromList(wrapped.ciphertext), previous) ||
        wrapped.nonce.length != 12 || wrapped.tag.length != 16) {
      throw const MissingVaultKey('Test envelope mismatch');
    }
    return Uint8List.fromList(previous);
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var unequal = 0;
    for (var i = 0; i < a.length; i++) {
      unequal |= a[i] ^ b[i];
    }
    return unequal == 0;
  }

  @override
  Future<void> retire(String alias) async {
    final key = _keys.remove(alias);
    final context = _aad.remove(alias);
    key?.fillRange(0, key.length, 0);
    context?.fillRange(0, context.length, 0);
  }
}

void main() {
  late Directory root;
  late JournalEditorWorker source;
  late TestVaultKey originalDatabaseKey;
  late InsecureFakeDeviceProtector fake;
  late Uint8List archive;
  late String typedKey;
  late String entryId;
  late Map<String, Object?> initialPage;

  final candidateName =
      FictionalRetainedRecoveryCandidate.candidateDirectoryName;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-stage5a-fixture-');
    fake = InsecureFakeDeviceProtector();
    originalDatabaseKey = TestVaultKey.random();
    source = await JournalEditorWorker.open(
      '${root.path}/original.sqlite3',
      key: originalDatabaseKey, create: true,
    );
    final journal = await source.createJournal('Fictional Telugu memory');
    final session = await source.startSession(journalId: journal);
    session.controller.update(title: 'Imaginary story v1',
      body: 'తెలుగు కల్పితం 🌿 v1');
    await session.save();
    expect(session.indicator.phase, SavePhase.saved);
    entryId = (await session.persistedEntryId())!;
    session.controller.update(title: 'Imaginary story v2',
      body: 'తెలుగు కల్పితం 🌿 v2');
    await session.save();
    expect(await session.closeSafely(), isTrue);
    initialPage = (await source.readEntry(entryId))!;
    final recovery = RecoveryKey.random();
    try {
      typedKey = recovery.exportForOfflineStorage();
      archive = await source.exportRecoveryArchive(recovery);
    } finally {
      recovery.destroy();
    }
  });

  tearDown(() async {
    await source.close();
    originalDatabaseKey.destroy();
    archive.fillRange(0, archive.length, 0);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('new candidate is retained with device envelope and independently '
      'reopens without recovery archive, original key or manual key', () async {
    final input = Uint8List.fromList(archive);
    final prepared = await FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: input,
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    );
    expect(prepared.journals, 1);
    expect(prepared.entries, 1);
    expect(prepared.revisions, 1);
    expect(prepared.attachments, 0);
    expect(prepared.activeJournalReplaced, isFalse);
    expect(prepared.activatedForPersonalWriting, isFalse);
    expect(prepared.physicalDeviceRecoveryVerified, isFalse);
    expect(input.every((b) => b == 0), isTrue);
    final candidate = Directory('${root.path}/$candidateName');
    expect(File('${candidate.path}/vault/journal.sqlite3').existsSync(),
      isTrue);
    final envelope = File('${candidate.path}/envelope.json');
    expect(envelope.existsSync(), isTrue);
    expect(envelope.readAsStringSync(), isNot(contains('Imaginary story')));
    expect(envelope.readAsStringSync(), isNot(contains(typedKey)));
    expect(await source.readEntry(entryId), initialPage);

    // "Fresh process" uses only the retained encrypted files and the same
    // provisioned device wrapping identity; archive + secret are absent.
    final restarted = await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake,
    );
    expect(restarted.entries, 1);
    expect(restarted.revisions, 1);
    expect(restarted.activatedForPersonalWriting, isFalse);
    expect(await source.integrityCheck(), isTrue);
  });

  test('replay refuses to overwrite an already retained candidate', () async {
    await FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    );
    final candidate = File(
      '${root.path}/$candidateName/vault/journal.sqlite3');
    final originalSize = candidate.lengthSync();
    final originalEnvelope = File(
      '${root.path}/$candidateName/envelope.json').readAsStringSync();
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(candidate.lengthSync(), originalSize);
    expect(File('${root.path}/$candidateName/envelope.json').readAsStringSync(),
      originalEnvelope);
    expect((await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake)).entries, 1);
  });

  test('wrong key and damaged ciphertext do not reserve a candidate', () async {
    final wrong = RecoveryKey.random();
    final falseKey = wrong.exportForOfflineStorage();
    wrong.destroy();
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: falseKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(Directory('${root.path}/$candidateName').existsSync(), isFalse);

    final corrupted = Uint8List.fromList(archive);
    corrupted[corrupted.length ~/ 2] ^= 4;
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: corrupted,
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(Directory('${root.path}/$candidateName').existsSync(), isFalse);
    expect(corrupted.every((b) => b == 0), isTrue);
    expect(await source.readEntry(entryId), initialPage);
  });

  test('interrupted candidate is quarantined and never auto-reset', () async {
    final unknown = Directory('${root.path}/unknown-restore-stage')
      ..createSync();
    File('${unknown.path}/keep').writeAsStringSync('DO NOT DELETE');
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
      injectFailure: (checkpoint) {
        if (checkpoint == 'after_new_device_envelope') {
          throw StateError('Simulated crash before encrypted publication');
        }
      },
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    final reserved = Directory('${root.path}/$candidateName');
    expect(reserved.existsSync(), isTrue);
    expect(File('${reserved.path}/envelope.json').existsSync(), isTrue);
    expect(Directory('${reserved.path}/vault').existsSync(), isFalse);
    await expectLater(FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(File('${unknown.path}/keep').readAsStringSync(), 'DO NOT DELETE');
    expect(await source.readEntry(entryId), initialPage);
  });

  test('destroyed/missing Keystore alias fails closed without data reset',
      () async {
    await FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    );
    final envelope = File('${root.path}/$candidateName/envelope.json');
    final raw = envelope.readAsStringSync();
    final document = await KeyEnvelopeCoordinator(
      envelopeFile: envelope, protector: fake).readEnvelope();
    await fake.retire(document.activeAlias);
    await expectLater(FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(envelope.readAsStringSync(), raw);
    expect(Directory('${root.path}/$candidateName/vault').existsSync(),
      isTrue);
    expect(await source.integrityCheck(), isTrue);
  });
}
