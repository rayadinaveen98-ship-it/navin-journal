// Stage 5A retained candidate — fictional encrypted fixtures only.
// The fake protector below is deliberately NOT cryptography or Android Keystore.
// It exercises alias/AAD custody semantics in Linux tests; Android requires
// FlutterAndroidKeyProtector and a separate hardware acceptance gate.
import 'dart:io';
import 'dart:typed_data';

import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
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

  test('exclusive filesystem reservation prevents simultaneous imports '
      'and preserves the verified winner', () async {
    final outcomes = await Future.wait(
      List<Future<bool>>.generate(2, (_) async {
        try {
          await FictionalRetainedRecoveryCandidate.prepare(
            encryptedArchive: Uint8List.fromList(archive),
            manuallyEnteredRecoveryKey: typedKey,
            trustedPrivateRoot: root,
            deviceProtector: fake,
          );
          return true;
        } on FictionalRetainedRecoveryRejected {
          return false;
        }
      }),
    );
    expect(outcomes.where((value) => value), hasLength(1));
    expect(outcomes.where((value) => !value), hasLength(1));
    expect(File('${root.path}/$candidateName.reservation').existsSync(),
      isTrue);
    final reopened = await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake,
    );
    expect(reopened.entries, 1);
    expect(await source.readEntry(entryId), initialPage);
  });

  test('orphaned exclusive reservation is not silently reset or reused',
      () async {
    File('${root.path}/$candidateName.reservation')
        .createSync(exclusive: true);
    await expectLater(FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: Uint8List.fromList(archive),
      manuallyEnteredRecoveryKey: typedKey,
      trustedPrivateRoot: root,
      deviceProtector: fake,
    ), throwsA(isA<FictionalRetainedRecoveryRejected>()));
    expect(Directory('${root.path}/$candidateName').existsSync(), isFalse);
    expect(File('${root.path}/$candidateName.reservation').existsSync(),
      isTrue);
    expect(await source.readEntry(entryId), initialPage);
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

  Future<void> prepareCandidate() =>
      FictionalRetainedRecoveryCandidate.prepare(
        encryptedArchive: Uint8List.fromList(archive),
        manuallyEnteredRecoveryKey: typedKey,
        trustedPrivateRoot: root,
        deviceProtector: fake,
      ).then((_) {});

  test('activation needs distinct explicit approval, leaves active slot absent',
      () async {
    await prepareCandidate();
    expect(await FictionalRecoveryActivator.inspect(
      trustedPrivateRoot: root),
      FictionalActivationState.awaitingExplicitApproval);
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: false,
    ), throwsA(isA<FictionalActivationRejected>()));
    expect(Directory('${root.path}/${FictionalRecoveryActivator.activeDirectoryName}')
      .existsSync(), isFalse);
    expect(File('${root.path}/${FictionalRecoveryActivator.activationReservationName}')
      .existsSync(), isFalse);
    expect((await FictionalRetainedRecoveryCandidate.reopen(
        trustedPrivateRoot: root, deviceProtector: fake)).entries, 1);
  });

  test('explicit approval moves verified encrypted DB AND bound envelope '
      'atomically, preserves source and independently reopens', () async {
    await prepareCandidate();
    final before = await source.readEntry(entryId);
    final src = Directory('${root.path}/$candidateName');
    final envelopeText = File('${src.path}/envelope.json').readAsStringSync();
    final receipt = await FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
    );
    expect(receipt.journals, 1);
    expect(receipt.entries, 1);
    expect(receipt.revisions, 1);
    expect(receipt.attachments, 0);
    expect(receipt.existingVaultReplaced, isFalse);
    expect(receipt.privateWritingApproved, isFalse);
    expect(receipt.deviceRecoveryCertified, isFalse);
    expect(src.existsSync(), isFalse);
    final active = Directory('${root.path}/${FictionalRecoveryActivator.activeDirectoryName}');
    expect(File('${active.path}/envelope.json').readAsStringSync(), envelopeText);
    expect(File('${active.path}/vault/journal.sqlite3').existsSync(), isTrue);
    expect(File('${root.path}/${FictionalRecoveryActivator.activationReservationName}')
      .existsSync(), isTrue);
    expect(await FictionalRecoveryActivator.inspect(trustedPrivateRoot: root),
      FictionalActivationState.activeFictionalVault);
    final reopened = await FictionalRecoveryActivator.reopenActivated(
      trustedPrivateRoot: root, deviceProtector: fake);
    expect(reopened.entries, 1);
    expect(reopened.revisions, 1);
    expect(await source.readEntry(entryId), before);
    expect(await source.integrityCheck(), isTrue);
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
    ), throwsA(isA<FictionalActivationRejected>()));
  });

  test('occupied active directory, file and symlink all reject without '
      'reserving activation or touching either encrypted journal', () async {
    await prepareCandidate();
    final activePath = '${root.path}/${FictionalRecoveryActivator.activeDirectoryName}';
    for (final kind in ['directory', 'file', 'link']) {
      if (kind == 'directory') {
        Directory(activePath).createSync();
        File('$activePath/do-not-touch').writeAsStringSync('existing journal');
      } else if (kind == 'file') {
        File(activePath).writeAsStringSync('foreign active vault');
      } else {
        Link(activePath).createSync(root.path);
      }
      await expectLater(FictionalRecoveryActivator.approveAndActivate(
        trustedPrivateRoot: root, deviceProtector: fake,
        userExplicitlyApproved: true,
      ), throwsA(isA<FictionalActivationRejected>()));
      expect(File('${root.path}/${FictionalRecoveryActivator.activationReservationName}')
        .existsSync(), isFalse);
      expect((await FictionalRetainedRecoveryCandidate.reopen(
        trustedPrivateRoot: root, deviceProtector: fake)).journals, 1);
      if (kind == 'directory') {
        expect(File('$activePath/do-not-touch').readAsStringSync(),
          'existing journal');
        Directory(activePath).deleteSync(recursive: true);
      } else if (kind == 'file') {
        expect(File(activePath).readAsStringSync(), 'foreign active vault');
        File(activePath).deleteSync();
      } else {
        Link(activePath).deleteSync();
      }
    }
    expect(await source.readEntry(entryId), initialPage);
  });

  test('two simultaneous approved activations choose exactly one '
      'no-replace winner with no partial journal', () async {
    await prepareCandidate();
    final outcomes = await Future.wait(List<Future<bool>>.generate(2, (_) async {
      try {
        await FictionalRecoveryActivator.approveAndActivate(
          trustedPrivateRoot: root, deviceProtector: fake,
          userExplicitlyApproved: true,
        );
        return true;
      } on FictionalActivationRejected {
        return false;
      }
    }));
    expect(outcomes.where((value) => value), hasLength(1));
    expect(outcomes.where((value) => !value), hasLength(1));
    expect((await FictionalRecoveryActivator.reopenActivated(
      trustedPrivateRoot: root, deviceProtector: fake)).entries, 1);
    expect(await source.integrityCheck(), isTrue);
  });

  test('interruption after activation lock leaves candidate quarantined, '
      'never auto-retries or deletes encrypted data', () async {
    await prepareCandidate();
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
      injectFailure: (checkpoint) {
        if (checkpoint == 'after_activation_reservation') {
          throw StateError('Crash after permanent approval reservation');
        }
      },
    ), throwsA(isA<FictionalActivationRejected>()));
    expect(Directory('${root.path}/$candidateName').existsSync(), isTrue);
    expect(Directory('${root.path}/${FictionalRecoveryActivator.activeDirectoryName}')
      .existsSync(), isFalse);
    expect(await FictionalRecoveryActivator.inspect(trustedPrivateRoot: root),
      FictionalActivationState.unsafeOrInterrupted);
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
    ), throwsA(isA<FictionalActivationRejected>()));
    expect((await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake)).entries, 1);
    expect(await source.readEntry(entryId), initialPage);
  });

  test('crash after approved marker but BEFORE rename retains candidate',
      () async {
    await prepareCandidate();
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
      injectFailure: (point) {
        if (point == 'after_activation_approval_marker') {
          throw StateError('Simulated native crash before no-replace rename');
        }
      },
    ), throwsA(isA<FictionalActivationRejected>()));
    final candidate = Directory('${root.path}/$candidateName');
    expect(candidate.existsSync(), isTrue);
    expect(File('${candidate.path}/${NativeRestorePublisher.fictionalActivationMarker}')
      .existsSync(), isTrue);
    expect(Directory('${root.path}/${FictionalRecoveryActivator.activeDirectoryName}')
      .existsSync(), isFalse);
    expect((await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root, deviceProtector: fake)).entries, 1);
    expect(await FictionalRecoveryActivator.inspect(trustedPrivateRoot: root),
      FictionalActivationState.unsafeOrInterrupted);
  });

  test('crash AFTER atomic no-replace rename remains independently '
      'recoverable but cannot be retried automatically', () async {
    await prepareCandidate();
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
      injectFailure: (point) {
        if (point == 'after_activation_atomic_rename') {
          throw StateError('Simulated failure after committed rename');
        }
      },
    ), throwsA(isA<FictionalActivationRejected>()));
    expect(await FictionalRecoveryActivator.inspect(trustedPrivateRoot: root),
      FictionalActivationState.activeFictionalVault);
    final reopened = await FictionalRecoveryActivator.reopenActivated(
      trustedPrivateRoot: root, deviceProtector: fake);
    expect(reopened.entries, 1);
    expect(reopened.revisions, 1);
    expect(await source.readEntry(entryId), initialPage);
    await expectLater(FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
    ), throwsA(isA<FictionalActivationRejected>()));
  });

  test('lost active wrapping key fails closed without erasing promoted vault',
      () async {
    await prepareCandidate();
    await FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root, deviceProtector: fake,
      userExplicitlyApproved: true,
    );
    final active = Directory(
      '${root.path}/${FictionalRecoveryActivator.activeDirectoryName}');
    final envelope = File('${active.path}/envelope.json');
    final document = await KeyEnvelopeCoordinator(
      envelopeFile: envelope, protector: fake).readEnvelope();
    final saved = envelope.readAsStringSync();
    await fake.retire(document.activeAlias);
    await expectLater(FictionalRecoveryActivator.reopenActivated(
      trustedPrivateRoot: root, deviceProtector: fake,
    ), throwsA(isA<FictionalActivationRejected>()));
    expect(envelope.readAsStringSync(), saved);
    expect(File('${active.path}/vault/journal.sqlite3').existsSync(), isTrue);
    expect(await source.readEntry(entryId), initialPage);
  });
}
