/// A4.3.1 — logical whole-journal snapshot contract, FICTIONAL DATA ONLY.
///
/// This is a *plaintext in-memory* schema validator/serializer. Never persist
/// or transmit its result directly. The next A4.3 layer must take one
/// transactionally consistent database snapshot, encrypt this payload using
/// an independently held recovery key, and restore it into a new device-bound
/// encrypted vault. This file is NOT itself a backup, migration, or app vault.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class ProductSnapshotRejected implements Exception {
  const ProductSnapshotRejected();
  @override
  String toString() => 'ProductSnapshotRejected';
}

/// Versioned logical payload to be placed *inside* an authenticated archive.
///
/// Preserves journal identity/archive/Trash, entry identity and dates,
/// previous revisions, and entry-associated media. The entry's current
/// version is stored once; historical revisions must be exactly 1..version-1.
/// Revision references may legitimately point to archived/trashed journals.
class ProductSnapshotCodec {
  static const format = 'NJR-PRODUCT-SNAPSHOT-1';
  static const maxPayloadBytes = 6 * 1024 * 1024;
  static const maxMediaBytes = 2 * 1024 * 1024;
  static const maxEntries = 1000;
  static const maxJournals = 100;
  static const maxRevisions = 4000;
  static const maxAttachments = 25;
  static const maxTextChars = 100000;

  final _digest = Sha256();

  /// Returns plaintext bytes IN MEMORY. This is not an encrypted export.
  Future<Uint8List> encode(Map<String, dynamic> snapshot) async {
    await validate(snapshot);
    final bytes = utf8.encode(jsonEncode(snapshot));
    if (bytes.length > maxPayloadBytes) {
      throw const ProductSnapshotRejected();
    }
    return Uint8List.fromList(bytes);
  }

  /// Accept only a previously authenticated/decrypted payload in production.
  Future<Map<String, dynamic>> decode(Uint8List plaintext) async {
    if (plaintext.isEmpty || plaintext.length > maxPayloadBytes) {
      throw const ProductSnapshotRejected();
    }
    try {
      final value = jsonDecode(utf8.decode(plaintext));
      if (value is! Map<String, dynamic>) {
        throw const ProductSnapshotRejected();
      }
      await validate(value);
      return value;
    } catch (_) {
      throw const ProductSnapshotRejected();
    }
  }

