/// Stage 5D.1 V3: isolated authenticated archive contract, FICTIONAL DATA ONLY.
///
/// This codec deliberately does not touch SQLite, Flutter, Keystore or disk.
/// A future, separately reviewed vault integration must import the exact
/// authenticated receipt ledger transactionally, with no-clobber publication.
/// Never treat a verified archive as an approved private-data backup.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'product_encrypted_archive.dart';
import 'product_snapshot.dart';
import 'recovery_archive.dart';

/// Inner V3 snapshot: the existing validated entire journal plus the
/// transactionally committed encrypted conflict-copy provenance ledger.
class ProductSnapshotV3Codec {
  static const format = 'NJR-PRODUCT-SNAPSHOT-2';
  static const maxReceipts = ProductSnapshotCodec.maxEntries;

  final ProductSnapshotCodec _legacy = ProductSnapshotCodec();

  Future<void> validate(Map<String, dynamic> source) async {
    const keys = {
      'format', 'exportedAtUtc', 'journals', 'entries', 'revisions',
      'attachments', 'conflictCopyReceipts',
    };
    if (source.length != keys.length ||
        !source.keys.toSet().containsAll(keys) ||
        source['format'] != format) {
      throw const ProductSnapshotRejected();
    }
    // Preserve the existing strict schema/reference, media SHA-256, version
    // history, and timestamp checks without mutating the caller's snapshot.
    final oldSchema = Map<String, dynamic>.from(source)
      ..remove('conflictCopyReceipts')
      ..['format'] = ProductSnapshotCodec.format;
    await _legacy.validate(oldSchema);

    final rawReceipts = source['conflictCopyReceipts'];
    if (rawReceipts is! List || rawReceipts.length > maxReceipts) {
      throw const ProductSnapshotRejected();
    }
    final journals = <String>{};
    for (final raw in source['journals'] as List) {
      final row = raw as Map<String, dynamic>;
      journals.add(row['id'] as String);
    }
    final entries = <String, Map<String, dynamic>>{};
    for (final raw in source['entries'] as List) {
      final row = raw as Map<String, dynamic>;
      entries[row['id'] as String] = row;
    }
    final operations = <String>{};
    final copyIds = <String>{};
    final receiptKeys = {
      'operationId', 'sourceEntryId', 'expectedOriginalVersion',
      'competingOriginalVersion', 'copyEntryId', 'journalId', 'createdAtMs',
    };

    for (final raw in rawReceipts) {
      if (raw is! Map<String, dynamic> ||
          raw.length != receiptKeys.length ||
          !raw.keys.toSet().containsAll(receiptKeys)) {
        throw const ProductSnapshotRejected();
      }
      final operation = raw['operationId'];
      final sourceId = raw['sourceEntryId'];
      final copyId = raw['copyEntryId'];
      final journalId = raw['journalId'];
      if (operation is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(operation) ||
          !operations.add(operation) ||
          sourceId is! String ||
          copyId is! String ||
          sourceId == copyId ||
          !copyIds.add(copyId) ||
          journalId is! String ||
          !journals.contains(journalId)) {
        throw const ProductSnapshotRejected();
      }
      final sourceEntry = entries[sourceId];
      final copyEntry = entries[copyId];
      if (sourceEntry == null || copyEntry == null) {
        throw const ProductSnapshotRejected();
      }
      final expected = raw['expectedOriginalVersion'];
      final competing = raw['competingOriginalVersion'];
      final created = raw['createdAtMs'];
      if (expected is! int || competing is! int ||
          expected < 1 || competing <= expected ||
          competing > (sourceEntry['version'] as int) ||
          created is! int || created < 0 ||
          created > 8640000000000000 ||
          created < (sourceEntry['createdAtMs'] as int) ||
          created < (copyEntry['createdAtMs'] as int)) {
        throw const ProductSnapshotRejected();
      }
      // The preserved copy may have been edited, moved, archived, or trashed.
      // Never require its current journal/version/body to match creation time.
    }
  }

  Future<Uint8List> encode(Map<String, dynamic> source) async {
    await validate(source);
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(source)));
    if (bytes.length > ProductSnapshotCodec.maxPayloadBytes) {
      bytes.fillRange(0, bytes.length, 0);
      throw const ProductSnapshotRejected();
    }
    return bytes;
  }

  Future<Map<String, dynamic>> decode(Uint8List raw) async {
    if (raw.isEmpty || raw.length > ProductSnapshotCodec.maxPayloadBytes) {
      throw const ProductSnapshotRejected();
    }
    try {
      final parsed = jsonDecode(utf8.decode(raw));
      if (parsed is! Map<String, dynamic>) {
        throw const ProductSnapshotRejected();
      }
      await validate(parsed);
      return parsed;
    } catch (_) {
      throw const ProductSnapshotRejected();
    }
  }
}

