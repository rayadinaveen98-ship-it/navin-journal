/// A2.2 DESIGN SPIKE — NOT A PRODUCTION DEVICE KEY STORE.
///
/// The provider interface must eventually be implemented with Android
/// Keystore / Apple Keychain, and validated on real devices. The Linux
/// test double is software-only and MUST NOT protect actual journal data.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

abstract interface class DeviceKeyProtector {
  /// Create a distinct, non-exportable wrapping key. Never replace an alias.
  Future<void> provision(String alias);

  /// AES-GCM with new random nonce and bound authenticated context.
  Future<WrappedSecret> wrap(
      String alias, Uint8List dataKey, Uint8List aad);

  /// Never create/recreate a missing alias on unwrap.
  Future<Uint8List> unwrap(
      String alias, WrappedSecret wrapped, Uint8List aad);

  /// Delete only after a durable new envelope is verified and committed.
  Future<void> retire(String alias);
}

class MissingVaultKey implements Exception {
  final String reason;
  const MissingVaultKey(this.reason);
  @override
  String toString() => 'MissingVaultKey: ' + reason;
}

class BrokenEnvelope implements Exception {
  const BrokenEnvelope();
  @override
  String toString() => 'BrokenEnvelope';
}

class WrappedSecret {
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> tag;
  const WrappedSecret(this.nonce, this.ciphertext, this.tag);

  Map<String, Object> toJson() => {
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(ciphertext),
        'tag': base64Encode(tag),
      };

  factory WrappedSecret.fromJson(Object? source) {
    if (source is! Map<String, dynamic>) throw const BrokenEnvelope();
    List<int> decode(String key, int requiredLength) {
      final value = source[key];
      if (value is! String) throw const BrokenEnvelope();
      try {
        final bytes = base64Decode(value);
        if (bytes.length != requiredLength) throw const BrokenEnvelope();
        return bytes;
      } on FormatException {
        throw const BrokenEnvelope();
      }
    }

    return WrappedSecret(
        decode('nonce', 12), decode('ciphertext', 32), decode('tag', 16));
  }
}

class EnvelopeSlot {
  final String alias;
  final int generation;
  final WrappedSecret wrapped;
  const EnvelopeSlot(this.alias, this.generation, this.wrapped);

  Map<String, Object> toJson() => {
        'alias': alias,
        'generation': generation,
        'wrapped': wrapped.toJson(),
      };

  factory EnvelopeSlot.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) throw const BrokenEnvelope();
    final alias = raw['alias'];
    final version = raw['generation'];
    if (alias is! String || version is! int || version < 1) {
      throw const BrokenEnvelope();
    }
    return EnvelopeSlot(
        alias, version, WrappedSecret.fromJson(raw['wrapped']));
  }
}

class EnvelopeDocument {
  final String vaultId;
  final String activeAlias;
  final List<EnvelopeSlot> slots;
  const EnvelopeDocument(this.vaultId, this.activeAlias, this.slots);

  EnvelopeSlot get active =>
      slots.singleWhere((s) => s.alias == activeAlias);

  int get generation => slots.map((s) => s.generation).reduce(max);

  Map<String, Object> toJson() => {
        'schema': 1,
        'vault': vaultId,
        'active': activeAlias,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory EnvelopeDocument.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic> || raw['schema'] != 1 ||
        raw['vault'] is! String || raw['active'] is! String ||
        raw['slots'] is! List) throw const BrokenEnvelope();
    final id = raw['vault'] as String;
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
      throw const BrokenEnvelope();
    }
    final slots = (raw['slots'] as List)
        .map(EnvelopeSlot.fromJson)
        .toList(growable: false);
    if (slots.isEmpty || slots.length > 2) throw const BrokenEnvelope();
    final aliases = slots.map((s) => s.alias).toSet();
    final versions = slots.map((s) => s.generation).toSet();
    if (aliases.length != slots.length || versions.length != slots.length ||
        !aliases.contains(raw['active']) ||
        slots.any((s) =>
            !s.alias.startsWith('nj-v1-' + id + '-g') ||
            s.alias != ('nj-v1-' + id + '-g' + s.generation.toString()))) {
      throw const BrokenEnvelope();
    }
    return EnvelopeDocument(id, raw['active'] as String, slots);
  }
}

/// Re-wraps a 32-byte database key, without rekeying database pages.
///
/// Linux file rename is atomic in the tested filesystem, but this code does
/// NOT fsync the directory, coordinate multiple writers, verify Android power
/// failure, or provide independent passphrase-based archive recovery.
class KeyEnvelopeCoordinator {
  final File envelopeFile;
  final DeviceKeyProtector protector;
  final void Function(String point)? injectFailure;

  const KeyEnvelopeCoordinator({
    required this.envelopeFile,
    required this.protector,
    this.injectFailure,
  });

  String _newVaultId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _context(String vault, EnvelopeSlot slot) =>
      Uint8List.fromList(utf8.encode(
          'navin-envelope-v1|' + vault + '|' + slot.alias + '|' +
          slot.generation.toString()));

  Future<EnvelopeDocument> readEnvelope() async {
    if (!await envelopeFile.exists()) {
      throw const MissingVaultKey('No envelope. Never auto-reset a vault');
    }
    try {
      return EnvelopeDocument.fromJson(
          jsonDecode(await envelopeFile.readAsString()));
    } on FormatException {
      throw const BrokenEnvelope();
    } on TypeError {
      throw const BrokenEnvelope();
    }
  }

