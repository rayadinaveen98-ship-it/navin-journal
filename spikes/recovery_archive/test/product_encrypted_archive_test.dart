/// A4.3.2 full-schema authenticated archive tests — fictional data only.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

final productCodec = ProductEncryptedArchiveCodec();

Future<Map<String, dynamic>> sampleProduct() async {
  final media = [0, 20, 30, 50, 255];
  final hash = await Sha256().hash(media);
  return {
    'format': ProductSnapshotCodec.format,
    'exportedAtUtc': DateTime.utc(2026, 11, 13).toIso8601String(),
    'journals': [
      {
        'id': 'journal1', 'name': 'జ్ఞాపకాలు', 'archived': false,
        'createdAtMs': 1700000000000, 'deletedAtMs': null,
      },
      {
        'id': 'deletedJ', 'name': 'Earlier', 'archived': true,
        'createdAtMs': 1700000000000, 'deletedAtMs': 1800000000000,
      },
    ],
    'entries': [
      {
        'id': 'entry1', 'journalId': 'journal1', 'title': 'Private fiction 🪷',
        'body': 'Some Telugu తెలుగు and English words.',
        'createdAtMs': 1700000000000, 'updatedAtMs': 1700000002000,
        'eventAtMs': 1650000000000, 'version': 2, 'deletedAtMs': null,
      },
    ],
    'revisions': [
      {
        'entryId': 'entry1', 'version': 1, 'journalId': 'deletedJ',
        'title': 'Earlier', 'body': 'Fictional first revision',
        'eventAtMs': 1650000000000, 'updatedAtMs': 1700000001000,
      },
    ],
    'attachments': [
      {
        'id': 'attachment1', 'entryId': 'entry1', 'name': 'scene.png',
        'mime': 'image/png', 'data': base64Encode(media),
        'sha256': base64Encode(hash.bytes),
      },
    ],
  };
}

void main() {
  late RecoveryKey key;
  setUp(() => key = RecoveryKey.random());
  tearDown(() => key.destroy());

  test('encrypts, authenticates and round-trips full product structure', () async {
    final source = await sampleProduct();
    final result = await productCodec.export(
      recoveryKey: key, snapshot: source,
    );
    final recovered = await productCodec.verify(
      recoveryKey: key, archive: result,
    );
    expect(recovered, source);
    expect(recovered['revisions'][0]['journalId'], 'deletedJ');
    expect(recovered['attachments'][0]['data'], base64Encode([0, 20, 30, 50, 255]));
  });

  test('plaintext titles, Telugu, body, journal names and filenames absent', () async {
    final bytes = await productCodec.export(
      recoveryKey: key, snapshot: await sampleProduct(),
    );
    final visible = utf8.decode(bytes);
    for (final secret in [
      'Private fiction', 'తెలుగు', 'జ్ఞాపకాలు',
      'Fictional first revision', 'scene.png',
    ]) {
      expect(visible.contains(secret), isFalse);
    }
    final json = jsonDecode(visible) as Map<String, dynamic>;
    expect(json.keys.toSet(), {
      'format', 'algorithm', 'nonce', 'ciphertext', 'tag',
    });
  });

  test('recovery key is independent and a wrong key fails closed', () async {
    final archive = await productCodec.export(
      recoveryKey: key, snapshot: await sampleProduct(),
    );
    final other = RecoveryKey.random();
    try {
      await expectLater(
        productCodec.verify(recoveryKey: other, archive: archive),
        throwsA(isA<ArchiveRejected>()),
      );
    } finally {
      other.destroy();
    }
    // Reopen with the externally retained recovery key text.
    final external = key.exportForOfflineStorage();
    final restored = RecoveryKey.parse(external);
    try {
      final result = await productCodec.verify(
        recoveryKey: restored, archive: archive,
      );
      expect(result['entries'][0]['id'], 'entry1');
    } finally {
      restored.destroy();
    }
  });

  test('ciphertext tampering is rejected without returning any journals', () async {
    final archive = await productCodec.export(
      recoveryKey: key, snapshot: await sampleProduct(),
    );
    final wrapper = jsonDecode(utf8.decode(archive)) as Map<String, dynamic>;
    final ciphertext = base64Decode(wrapper['ciphertext'] as String);
    ciphertext[0] ^= 0x80;
    wrapper['ciphertext'] = base64Encode(ciphertext);
    await expectLater(
      productCodec.verify(
        recoveryKey: key,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(wrapper))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('version downgrade and unrecognized metadata are refused', () async {
    final archive = await productCodec.export(
      recoveryKey: key, snapshot: await sampleProduct(),
    );
    final original = jsonDecode(utf8.decode(archive)) as Map<String, dynamic>;
    final downgrade = Map<String, dynamic>.from(original);
    downgrade['format'] = RecoveryArchiveCodec.format;
    await expectLater(
      productCodec.verify(
        recoveryKey: key,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(downgrade))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
    final unknown = Map<String, dynamic>.from(original);
    unknown['unused'] = 'should be refused';
    await expectLater(
      productCodec.verify(
        recoveryKey: key,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(unknown))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('a source with dangling references cannot be encrypted', () async {
    final source = await sampleProduct();
    source['attachments'][0]['entryId'] = 'missing';
    await expectLater(
      productCodec.export(recoveryKey: key, snapshot: source),
      throwsA(isA<ProductSnapshotRejected>()),
    );
  });

  test('legacy A4.1 archive is not misread as product archive', () async {
    final old = await RecoveryArchiveCodec().export(
      key: key,
      entries: [
        const PortableEntry(id: 'old1', title: 'Fiction', body: 'Demo'),
      ],
      attachments: [],
    );
    await expectLater(
      productCodec.verify(recoveryKey: key, archive: old),
      throwsA(isA<ArchiveRejected>()),
    );
  });
}
