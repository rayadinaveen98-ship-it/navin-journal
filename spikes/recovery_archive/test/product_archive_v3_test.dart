/// Stage 5D.1 isolated V3 format and integrity tests. FICTIONAL DATA ONLY.
import 'dart:convert';
import 'dart:typed_data';

import 'package:navin_journal_recovery_archive_spike/product_archive_v3.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

const _op = 'edit-00112233445566778899aabbccddeeff';

Map<String, dynamic> _sample() => {
  'format': ProductSnapshotV3Codec.format,
  'exportedAtUtc': DateTime.utc(2026, 11, 16).toIso8601String(),
  'journals': [
    {
      'id': 'home', 'name': 'Fictional తెలుగు', 'archived': false,
      'createdAtMs': 1700000000000, 'deletedAtMs': null,
    },
    {
      'id': 'past', 'name': 'Earlier fiction', 'archived': false,
      'createdAtMs': 1700000000000, 'deletedAtMs': null,
    },
  ],
  'entries': [
    {
      'id': 'original', 'journalId': 'home',
      'title': 'First fictional page', 'body': 'Protected latest తెలుగు',
      'createdAtMs': 1700000000000, 'updatedAtMs': 1700000002000,
      'eventAtMs': null, 'version': 2, 'deletedAtMs': null,
    },
    {
      'id': 'copy001', 'journalId': 'home',
      'title': 'Preserved fictional page', 'body': 'Losing draft 🪷',
      'createdAtMs': 1700000003000, 'updatedAtMs': 1700000003000,
      'eventAtMs': null, 'version': 1, 'deletedAtMs': null,
    },
  ],
  'revisions': [
    {
      'entryId': 'original', 'journalId': 'home', 'version': 1,
      'title': 'Earlier fictional page', 'body': 'Original text',
      'eventAtMs': null, 'updatedAtMs': 1700000001000,
    },
  ],
  'attachments': [],
  'conflictCopyReceipts': [
    {
      'operationId': _op,
      'sourceEntryId': 'original', 'expectedOriginalVersion': 1,
      'competingOriginalVersion': 2, 'copyEntryId': 'copy001',
      'journalId': 'home', 'createdAtMs': 1700000003000,
    },
  ],
};

Map<String, dynamic> _clone(Map<String, dynamic> input) =>
    jsonDecode(jsonEncode(input)) as Map<String, dynamic>;

Map<String, dynamic> _v2Sample() {
  final old = _sample()
    ..remove('conflictCopyReceipts')
    ..['format'] = ProductSnapshotCodec.format;
  return old;
}