  Future<void> _write(EnvelopeDocument document) async {
    await envelopeFile.parent.create(recursive: true);
    final temp = File(envelopeFile.path + '.tmp');
    // Envelope contains authenticated ciphertext ONLY. No raw DEK on disk.
    await temp.writeAsString(jsonEncode(document.toJson()), flush: true);
    injectFailure?.call('before_envelope_rename');
    await temp.rename(envelopeFile.path);
  }

  /// Generates random DEK only for a fresh vault with no existing database.
  ///
  /// Caller MUST create encrypted SQLite vault immediately. If creation fails,
  /// the envelope intentionally remains, to avoid silent overwrite/rekey.
  Future<Uint8List> initialize({required String databasePath}) async {
    if (await envelopeFile.exists() || await File(databasePath).exists()) {
      throw StateError('Existing vault/envelope: refusing reinitialization');
    }
    final vaultId = _newVaultId();
    final alias = 'nj-v1-' + vaultId + '-g1';
    final rng = Random.secure();
    final dek = Uint8List.fromList(
        List<int>.generate(32, (_) => rng.nextInt(256)));
    try {
      await protector.provision(alias);
      final dummy = EnvelopeSlot(alias, 1, const WrappedSecret([], [], []));
      final wrapped = await protector.wrap(alias, dek, _context(vaultId, dummy));
      injectFailure?.call('after_first_wrap');
      await _write(EnvelopeDocument(
          vaultId, alias, [EnvelopeSlot(alias, 1, wrapped)]));
      return Uint8List.fromList(dek);
    } finally {
      dek.fillRange(0, dek.length, 0);
    }
  }

  Future<Uint8List> unlock({required String databasePath}) async {
    if (!await File(databasePath).exists()) {
      throw const MissingVaultKey('Database missing: no silent creation');
    }
    final document = await readEnvelope();
    final active = document.active;
    try {
      final bytes = await protector.unwrap(active.alias, active.wrapped,
          _context(document.vaultId, active));
      if (bytes.length != 32) {
        throw const MissingVaultKey('Unexpected unwrapped key size');
      }
      return bytes;
    } catch (_) {
      throw const MissingVaultKey(
          'Device key unavailable or envelope authentication failed');
    }
  }

  /// Stage -> verify -> promote. Old slot remains available for crash
  /// recovery until finalizeRotation explicitly removes it.
  Future<void> rotateWrappingKey({required String databasePath}) async {
    final initial = await readEnvelope();
    if (initial.slots.length != 1) {
      throw StateError('Finish/resume existing rotation before starting new');
    }
    final dek = await unlock(databasePath: databasePath);
    try {
      final gen = initial.generation + 1;
      final alias = 'nj-v1-' + initial.vaultId + '-g' + gen.toString();
      await protector.provision(alias);
      injectFailure?.call('after_new_alias');
      final empty = EnvelopeSlot(alias, gen, const WrappedSecret([], [], []));
      final wrapped = await protector.wrap(
          alias, dek, _context(initial.vaultId, empty));
      final newSlot = EnvelopeSlot(alias, gen, wrapped);
      final twoSlots = [...initial.slots, newSlot];
      await _write(EnvelopeDocument(
          initial.vaultId, initial.activeAlias, twoSlots));
      injectFailure?.call('after_stage_write');

      final tested = await protector.unwrap(
          alias, wrapped, _context(initial.vaultId, newSlot));
      final equal = _same(dek, tested);
      tested.fillRange(0, tested.length, 0);
      if (!equal) throw const MissingVaultKey('New wrapped DEK mismatch');

      await _write(EnvelopeDocument(initial.vaultId, alias, twoSlots));
      injectFailure?.call('after_primary_promote');
    } finally {
      dek.fillRange(0, dek.length, 0);
    }
  }

  Future<void> resumeRotation({required String databasePath}) async {
    final document = await readEnvelope();
    if (document.slots.length != 2) {
      throw StateError('No pending rotation to resume');
    }
    final newest = document.slots.reduce(
        (a, b) => a.generation > b.generation ? a : b);
    if (document.activeAlias == newest.alias) return;
    final old = await unlock(databasePath: databasePath);
    try {
      final next = await protector.unwrap(
          newest.alias, newest.wrapped, _context(document.vaultId, newest));
      final equal = _same(old, next);
      next.fillRange(0, next.length, 0);
      if (!equal) throw const MissingVaultKey('Staged DEK did not match');
      await _write(EnvelopeDocument(
          document.vaultId, newest.alias, document.slots));
    } finally {
      old.fillRange(0, old.length, 0);
    }
  }

  /// Commit one new slot before retiring the previous KEK.
  /// Crash after commit can orphan an alias, but must not lose the vault key.
  Future<void> finalizeRotation({required String databasePath}) async {
    final document = await readEnvelope();
    if (document.slots.length != 2) {
      throw StateError('No rotation to finalize');
    }
    final newest = document.slots.reduce(
        (a, b) => a.generation > b.generation ? a : b);
    if (document.activeAlias != newest.alias) {
      throw StateError('Cannot retire before promoting newest wrapping key');
    }
    final checked = await unlock(databasePath: databasePath);
    checked.fillRange(0, checked.length, 0);
    final obsolete = document.slots.singleWhere(
        (s) => s.alias != newest.alias);
    await _write(EnvelopeDocument(
        document.vaultId, newest.alias, [newest]));
    injectFailure?.call('after_remove_old_slot');
    await protector.retire(obsolete.alias);
  }

  bool _same(Uint8List a, Uint8List b) {
    var result = a.length ^ b.length;
    for (var i = 0; i < min(a.length, b.length); i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
