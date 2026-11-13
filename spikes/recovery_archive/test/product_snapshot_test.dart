/// A4.3.1 logical product archive contract tests — FICTIONAL DATA ONLY.
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:navin_journal_recovery_archive_spike/product_snapshot.dart';
import 'package:test/test.dart';

final codec = ProductSnapshotCodec();

Future<Map<String, dynamic>> fictionalSnapshot() async {
  const media = [0, 1, 2, 3, 128, 255];
  final digest = await Sha256().hash(media);
  return {
    'format': ProductSnapshotCodec.format,
    'exportedAtUtc': DateTime.utc(2026, 11, 13).toIso8601String(),
    'journals': [
      {
        'id': 'home', 'name': 'నా జ్ఞాపకాలు', 'archived': false,
        'createdAtMs': 1700000000000, 'deletedAtMs': null,
      },
      {
        'id': 'old', 'name': 'Past Seasons', 'archived': true,
        'createdAtMs': 1700000000000, 'deletedAtMs': 1800000000000,
      },
    ],
    'entries': [
      {
        'id': 'entry01', 'journalId': 'home',
        'title': 'ఒక రోజు 🪷', 'body': 'Today, a small story. తెలుగు!',
        'createdAtMs': 1700000000000, 'updatedAtMs': 1700000003000,
        'eventAtMs': 1650000000000, 'version': 2, 'deletedAtMs': null,
      },
      {
        'id': 'trashed01', 'journalId': 'old', 'title': 'Past',
        'body': 'An old fictional entry', 'createdAtMs': 1700000000000,
        'updatedAtMs': 1700000001000, 'eventAtMs': null,
        'version': 1, 'deletedAtMs': 1800000000000,
      },
    ],
    'revisions': [
      {
        'entryId': 'entry01', 'journalId': 'old', 'version': 1,
        'title': 'మొదటి పేజీ', 'body': 'Before moving journals',
        'eventAtMs': null, 'updatedAtMs': 1700000001000,
      },
    ],
    'attachments': [
      {
        'id': 'media01', 'entryId': 'entry01', 'name': 'photo.png',
        'mime': 'image/png', 'data': base64Encode(media),
        'sha256': base64Encode(digest.bytes),
      },
    ],
  };
}

Map<String, dynamic> copySnapshot(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

Future<void> mustReject(Map<String, dynamic> source) async {
  await expectLater(
    codec.encode(source), throwsA(isA<ProductSnapshotRejected>()),
  );
}

void main() {
  test('full logical schema preserves Telugu, versions, journal moves, Trash and media', () async {
    final input = await fictionalSnapshot();
    final encoded = await codec.encode(input);
    final verified = await codec.decode(encoded);
    expect(verified, input);
    expect(verified['entries'][0]['title'], 'ఒక రోజు 🪷');
    expect(verified['entries'][1]['deletedAtMs'], 1800000000000);
    expect(verified['journals'][1]['archived'], true);
    expect(verified['revisions'][0]['journalId'], 'old');
    expect(verified['attachments'][0]['entryId'], 'entry01');
  });

  test('rejects truncated payload without writing anything', () async {
    final valid = await codec.encode(await fictionalSnapshot());
    await expectLater(
      codec.decode(Uint8List.sublistView(valid, 0, valid.length - 6)),
      throwsA(isA<ProductSnapshotRejected>()),
    );
  });

  test('missing entry journal reference is rejected', () async {
    final s = await fictionalSnapshot();
    s['entries'][0]['journalId'] = 'missing';
    await mustReject(s);
  });

  test('missing historical journal reference is rejected', () async {
    final s = await fictionalSnapshot();
    s['revisions'][0]['journalId'] = 'unknown';
    await mustReject(s);
  });

  test('entry revision history must be continuous and complete', () async {
    final s = await fictionalSnapshot();
    s['entries'][0]['version'] = 3;
    await mustReject(s);
    final t = await fictionalSnapshot();
    t['revisions'][0]['version'] = 2;
    await mustReject(t);
  });

  test('a duplicate historical version is rejected', () async {
    final s = await fictionalSnapshot();
    s['entries'][0]['version'] = 3;
    s['revisions'].add(copySnapshot(s)['revisions'][0]);
    await mustReject(s);
  });

  test('a duplicate journal ID is rejected', () async {
    final s = await fictionalSnapshot();
    s['journals'].add(copySnapshot(s)['journals'][0]);
    await mustReject(s);
  });

  test('duplicate entry IDs are rejected even across Trash state', () async {
    final s = await fictionalSnapshot();
    s['entries'][1]['id'] = 'entry01';
    await mustReject(s);
  });

  test('attachment orphan cannot be smuggled into restore', () async {
    final s = await fictionalSnapshot();
    s['attachments'][0]['entryId'] = 'absent';
    await mustReject(s);
  });

  test('attachment bytes and SHA digest mismatch are rejected', () async {
    final s = await fictionalSnapshot();
    s['attachments'][0]['data'] = base64Encode([0, 1, 2, 3, 128, 254]);
    await mustReject(s);
  });

  test('attachment pathname traversal is rejected', () async {
    for (final name in ['../escape.png', r'..\escape.png', '/root', '.', '..']) {
      final s = await fictionalSnapshot();
      s['attachments'][0]['name'] = name;
      await mustReject(s);
    }
  });

  test('unknown format and unrecognized fields fail closed', () async {
    final s = await fictionalSnapshot();
    s['format'] = 'NJR-PRODUCT-SNAPSHOT-99';
    await mustReject(s);
    final t = await fictionalSnapshot();
    t['entries'][0]['undocumentedField'] = true;
    await mustReject(t);
  });

  test('wrong types, impossible timestamps and invalid versions rejected', () async {
    final a = await fictionalSnapshot();
    a['journals'][0]['archived'] = 1;
    await mustReject(a);
    final b = await fictionalSnapshot();
    b['entries'][0]['updatedAtMs'] = 1699999999000;
    await mustReject(b);
    final c = await fictionalSnapshot();
    c['entries'][0]['version'] = 0;
    await mustReject(c);
  });

  test('payload cannot exceed test-only bounded capacity', () async {
    final s = await fictionalSnapshot();
    for (var i = 0; i < 1001; i++) {
      s['entries'].add({
        'id': 'fake' + i.toString(), 'journalId': 'home',
        'title': '', 'body': 'test', 'createdAtMs': 1700000000000,
        'updatedAtMs': 1700000000000, 'eventAtMs': null,
        'version': 1, 'deletedAtMs': null,
      });
    }
    await mustReject(s);
  });

  test('single revision unchanged text still allowed for Trash version bump', () async {
    final s = await fictionalSnapshot();
    s['entries'][1]['version'] = 2;
    s['revisions'].add({
      'entryId': 'trashed01', 'journalId': 'old',
      'version': 1, 'title': 'Past', 'body': 'An old fictional entry',
      'eventAtMs': null, 'updatedAtMs': 1700000000000,
    });
    final value = await codec.decode(await codec.encode(s));
    expect(value['entries'][1]['deletedAtMs'], isNotNull);
    expect(value['revisions'].length, 2);
  });
}
