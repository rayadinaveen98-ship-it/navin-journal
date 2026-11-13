import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:test/test.dart';

/// Software-only test double. Its keys live in RAM; NOT Android Keystore!
class FakeDeviceKeystore implements DeviceKeyProtector {
  final _aes = AesGcm.with256bits();
  final Map<String, SecretKey> _keys = {};
  final Set<String> retiredAliases = {};

  @override
  Future<void> provision(String alias) async {
    if (_keys.containsKey(alias)) throw StateError('Alias already exists');
    _keys[alias] = await _aes.newSecretKey();
  }

  @override
  Future<WrappedSecret> wrap(
      String alias, Uint8List dataKey, Uint8List aad) async {
    final kek = _keys[alias];
    if (kek == null) throw StateError('Missing test key');
    final box = await _aes.encrypt(dataKey, secretKey: kek, aad: aad);
    return WrappedSecret(box.nonce, box.cipherText, box.mac.bytes);
  }

  @override
  Future<Uint8List> unwrap(
      String alias, WrappedSecret wrapped, Uint8List aad) async {
    final kek = _keys[alias];
    if (kek == null) throw StateError('Missing test key');
    final box = SecretBox(wrapped.ciphertext,
        nonce: wrapped.nonce, mac: Mac(wrapped.tag));
    final result = await _aes.decrypt(box, secretKey: kek, aad: aad);
    return Uint8List.fromList(result);
  }

  @override
  Future<void> retire(String alias) async {
    if (!_keys.containsKey(alias)) throw StateError('Missing alias');
    _keys.remove(alias);
    retiredAliases.add(alias);
  }

  bool contains(String alias) => _keys.containsKey(alias);
}

