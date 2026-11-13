/// A4.3.2 — encrypted whole-journal snapshot container. FICTIONAL DATA ONLY.
///
/// This encrypts the validated A4.3.1 logical schema independently of the
/// Android device key. It does not read a live database, write files, restore
/// a vault, or manage recovery-key custody. Production integration and
/// independent security review remain open.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'product_snapshot.dart';
import 'recovery_archive.dart';

class ProductEncryptedArchiveCodec {
  static const format = 'NJR-RECOVERY-2';
  static const _domain = 'navin-journal|product-recovery|version-2';
  static const _maxContainerBytes = ProductSnapshotCodec.maxPayloadBytes * 2;

  final ProductSnapshotCodec snapshotCodec;
  final _cipher = AesGcm.with256bits();

  ProductEncryptedArchiveCodec({ProductSnapshotCodec? snapshotCodec})
      : snapshotCodec = snapshotCodec ?? ProductSnapshotCodec();

  /// Returns fully encrypted version-2 archive. The only unencrypted fields
  /// are version/algorithm, nonce, ciphertext and authentication tag.
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
        aad: utf8.encode(_domain),
      );
      final container = utf8.encode(jsonEncode({
        'format': format,
        'algorithm': 'AES-256-GCM',
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      }));
      if (container.length > _maxContainerBytes) {
        throw const ArchiveRejected();
      }
      return Uint8List.fromList(container);
    } finally {
      key.fillRange(0, key.length, 0);
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  /// Authenticates first and only then interprets the logical journal schema.
  /// Never use this result to mutate an existing vault; A4.3 restore is open.
  Future<Map<String, dynamic>> verify({
    required RecoveryKey recoveryKey,
    required Uint8List archive,
  }) async {
    if (archive.isEmpty || archive.length > _maxContainerBytes) {
      throw const ArchiveRejected();
    }
    late final Map<String, dynamic> container;
    try {
      final obj = jsonDecode(utf8.decode(archive));
      if (obj is! Map<String, dynamic>) throw const ArchiveRejected();
      container = obj;
    } catch (_) {
      throw const ArchiveRejected();
    }
    if (container.length != 5 ||
        container.keys.toSet().length != 5 ||
        !container.keys.toSet().containsAll({
          'format', 'algorithm', 'nonce', 'ciphertext', 'tag',
        }) ||
        container['format'] != format ||
        container['algorithm'] != 'AES-256-GCM') {
      throw const ArchiveRejected();
    }

    Uint8List part(String name, {int? size}) {
      final encoded = container[name];
      if (encoded is! String ||
          encoded.length > _maxContainerBytes) {
        throw const ArchiveRejected();
      }
      try {
        final bytes = base64Decode(encoded);
        if (size != null && bytes.length != size) {
          throw const ArchiveRejected();
        }
        if (base64Encode(bytes) != encoded) {
          throw const ArchiveRejected();
        }
        return Uint8List.fromList(bytes);
      } catch (_) {
        throw const ArchiveRejected();
      }
    }

    final nonce = part('nonce', size: 12);
    final tag = part('tag', size: 16);
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
        aad: utf8.encode(_domain),
      );
      plaintext = Uint8List.fromList(result);
    } catch (_) {
      throw const ArchiveRejected();
    } finally {
      key.fillRange(0, key.length, 0);
    }
    try {
      return await snapshotCodec.decode(plaintext);
    } catch (_) {
      throw const ArchiveRejected();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }
}
