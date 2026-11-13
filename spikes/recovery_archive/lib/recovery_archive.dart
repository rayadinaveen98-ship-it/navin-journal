/// Stage 4 A4.1: isolated encrypted portable archive verification proof.
///
/// All test data must be FICTIONAL. This is NOT a finished backup/restore
/// implementation, audited key management or secure production archive.
///
/// A random 256-bit recovery key is independent of AndroidKeyStore. The user
/// must keep that key outside the device; losing the key loses the archive.
/// Password UX/KDF, transactional restoration, attachments on-disk, power-loss
/// durability, key storage and independent security review are pending.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class ArchiveRejected implements Exception {
  const ArchiveRejected();

  @override
  String toString() => 'ArchiveRejected';
}

class RecoveryKey {
  final Uint8List _bytes;
  bool _destroyed = false;

  RecoveryKey._(this._bytes);

  factory RecoveryKey.random() {
    final rng = Random.secure();
    return RecoveryKey._(Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    ));
  }

  factory RecoveryKey.parse(String external) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(external)) {
      throw const ArchiveRejected();
    }
    try {
      final bytes = base64Url.decode(base64Url.normalize(external));
      if (bytes.length != 32 ||
          base64Url.encode(bytes).replaceAll('=', '') != external) {
        throw const ArchiveRejected();
      }
      return RecoveryKey._(Uint8List.fromList(bytes));
    } on FormatException {
      throw const ArchiveRejected();
    }
  }

  /// Test-only portable key; NEVER put into logs, analytics or archive file.
  String exportForOfflineStorage() {
    if (_destroyed) throw StateError('Recovery key destroyed');
    return base64Url.encode(_bytes).replaceAll('=', '');
  }

  Uint8List snapshot() {
    if (_destroyed) throw StateError('Recovery key destroyed');
    return Uint8List.fromList(_bytes);
  }

  void destroy() {
    _bytes.fillRange(0, _bytes.length, 0);
    _destroyed = true;
  }
}

class PortableEntry {
  final String id;
  final String title;
  final String body;
  const PortableEntry({
    required this.id,
    required this.title,
    required this.body,
  });

  @override
  bool operator ==(Object other) =>
      other is PortableEntry &&
      other.id == id &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, title, body);
}

class PortableAttachment {
  final String id;
  final String name;
  final String mimeType;
  final Uint8List bytes;

  PortableAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
}

class VerifiedRecoveryArchive {
  final DateTime createdAtUtc;
  final List<PortableEntry> entries;
  final List<PortableAttachment> attachments;
  const VerifiedRecoveryArchive({
    required this.createdAtUtc,
    required this.entries,
    required this.attachments,
  });
}

/// A small, bounded encrypted container. Entire manifest, entry bodies,
/// filenames, attachment bytes and counts are inside AES-256-GCM.
///
/// A successful [verify] does not change an existing vault. Actual restore
/// must stage and atomically commit to a separate destination with conflict
/// checks, migrations and available-space review in a later A4 gate.
class RecoveryArchiveCodec {
  static const format = 'NJR-RECOVERY-1';
  static const _domain = 'navin-journal|portable-archive|version-1';
  static const _maxFileBytes = 6 * 1024 * 1024;
  static const _maxMediaBytes = 2 * 1024 * 1024;
  static const _maxRecords = 1000;
  static const _maxAttachments = 25;
  static const _maxTextChars = 100000;
  static const _maxNameLength = 160;
  final _cipher = AesGcm.with256bits();
  final _hash = Sha256();