void main() {
  late Directory directory;
  late String databasePath;
  late File envelopeFile;
  late FakeDeviceKeystore fake;
  late KeyEnvelopeCoordinator coordinator;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('nj_keys_');
    databasePath =
        directory.path + Platform.pathSeparator + 'fictional-vault.db';
    envelopeFile = File(
        directory.path + Platform.pathSeparator + 'fictional-envelope.json');
    fake = FakeDeviceKeystore();
    coordinator =
        KeyEnvelopeCoordinator(envelopeFile: envelopeFile, protector: fake);
  });

  tearDown(() {
    directory.deleteSync(recursive: true);
  });

  Future<void> createEncryptedDatabase() async {
    final raw = await coordinator.initialize(databasePath: databasePath);
    final material = TestVaultKey.fromBytes(raw);
    raw.fillRange(0, raw.length, 0);
    final db = EncryptedJournalSpike.open(databasePath,
        key: material, create: true);
    db.insertFictionalEntry(
      id: 'fictional-entry',
      title: 'నా జ్ఞాపకం — a test memory',
      body: 'ఈ రోజు శాంతంగా ఉంది. A peaceful example. 🌿',
    );
    db.close();
    material.destroy();
  }

  Future<String> openFictionalEntry() async {
    final raw = await coordinator.unlock(databasePath: databasePath);
    final material = TestVaultKey.fromBytes(raw);
    raw.fillRange(0, raw.length, 0);
    final db = EncryptedJournalSpike.open(databasePath, key: material);
    try {
      expect(db.integrityCheck(), isTrue);
      return db.entryBody('fictional-entry')!;
    } finally {
      db.close();
      material.destroy();
    }
  }

  const fictionalText = 'ఈ రోజు శాంతంగా ఉంది. A peaceful example. 🌿';

  test('new vault has one authenticated wrapped slot, no raw key in JSON',
      () async {
    await createEncryptedDatabase();
    final envelope = await coordinator.readEnvelope();
    expect(envelope.slots, hasLength(1));
    expect(envelope.activeAlias, envelope.slots.single.alias);
    expect(envelope.generation, 1);
    expect(await openFictionalEntry(), fictionalText);
    final content = await envelopeFile.readAsString();
    expect(content, contains('ciphertext'));
    expect(content, contains('nonce'));
    expect(content, isNot(contains('A peaceful example')));
    expect(File(databasePath).existsSync(), isTrue);
  });

  test('restart with original provider can unwrap same encrypted vault',
      () async {
    await createEncryptedDatabase();
    final reopened = KeyEnvelopeCoordinator(
        envelopeFile: envelopeFile, protector: fake);
    final raw = await reopened.unlock(databasePath: databasePath);
    final key = TestVaultKey.fromBytes(raw);
    raw.fillRange(0, raw.length, 0);
    final db = EncryptedJournalSpike.open(databasePath, key: key);
    expect(db.entryBody('fictional-entry'), fictionalText);
    db.close();
    key.destroy();
  });

  test('wrapping-key rotation retains DB key, revisions and a safe old slot',
      () async {
    await createEncryptedDatabase();
    final before = await coordinator.readEnvelope();
    final first = before.activeAlias;
    await coordinator.rotateWrappingKey(databasePath: databasePath);
    final staged = await coordinator.readEnvelope();
    expect(staged.slots, hasLength(2));
    expect(staged.generation, 2);
    expect(staged.activeAlias, isNot(first));
    expect(fake.contains(first), isTrue);
    expect(await openFictionalEntry(), fictionalText);
  });

  test('finalize removes old slot before retiring old alias', () async {
    await createEncryptedDatabase();
    final first = (await coordinator.readEnvelope()).activeAlias;
    await coordinator.rotateWrappingKey(databasePath: databasePath);
    await coordinator.finalizeRotation(databasePath: databasePath);
    expect((await coordinator.readEnvelope()).slots, hasLength(1));
    expect(fake.contains(first), isFalse);
    expect(fake.retiredAliases, contains(first));
    expect(await openFictionalEntry(), fictionalText);
  });

  test('failure after stage leaves old key active; resume and finalize work',
      () async {
    await createEncryptedDatabase();
    final first = (await coordinator.readEnvelope()).activeAlias;
    final crashing = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: fake,
      injectFailure: (point) {
        if (point == 'after_stage_write') {
          throw StateError('simulated process interruption');
        }
      },
    );
    await expectLater(
      crashing.rotateWrappingKey(databasePath: databasePath),
      throwsStateError,
    );
    final interrupted = await coordinator.readEnvelope();
    expect(interrupted.slots, hasLength(2));
    expect(interrupted.activeAlias, first);
    expect(await openFictionalEntry(), fictionalText);
    await coordinator.resumeRotation(databasePath: databasePath);
    await coordinator.finalizeRotation(databasePath: databasePath);
    expect(await openFictionalEntry(), fictionalText);
    expect((await coordinator.readEnvelope()).slots, hasLength(1));
  });

  test('failure after promotion keeps both slots; finalization recovers',
      () async {
    await createEncryptedDatabase();
    final crashed = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: fake,
      injectFailure: (point) {
        if (point == 'after_primary_promote') {
          throw StateError('simulated crash after promotion');
        }
      },
    );
    await expectLater(
      crashed.rotateWrappingKey(databasePath: databasePath),
      throwsStateError,
    );
    final interrupted = await coordinator.readEnvelope();
    expect(interrupted.slots, hasLength(2));
    expect(interrupted.active.generation, 2);
    await coordinator.resumeRotation(databasePath: databasePath);
    expect(await openFictionalEntry(), fictionalText);
    await coordinator.finalizeRotation(databasePath: databasePath);
    expect(await openFictionalEntry(), fictionalText);
  });

  test('failure after safe slot removal leaves usable vault', () async {
    await createEncryptedDatabase();
    await coordinator.rotateWrappingKey(databasePath: databasePath);
    final crash = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: fake,
      injectFailure: (point) {
        if (point == 'after_remove_old_slot') {
          throw StateError('simulated interruption during retirement');
        }
      },
    );
    await expectLater(
      crash.finalizeRotation(databasePath: databasePath),
      throwsStateError,
    );
    expect((await coordinator.readEnvelope()).slots, hasLength(1));
    expect(await openFictionalEntry(), fictionalText);
  });

  test('lost device keys cannot silently recreate or reset a vault',
      () async {
    await createEncryptedDatabase();
    final lost = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: FakeDeviceKeystore(), // simulates new device/key loss
    );
    final before = await envelopeFile.readAsString();
    await expectLater(
      lost.unlock(databasePath: databasePath),
      throwsA(isA<MissingVaultKey>()),
    );
    await expectLater(
      lost.initialize(databasePath: databasePath),
      throwsStateError,
    );
    expect(await envelopeFile.readAsString(), before);
    expect(await openFictionalEntry(), fictionalText);
  });

  test('tampered tag cannot unlock and never resets original file',
      () async {
    await createEncryptedDatabase();
    final original = await envelopeFile.readAsString();
    final parsed = jsonDecode(original) as Map<String, dynamic>;
    final slot = (parsed['slots'] as List).first as Map<String, dynamic>;
    final wrapped = slot['wrapped'] as Map<String, dynamic>;
    wrapped['tag'] = base64Encode(List<int>.filled(16, 0));
    await envelopeFile.writeAsString(jsonEncode(parsed), flush: true);
    await expectLater(
      coordinator.unlock(databasePath: databasePath),
      throwsA(isA<MissingVaultKey>()),
    );
    expect(File(databasePath).existsSync(), isTrue);
    await envelopeFile.writeAsString(original, flush: true);
    expect(await openFictionalEntry(), fictionalText);
  });

  test('unsupported schema never falls back to first-time key generation',
      () async {
    await createEncryptedDatabase();
    final parsed = jsonDecode(await envelopeFile.readAsString())
        as Map<String, dynamic>;
    parsed['schema'] = 99;
    await envelopeFile.writeAsString(jsonEncode(parsed), flush: true);
    await expectLater(
      coordinator.unlock(databasePath: databasePath),
      throwsA(isA<BrokenEnvelope>()),
    );
    await expectLater(
      coordinator.initialize(databasePath: databasePath),
      throwsStateError,
    );
    expect(File(databasePath).existsSync(), isTrue);
  });

  test('existing database with missing envelope cannot be auto-reset',
      () async {
    await createEncryptedDatabase();
    await envelopeFile.delete();
    await expectLater(
      coordinator.unlock(databasePath: databasePath),
      throwsA(isA<MissingVaultKey>()),
    );
    await expectLater(
      coordinator.initialize(databasePath: databasePath),
      throwsStateError,
    );
    expect(File(databasePath).existsSync(), isTrue);
  });

  test('existing envelope without database also refuses silent reset',
      () async {
    await createEncryptedDatabase();
    File(databasePath).deleteSync();
    await expectLater(
      coordinator.unlock(databasePath: databasePath),
      throwsA(isA<MissingVaultKey>()),
    );
    await expectLater(
      coordinator.initialize(databasePath: databasePath),
      throwsStateError,
    );
    expect(await envelopeFile.exists(), isTrue);
  });

  test('pre-commit failure does not replace previous working envelope',
      () async {
    await createEncryptedDatabase();
    final before = await envelopeFile.readAsString();
    final crash = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile,
      protector: fake,
      injectFailure: (point) {
        if (point == 'before_envelope_rename') {
          throw StateError('simulated interrupted metadata write');
        }
      },
    );
    await expectLater(
      crash.rotateWrappingKey(databasePath: databasePath),
      throwsStateError,
    );
    expect(await envelopeFile.readAsString(), before);
    expect(await openFictionalEntry(), fictionalText);
  });

  test('rotation already staged refuses second fresh alias rotation',
      () async {
    await createEncryptedDatabase();
    await coordinator.rotateWrappingKey(databasePath: databasePath);
    await expectLater(
      coordinator.rotateWrappingKey(databasePath: databasePath),
      throwsStateError,
    );
    expect(await openFictionalEntry(), fictionalText);
  });
}
