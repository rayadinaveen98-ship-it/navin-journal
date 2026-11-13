import 'dart:convert';
import 'dart:typed_data';

import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:test/test.dart';

void main() {
  late RecoveryArchiveCodec codec;
  late RecoveryKey recoveryKey;

  const fictional = PortableEntry(
    id: 'fict-a',
    title: 'నాకు ఒక చిన్న కల ఉంది',
    body: 'Fictional Telugu + English 🪷 — not a private diary.',
  );

  PortableAttachment sampleMedia() => PortableAttachment(
        id: 'image-1',
        name: 'fictional-flower.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );

  Future<Uint8List> sampleArchive() => codec.export(
        key: recoveryKey,
        entries: [fictional],
        attachments: [sampleMedia()],
        createdAtUtc: DateTime.utc(2026, 11, 13, 12, 0),
      );

  setUp(() {
    codec = RecoveryArchiveCodec();
    recoveryKey = RecoveryKey.random();
  });
  tearDown(() => recoveryKey.destroy());

  test('portable offline recovery key roundtrips exactly as 256 bits', () {
    final external = recoveryKey.exportForOfflineStorage();
    expect(external, hasLength(43));
    expect(RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(external), isTrue);
    final restored = RecoveryKey.parse(external);
    try {
      expect(restored.exportForOfflineStorage(), external);
    } finally {
      restored.destroy();
    }
  });

  test('independent recovery key decrypts entries/media in new object',
      () async {
    final cipher = await sampleArchive();
    final external = recoveryKey.exportForOfflineStorage();
    final importedKey = RecoveryKey.parse(external);
    try {
      final inspect = await RecoveryArchiveCodec().verify(
        key: importedKey,
        archive: cipher,
      );
      expect(inspect.createdAtUtc, DateTime.utc(2026, 11, 13, 12));
      expect(inspect.entries, [fictional]);
      expect(inspect.attachments.single.name, 'fictional-flower.png');
      expect(inspect.attachments.single.bytes,
          [137, 80, 78, 71, 13, 10, 26, 10]);
    } finally {
      importedKey.destroy();
    }
  });

  test('entire entry body and media filename are absent from archive bytes',
      () async {
    final bytes = await sampleArchive();
    final encoded = utf8.decode(bytes);
    expect(encoded, isNot(contains('Fictional Telugu')));
    expect(encoded, isNot(contains('fictional-flower.png')));
    expect(encoded, isNot(contains('fict-a')));
    expect(encoded, isNot(contains('image/png')));
    expect(encoded, contains('AES-256-GCM'));
  });

  test('a different recovery key cannot decrypt and exposes no plaintext',
      () async {
    final encoded = await sampleArchive();
    final wrong = RecoveryKey.random();
    try {
      await expectLater(
        codec.verify(key: wrong, archive: encoded),
        throwsA(isA<ArchiveRejected>()),
      );
    } finally {
      wrong.destroy();
    }
  });

  test('GCM tag tampering is rejected before content is returned', () async {
    final json = jsonDecode(utf8.decode(await sampleArchive())) as Map;
    final original = base64Decode(json['tag'] as String);
    original[0] ^= 1;
    json['tag'] = base64Encode(original);
    await expectLater(
      codec.verify(
        key: recoveryKey,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('ciphertext tampering is rejected', () async {
    final json = jsonDecode(utf8.decode(await sampleArchive())) as Map;
    final original = base64Decode(json['ciphertext'] as String);
    original[original.length ~/ 2] ^= 1;
    json['ciphertext'] = base64Encode(original);
    await expectLater(
      codec.verify(
        key: recoveryKey,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('nonce tampering is rejected', () async {
    final json = jsonDecode(utf8.decode(await sampleArchive())) as Map;
    final original = base64Decode(json['nonce'] as String);
    original[0] ^= 1;
    json['nonce'] = base64Encode(original);
    await expectLater(
      codec.verify(
        key: recoveryKey,
        archive: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('unknown archive version and algorithm are rejected', () async {
    final data = await sampleArchive();
    final original = jsonDecode(utf8.decode(data)) as Map;
    for (final pair in [
      ['format', 'NJR-RECOVERY-99'],
      ['algorithm', 'AES-128-CBC'],
    ]) {
      final changed = Map<String, dynamic>.from(original);
      changed[pair[0]] = pair[1];
      await expectLater(
        codec.verify(
          key: recoveryKey,
          archive: Uint8List.fromList(utf8.encode(jsonEncode(changed))),
        ),
        throwsA(isA<ArchiveRejected>()),
      );
    }
  });

  test('truncated, non-JSON and empty archives fail closed', () async {
    final full = await sampleArchive();
    for (final malformed in [
      Uint8List(0),
      Uint8List.fromList([0, 1, 2]),
      Uint8List.fromList(full.sublist(0, full.length ~/ 2)),
    ]) {
      await expectLater(
        codec.verify(key: recoveryKey, archive: malformed),
        throwsA(isA<ArchiveRejected>()),
      );
    }
  });

  test('each export has fresh authenticated encryption', () async {
    final a = await sampleArchive();
    final b = await sampleArchive();
    expect(a, isNot(b));
    final first = jsonDecode(utf8.decode(a)) as Map;
    final second = jsonDecode(utf8.decode(b)) as Map;
    expect(first['nonce'], isNot(second['nonce']));
    expect((await codec.verify(key: recoveryKey, archive: b)).entries,
        [fictional]);
  });

  test('duplicate stable entry IDs are refused before export', () async {
    await expectLater(
      codec.export(
        key: recoveryKey,
        entries: [fictional, fictional],
        attachments: [],
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('duplicate attachment IDs are refused before export', () async {
    await expectLater(
      codec.export(
        key: recoveryKey,
        entries: [fictional],
        attachments: [sampleMedia(), sampleMedia()],
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('attachment filenames cannot escape a future restore directory',
      () async {
    for (final name in [
      '../escape',
      r'..\escape.jpg',
      '/absolute.png',
      'a/b.png',
      '.',
      '..',
      'control\u0000name.png',
    ]) {
      await expectLater(
        codec.export(
          key: recoveryKey,
          entries: [fictional],
          attachments: [
            PortableAttachment(
              id: 'media',
              name: name,
              mimeType: 'image/png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
        throwsA(isA<ArchiveRejected>()),
      );
    }
  });

  test('overlarge entry, count and media payloads fail before encryption',
      () async {
    final hugeText = PortableEntry(
      id: 'too-large',
      title: '',
      body: 'x' * 100001,
    );
    await expectLater(
      codec.export(
        key: recoveryKey,
        entries: [hugeText],
        attachments: [],
      ),
      throwsA(isA<ArchiveRejected>()),
    );
    await expectLater(
      codec.export(
        key: recoveryKey,
        entries: [
          for (var i = 0; i < 1001; i++)
            PortableEntry(id: 'fict-$i', title: '', body: ''),
        ],
        attachments: [],
      ),
      throwsA(isA<ArchiveRejected>()),
    );
    await expectLater(
      codec.export(
        key: recoveryKey,
        entries: [],
        attachments: [
          PortableAttachment(
            id: 'large',
            name: 'oversize.png',
            mimeType: 'image/png',
            bytes: Uint8List(2 * 1024 * 1024 + 1),
          ),
        ],
      ),
      throwsA(isA<ArchiveRejected>()),
    );
  });

  test('malformed external key and destroyed key fail closed', () async {
    for (final key in ['short', 'invalid!!', ' ' * 43]) {
      expect(() => RecoveryKey.parse(key), throwsA(isA<ArchiveRejected>()));
    }
    final other = RecoveryKey.random();
    other.destroy();
    expect(() => other.snapshot(), throwsStateError);
    await expectLater(
      codec.export(key: other, entries: [fictional], attachments: []),
      throwsStateError,
    );
  });

  test('archive verification cannot overwrite or mutate caller fixtures',
      () async {
    final encrypted = await sampleArchive();
    final before = fictional.body;
    final checked = await codec.verify(key: recoveryKey, archive: encrypted);
    expect(fictional.body, before);
    expect(() => checked.entries.add(fictional), throwsUnsupportedError);
    // This is VERIFY-ONLY; there is intentionally no restore writer API.
  });
}