  void _checkId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id)) {
      throw const ArchiveRejected();
    }
  }

  void _checkEntry(PortableEntry entry) {
    _checkId(entry.id);
    if (entry.title.length > _maxTextChars ||
        entry.body.length > _maxTextChars) {
      throw const ArchiveRejected();
    }
  }

  void _checkAttachment(PortableAttachment a) {
    _checkId(a.id);
    if (a.name.isEmpty ||
        a.name.length > _maxNameLength ||
        a.name == '.' ||
        a.name == '..' ||
        a.name.contains('/') ||
        a.name.contains('\\') ||
        a.name.runes.any((v) => v < 32 || v == 127) ||
        !RegExp(r'^[a-zA-Z0-9.+_-]+/[a-zA-Z0-9.+_-]+$')
            .hasMatch(a.mimeType) ||
        a.bytes.length > _maxMediaBytes) {
      throw const ArchiveRejected();
    }
  }

  Future<Uint8List> export({
    required RecoveryKey key,
    required List<PortableEntry> entries,
    required List<PortableAttachment> attachments,
    DateTime? createdAtUtc,
  }) async {
    _validate(entries, attachments);
    final manifests = <Map<String, Object>>[];
    for (final attachment in attachments) {
      final digest = await _hash.hash(attachment.bytes);
      manifests.add({
        'id': attachment.id,
        'name': attachment.name,
        'mime': attachment.mimeType,
        'sha256': base64Encode(digest.bytes),
        'data': base64Encode(attachment.bytes),
      });
    }

    final payload = utf8.encode(jsonEncode({
      'schema': 1,
      'created': (createdAtUtc ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'counts': {'entries': entries.length, 'attachments': attachments.length},
      'entries': [
        for (final e in entries)
          {'id': e.id, 'title': e.title, 'body': e.body},
      ],
      'attachments': manifests,
    }));
    if (payload.length > _maxFileBytes) throw const ArchiveRejected();

    final raw = key.snapshot();
    try {
      final box = await _cipher.encrypt(
        payload,
        secretKey: SecretKey(raw),
        aad: utf8.encode(_domain),
      );
      final container = utf8.encode(jsonEncode({
        'format': format,
        'algorithm': 'AES-256-GCM',
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'tag': base64Encode(box.mac.bytes),
      }));
      if (container.length > _maxFileBytes * 2) {
        throw const ArchiveRejected();
      }
      return Uint8List.fromList(container);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  Future<VerifiedRecoveryArchive> verify({
    required RecoveryKey key,
    required Uint8List archive,
  }) async {
    if (archive.isEmpty || archive.length > _maxFileBytes * 2) {
      throw const ArchiveRejected();
    }
    Map<String, dynamic> container;
    try {
      final decoded = jsonDecode(utf8.decode(archive));
      if (decoded is! Map<String, dynamic>) throw const ArchiveRejected();
      container = decoded;
    } catch (_) {
      throw const ArchiveRejected();
    }
    if (container.length != 5 ||
        container['format'] != format ||
        container['algorithm'] != 'AES-256-GCM') {
      throw const ArchiveRejected();
    }
    List<int> decodePart(String name, {int? size}) {
      final value = container[name];
      if (value is! String) throw const ArchiveRejected();
      try {
        final bytes = base64Decode(value);
        if (size != null && bytes.length != size) throw const ArchiveRejected();
        return bytes;
      } catch (_) {
        throw const ArchiveRejected();
      }
    }

    final nonce = decodePart('nonce', size: 12);
    final tag = decodePart('tag', size: 16);
    final encrypted = decodePart('ciphertext');
    if (encrypted.length > _maxFileBytes) throw const ArchiveRejected();

    final raw = key.snapshot();
    List<int> plaintext;
    try {
      plaintext = await _cipher.decrypt(
        SecretBox(encrypted, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(raw),
        aad: utf8.encode(_domain),
      );
    } catch (_) {
      // Wrong key, tampering, malformed ciphertext all fail identically.
      throw const ArchiveRejected();
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
    if (plaintext.length > _maxFileBytes) throw const ArchiveRejected();

    try {
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != 1 ||
          decoded['counts'] is! Map ||
          decoded['entries'] is! List ||
          decoded['attachments'] is! List ||
          decoded['created'] is! String) {
        throw const ArchiveRejected();
      }
      final created = DateTime.tryParse(decoded['created'] as String);
      if (created == null || !created.isUtc) throw const ArchiveRejected();
      final entryObjects = decoded['entries'] as List;
      final mediaObjects = decoded['attachments'] as List;
      if (entryObjects.length > _maxRecords ||
          mediaObjects.length > _maxAttachments) {
        throw const ArchiveRejected();
      }
      final entries = <PortableEntry>[];
      final media = <PortableAttachment>[];

      for (final row in entryObjects) {
        if (row is! Map ||
            row['id'] is! String ||
            row['title'] is! String ||
            row['body'] is! String) {
          throw const ArchiveRejected();
        }
        entries.add(PortableEntry(
          id: row['id'] as String,
          title: row['title'] as String,
          body: row['body'] as String,
        ));
      }
      for (final row in mediaObjects) {
        if (row is! Map ||
            row['id'] is! String ||
            row['name'] is! String ||
            row['mime'] is! String ||
            row['data'] is! String ||
            row['sha256'] is! String) {
          throw const ArchiveRejected();
        }
        final bytes = base64Decode(row['data'] as String);
        final digest = await _hash.hash(bytes);
        if (base64Encode(digest.bytes) != row['sha256']) {
          throw const ArchiveRejected();
        }
        media.add(PortableAttachment(
          id: row['id'] as String,
          name: row['name'] as String,
          mimeType: row['mime'] as String,
          bytes: Uint8List.fromList(bytes),
        ));
      }
      final counts = decoded['counts'] as Map;
      if (counts['entries'] != entries.length ||
          counts['attachments'] != media.length) {
        throw const ArchiveRejected();
      }
      _validate(entries, media);
      return VerifiedRecoveryArchive(
        createdAtUtc: created,
        entries: List.unmodifiable(entries),
        attachments: List.unmodifiable(media),
      );
    } catch (_) {
      throw const ArchiveRejected();
    }
  }

  void _validate(List<PortableEntry> entries, List<PortableAttachment> media) {
    if (entries.length > _maxRecords || media.length > _maxAttachments) {
      throw const ArchiveRejected();
    }
    final ids = <String>{};
    for (final e in entries) {
      _checkEntry(e);
      if (!ids.add('entry:' + e.id)) throw const ArchiveRejected();
    }
    for (final a in media) {
      _checkAttachment(a);
      if (!ids.add('media:' + a.id)) throw const ArchiveRejected();
    }
  }
}