  Future<void> validate(Map<String, dynamic> root) async {
    _keys(root, {
      'format', 'exportedAtUtc', 'journals', 'entries', 'revisions',
      'attachments',
    });
    if (root['format'] != format) throw const ProductSnapshotRejected();
    final exported = _string(root['exportedAtUtc'], 40);
    final exportedAt = DateTime.tryParse(exported);
    if (exportedAt == null ||
        !exportedAt.isUtc ||
        exportedAt.toIso8601String() != exported) {
      throw const ProductSnapshotRejected();
    }

    final journals = _rows(root['journals'], maxJournals);
    final entries = _rows(root['entries'], maxEntries);
    final revisions = _rows(root['revisions'], maxRevisions);
    final media = _rows(root['attachments'], maxAttachments);
    final journalIds = <String>{};
    final entryVersions = <String, int>{};
    final entryDates = <String, (int, int)>{};
    final revisionVersions = <String, Set<int>>{};
    final mediaIds = <String>{};

    for (final row in journals) {
      _keys(row, {'id', 'name', 'archived', 'createdAtMs', 'deletedAtMs'});
      final id = _id(row['id']);
      if (!journalIds.add(id)) throw const ProductSnapshotRejected();
      final name = _string(row['name'], 48);
      if (name.trim().isEmpty || name != name.trim()) {
        throw const ProductSnapshotRejected();
      }
      if (row['archived'] is! bool) throw const ProductSnapshotRejected();
      final created = _millis(row['createdAtMs'])!;
      final deleted = _millis(row['deletedAtMs'], nullable: true);
      if (deleted != null && deleted < created) {
        throw const ProductSnapshotRejected();
      }
    }

    for (final row in entries) {
      _keys(row, {
        'id', 'journalId', 'title', 'body', 'createdAtMs',
        'updatedAtMs', 'eventAtMs', 'version', 'deletedAtMs',
      });
      final id = _id(row['id']);
      final journalId = _id(row['journalId']);
      if (!journalIds.contains(journalId) ||
          entryVersions.containsKey(id)) {
        throw const ProductSnapshotRejected();
      }
      _string(row['title'], maxTextChars, allowEmpty: true);
      _string(row['body'], maxTextChars, allowEmpty: true);
      final created = _millis(row['createdAtMs'])!;
      final updated = _millis(row['updatedAtMs'])!;
      _millis(row['eventAtMs'], nullable: true, historical: true);
      final deleted = _millis(row['deletedAtMs'], nullable: true);
      if (updated < created || (deleted != null && deleted < created)) {
        throw const ProductSnapshotRejected();
      }
      final version = row['version'];
      if (version is! int || version < 1 ||
          version > maxRevisions + 1) {
        throw const ProductSnapshotRejected();
      }
      entryVersions[id] = version;
      entryDates[id] = (created, updated);
      revisionVersions[id] = <int>{};
    }

    for (final row in revisions) {
      _keys(row, {
        'entryId', 'version', 'journalId', 'title', 'body',
        'eventAtMs', 'updatedAtMs',
      });
      final entryId = _id(row['entryId']);
      final journalId = _id(row['journalId']);
      if (!entryVersions.containsKey(entryId) ||
          !journalIds.contains(journalId)) {
        throw const ProductSnapshotRejected();
      }
      _string(row['title'], maxTextChars, allowEmpty: true);
      _string(row['body'], maxTextChars, allowEmpty: true);
      _millis(row['eventAtMs'], nullable: true, historical: true);
      final at = _millis(row['updatedAtMs'])!;
      final dates = entryDates[entryId]!;
      if (at < dates.$1 || at > dates.$2) {
        throw const ProductSnapshotRejected();
      }
      final version = row['version'];
      if (version is! int || version < 1 ||
          version >= entryVersions[entryId]! ||
          !revisionVersions[entryId]!.add(version)) {
        throw const ProductSnapshotRejected();
      }
    }
    for (final item in entryVersions.entries) {
      final history = revisionVersions[item.key]!;
      if (history.length != item.value - 1) {
        throw const ProductSnapshotRejected();
      }
      for (var v = 1; v < item.value; v++) {
        if (!history.contains(v)) throw const ProductSnapshotRejected();
      }
    }

    for (final row in media) {
      _keys(row, {
        'id', 'entryId', 'name', 'mime', 'data', 'sha256',
      });
      final id = _id(row['id']);
      if (!mediaIds.add(id) ||
          !entryVersions.containsKey(_id(row['entryId']))) {
        throw const ProductSnapshotRejected();
      }
      final name = _string(row['name'], 160);
      if (name.isEmpty || name == '.' || name == '..' ||
          name.contains('/') || name.contains('\\') ||
          name.runes.any((v) => v < 32 || v == 127)) {
        throw const ProductSnapshotRejected();
      }
      final mime = _string(row['mime'], 128);
      if (!RegExp(r'^[a-zA-Z0-9.+_-]+/[a-zA-Z0-9.+_-]+$')
          .hasMatch(mime)) {
        throw const ProductSnapshotRejected();
      }
      final bytes = _base64(_string(row['data'], maxPayloadBytes * 2,
          allowEmpty: true));
      if (bytes.length > maxMediaBytes) {
        throw const ProductSnapshotRejected();
      }
      final expected = _base64(_string(row['sha256'], 60));
      if (expected.length != 32 ||
          !_equalBytes(expected, (await _digest.hash(bytes)).bytes)) {
        throw const ProductSnapshotRejected();
      }
    }
  }

  static bool _equalBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static void _keys(Map<String, dynamic> row, Set<String> required) {
    if (row.length != required.length ||
        !row.keys.toSet().containsAll(required)) {
      throw const ProductSnapshotRejected();
    }
  }

  static List<Map<String, dynamic>> _rows(Object? input, int max) {
    if (input is! List || input.length > max) {
      throw const ProductSnapshotRejected();
    }
    return [
      for (final value in input)
        if (value is Map<String, dynamic>)
          value
        else
          throw const ProductSnapshotRejected(),
    ];
  }

  static String _id(Object? input) {
    if (input is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(input)) {
      throw const ProductSnapshotRejected();
    }
    return input;
  }

  static String _string(Object? input, int max, {bool allowEmpty = false}) {
    if (input is! String ||
        input.runes.length > max ||
        (!allowEmpty && input.isEmpty)) {
      throw const ProductSnapshotRejected();
    }
    return input;
  }

  static int? _millis(Object? input, {
    bool nullable = false,
    bool historical = false,
  }) {
    if (nullable && input == null) return null;
    if (input is! int ||
        input.abs() > 8640000000000000 ||
        (!historical && input < 0)) {
      throw const ProductSnapshotRejected();
    }
    return input;
  }

  static Uint8List _base64(String input) {
    try {
      final value = base64Decode(input);
      if (base64Encode(value) != input) {
        throw const ProductSnapshotRejected();
      }
      return Uint8List.fromList(value);
    } catch (_) {
      throw const ProductSnapshotRejected();
    }
  }
}