void main() {
  late RecoveryKey key;
  late ProductArchiveV3Codec archive;
  late ProductSnapshotV3Codec snapshot;
  setUp(() {
    key = RecoveryKey.random();
    archive = ProductArchiveV3Codec();
    snapshot = ProductSnapshotV3Codec();
  });
  tearDown(() => key.destroy());

  test('v3 authenticated round-trip retains all receipt provenance', () async {
    final input = _sample();
    final exported = await archive.export(recoveryKey: key, snapshot: input);
    final result = await archive.verify(recoveryKey: key, archive: exported);
    expect(result.archiveFormat, ProductArchiveV3Codec.format);
    expect(result.hasAuthenticatedConflictProvenance, isTrue);
    expect(result.snapshot, input);
    expect(result.snapshot['conflictCopyReceipts'][0]['operationId'], _op);
    expect(result.snapshot['entries'][0]['version'], 2);
    final visible = utf8.decode(exported);
    for (final secret in [
      _op, 'original', 'copy001', 'Protected latest',
      'తెలుగు', 'Losing draft', 'Fictional తెలుగు',
    ]) {
      expect(visible.contains(secret), isFalse);
    }
    final wrapper = jsonDecode(visible) as Map<String, dynamic>;
    expect(wrapper.keys.toSet(),
        {'format', 'algorithm', 'nonce', 'ciphertext', 'tag'});
  });

  test('valid legacy v2 is readable but never claims provenance', () async {
    final original = _v2Sample();
    final oldBytes = await ProductEncryptedArchiveCodec().export(
      recoveryKey: key, snapshot: original);
    final recovered = await archive.verify(
      recoveryKey: key, archive: oldBytes);
    expect(recovered.archiveFormat, ProductEncryptedArchiveCodec.format);
    expect(recovered.hasAuthenticatedConflictProvenance, isFalse);
    expect(recovered.snapshot, original);
    expect(recovered.snapshot.containsKey('conflictCopyReceipts'), isFalse);
    await expectLater(
      archive.export(recoveryKey: key, snapshot: original),
      throwsA(isA<ProductSnapshotRejected>()),
    );
    await expectLater(
      ProductEncryptedArchiveCodec().verify(
        recoveryKey: key,
        archive: await archive.export(
          recoveryKey: key, snapshot: _sample()),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('wrong recovery key, tampered ciphertext and tag fail closed', () async {
    final original = await archive.export(
      recoveryKey: key, snapshot: _sample());
    final other = RecoveryKey.random();
    try {
      await expectLater(
        archive.verify(recoveryKey: other, archive: original),
        throwsA(isA<ArchiveRejected>()),
      );
    } finally {
      other.destroy();
    }
    for (final field in ['ciphertext', 'tag']) {
      final changed = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
      final bytes = base64Decode(changed[field] as String);
      bytes[0] ^= 0x20;
      changed[field] = base64Encode(bytes);
      await expectLater(
        archive.verify(recoveryKey: key,
          archive: Uint8List.fromList(utf8.encode(jsonEncode(changed)))),
        throwsA(isA<ArchiveRejected>()),
      );
    }
  });

  test('outer version swap cannot downgrade v3 or upgrade v2', () async {
    final v3 = await archive.export(
      recoveryKey: key, snapshot: _sample());
    final v2 = await ProductEncryptedArchiveCodec().export(
      recoveryKey: key, snapshot: _v2Sample());
    for (final (bytes, format) in [
      (v3, ProductEncryptedArchiveCodec.format),
      (v2, ProductArchiveV3Codec.format),
    ]) {
      final wrapper = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      wrapper['format'] = format;
      await expectLater(
        archive.verify(recoveryKey: key,
          archive: Uint8List.fromList(utf8.encode(jsonEncode(wrapper)))),
        throwsA(isA<ArchiveRejected>()),
      );
    }
  });

  test('strictly rejects unknown outer fields and malformed plaintext', () async {
    final encoded = await archive.export(
      recoveryKey: key, snapshot: _sample());
    final wrapper = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    wrapper['unverified'] = 'attacker';
    await expectLater(
      archive.verify(recoveryKey: key,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(wrapper)))),
      throwsA(isA<ArchiveRejected>()),
    );
    final changed = _sample()..['unverifiedField'] = true;
    await expectLater(snapshot.encode(changed),
        throwsA(isA<ProductSnapshotRejected>()));
    await expectLater(snapshot.decode(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ProductSnapshotRejected>()));
  });

  test('invalid missing, duplicate and cross-source receipt references rejected', () async {
    final variants = <Map<String, dynamic>>[];
    for (final patch in [
      <String, Object?>{'sourceEntryId': 'missing'},
      <String, Object?>{'copyEntryId': 'missing'},
      <String, Object?>{'copyEntryId': 'original'},
      <String, Object?>{'journalId': 'missing'},
      <String, Object?>{'expectedOriginalVersion': 2},
      <String, Object?>{'competingOriginalVersion': 3},
      <String, Object?>{'createdAtMs': 1699999999000},
      <String, Object?>{'operationId': 'short'},
    ]) {
      final variant = _sample();
      (variant['conflictCopyReceipts'] as List).first.addAll(patch);
      variants.add(variant);
    }
    for (final variant in variants) {
      await expectLater(snapshot.encode(variant),
          throwsA(isA<ProductSnapshotRejected>()));
    }
    final dup = _sample();
    (dup['conflictCopyReceipts'] as List).add(
        _clone(_sample())['conflictCopyReceipts'][0]);
    await expectLater(snapshot.encode(dup),
        throwsA(isA<ProductSnapshotRejected>()));
  });

  test('renamed, moved, edited and trashed copy retains valid provenance', () async {
    final source = _sample();
    final copy = (source['entries'] as List)[1] as Map<String, dynamic>;
    copy['journalId'] = 'past';
    copy['title'] = 'Edited and moved fictional page';
    copy['body'] = 'Latest revised Telugu తెలుగు';
    copy['version'] = 2;
    copy['updatedAtMs'] = 1700000005000;
    copy['deletedAtMs'] = 1700000006000;
    (source['revisions'] as List).add({
      'entryId': 'copy001', 'version': 1, 'journalId': 'home',
      'title': 'Preserved fictional page', 'body': 'Losing draft 🪷',
      'eventAtMs': null, 'updatedAtMs': 1700000003000,
    });
    final copyVerified = await archive.verify(
      recoveryKey: key, archive: await archive.export(
        recoveryKey: key, snapshot: source));
    expect(copyVerified.snapshot['conflictCopyReceipts'][0]['copyEntryId'],
        'copy001');
    expect(copyVerified.snapshot['entries'][1]['journalId'], 'past');
    expect(copyVerified.snapshot['entries'][1]['deletedAtMs'], isNotNull);
  });

  test('copy can exist without a receipt, but v3 format still explicit', () async {
    final zeroReceipts = _sample()
      ..['conflictCopyReceipts'] = <Map<String, Object?>>[];
    final validated = await snapshot.decode(await snapshot.encode(zeroReceipts));
    expect(validated['conflictCopyReceipts'], isEmpty);
    expect(validated['format'], ProductSnapshotV3Codec.format);
  });

  test('invalid original revision chain is rejected before encryption', () async {
    final fake = _sample();
    (fake['revisions'] as List).clear();
    await expectLater(archive.export(recoveryKey: key, snapshot: fake),
        throwsA(isA<ProductSnapshotRejected>()));
  });
}