/// Indicates which exact archive format was authenticated. V2 archives have
/// no provenance records: this flag is an explicit warning, not an empty
/// "verified" receipt list fabricated during migration.
class VerifiedProductArchive {
  final String archiveFormat;
  final Map<String, dynamic> snapshot;
  final bool hasAuthenticatedConflictProvenance;

  const VerifiedProductArchive({
    required this.archiveFormat,
    required this.snapshot,
    required this.hasAuthenticatedConflictProvenance,
  });
}

/// Read V2 as legacy; WRITE V3 only. Outer V3 authentication is explicitly
/// domain-separated from V2 and cannot be relabeled to downgrade ciphertext.
class ProductArchiveV3Codec {
  static const format = 'NJR-RECOVERY-3';
  static const _aad = 'navin-journal|product-recovery|version-3';
  static const _maxContainerBytes = ProductSnapshotCodec.maxPayloadBytes * 2;
  final ProductSnapshotV3Codec snapshotCodec;
  final ProductEncryptedArchiveCodec _v2;
  final AesGcm _cipher = AesGcm.with256bits();

  ProductArchiveV3Codec({
    ProductSnapshotV3Codec? snapshotCodec,
    ProductEncryptedArchiveCodec? legacyV2,
  })  : snapshotCodec = snapshotCodec ?? ProductSnapshotV3Codec(),
        _v2 = legacyV2 ?? ProductEncryptedArchiveCodec();

  Future<Uint8List> export({
    required RecoveryKey recoveryKey,
    required Map<String, dynamic> snapshot,
  }) async {
    final plaintext = await snapshotCodec.encode(snapshot);
    final key = recoveryKey.snapshot();
    try {
      final box = await _cipher.encrypt(
        plaintext,
        secretKey: SecretKey(key),
        aad: utf8.encode(_aad),
      );
      final result = Uint8List.fromList(utf8.encode(jsonEncode({
        'format': format,
        'algorithm': 'AES-256-GCM',
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      })));
      if (result.length > _maxContainerBytes) {
        result.fillRange(0, result.length, 0);
        throw const ArchiveRejected();
      }
      return result;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
      key.fillRange(0, key.length, 0);
    }
  }

  Future<VerifiedProductArchive> verify({
    required RecoveryKey recoveryKey,
    required Uint8List archive,
  }) async {
    if (archive.isEmpty || archive.length > _maxContainerBytes) {
      throw const ArchiveRejected();
    }
    late final Map<String, dynamic> container;
    try {
      final json = jsonDecode(utf8.decode(archive));
      if (json is! Map<String, dynamic>) throw const ArchiveRejected();
      container = json;
    } catch (_) {
      throw const ArchiveRejected();
    }

    // Only the public format tag is used to select a verifier. Each verifier
    // authenticates the ciphertext with its OWN version-specific AAD.
    if (container['format'] == ProductEncryptedArchiveCodec.format) {
      final legacy = await _v2.verify(
        recoveryKey: recoveryKey,
        archive: archive,
      );
      return VerifiedProductArchive(
        archiveFormat: ProductEncryptedArchiveCodec.format,
        snapshot: legacy,
        hasAuthenticatedConflictProvenance: false,
      );
    }
    if (container.length != 5 ||
        !container.keys.toSet().containsAll({
          'format', 'algorithm', 'nonce', 'ciphertext', 'tag',
        }) ||
        container['format'] != format ||
        container['algorithm'] != 'AES-256-GCM') {
      throw const ArchiveRejected();
    }

    Uint8List part(String name, {int? length}) {
      final encoded = container[name];
      if (encoded is! String || encoded.length > _maxContainerBytes) {
        throw const ArchiveRejected();
      }
      try {
        final bytes = Uint8List.fromList(base64Decode(encoded));
        if ((length != null && bytes.length != length) ||
            base64Encode(bytes) != encoded) {
          throw const ArchiveRejected();
        }
        return bytes;
      } catch (_) {
        throw const ArchiveRejected();
      }
    }

    final nonce = part('nonce', length: 12);
    final tag = part('tag', length: 16);
    final ciphertext = part('ciphertext');
    if (ciphertext.length > ProductSnapshotCodec.maxPayloadBytes) {
      throw const ArchiveRejected();
    }

    final key = recoveryKey.snapshot();
    late final Uint8List plaintext;
    try {
      final result = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(key),
        aad: utf8.encode(_aad),
      );
      plaintext = Uint8List.fromList(result);
    } catch (_) {
      throw const ArchiveRejected();
    } finally {
      key.fillRange(0, key.length, 0);
    }
    try {
      return VerifiedProductArchive(
        archiveFormat: format,
        snapshot: await snapshotCodec.decode(plaintext),
        hasAuthenticatedConflictProvenance: true,
      );
    } catch (_) {
      throw const ArchiveRejected();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}
