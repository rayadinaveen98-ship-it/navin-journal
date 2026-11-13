// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
/// A3.4 — Android force-stop/relaunch proof. Debug-only, fictional data.
///
/// This is a separate APK entrypoint and is NOT the Navin Journal app.
/// ADB starts this app three times with a different test phase. Between
/// phases, ADB really force-stops the Android application process. The same
/// app-private encrypted DB, authenticated envelope and AndroidKeyStore alias
/// must survive. Never use this harness for actual private diaries.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_autosave_spike/encrypted_isolate_store.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'android_key_bridge.dart';

const _diagnostic = MethodChannel('navin_journal/test_lifecycle_v1');
const _entryId = 'fictional-a3-4-entry';
const _first = DraftContent(
  title: 'Fictional first memory',
  body: 'ఈ రోజు ప్రశాంతంగా ఉంది. A3_4_ANDROID_TEST_ONLY_VERSION_1 🌿',
);
const _second = DraftContent(
  title: 'Fictional second memory',
  body: 'ఇది రెండవ జ్ఞాపకం. A3_4_ANDROID_TEST_ONLY_VERSION_2 🪷',
);

// Keep the worker open until Android force-stops the actual process, rather
// than closing it cleanly as if this were a simulated app restart.
EncryptedIsolateStore? _liveWorker;

Future<EncryptedIsolateStore> _open(
  KeyEnvelopeCoordinator coordinator,
  String filename, {
  required bool create,
}) async {
  final bytes = create
      ? await coordinator.initialize(databasePath: filename)
      : await coordinator.unlock(databasePath: filename);
  final key = TestVaultKey.fromBytes(bytes);
  bytes.fillRange(0, bytes.length, 0);
  try {
    return await EncryptedIsolateStore.open(filename, key: key, create: create);
  } finally {
    key.destroy();
  }
}

Future<void> _executeForceStopPhase() async {
  try {
    final root = await _diagnostic.invokeMethod<String>('getPrivateRoot');
    final phase = await _diagnostic.invokeMethod<String>('getStartPhase');
    if (root == null || root.isEmpty || phase == null || phase.isEmpty) {
      throw StateError('Test launch phase or private root unavailable');
    }
    final dir = Directory(root + Platform.pathSeparator + 'nj_a3_4_fixture');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = dir.path + Platform.pathSeparator + 'encrypted.sqlite3';
    final envelope = File(
      dir.path + Platform.pathSeparator + 'device-key-envelope.json',
    );
    final coordinator = KeyEnvelopeCoordinator(
      envelopeFile: envelope,
      protector: FlutterAndroidKeyProtector(),
    );

    switch (phase) {
      case 'write_v1':
        // First run must create the vault exactly once. No silent reset on
        // duplicate launches or missing/mismatched key material.
        if (File(file).existsSync() || envelope.existsSync()) {
          throw StateError('Refusing to reset existing encrypted test fixture');
        }
        _liveWorker = await _open(coordinator, file, create: true);
        final result = await _liveWorker!.commit(
          entryId: _entryId,
          expectedVersion: 0,
          content: _first,
        );
        if (result.version != 1 ||
            (await _liveWorker!.read(_entryId))?.content != _first ||
            !(await _liveWorker!.integrityCheck())) {
          throw StateError('First fictional encrypted commit not verified');
        }
        await _diagnostic.invokeMethod<void>(
          'markPhase',
          {'marker': 'ACK_V1'},
        );
      case 'reopen_and_write_v2':
        // New Android process, same app-private file and original Keystore
        // alias. Verify acknowledged v1 BEFORE writing a second version.
        _liveWorker = await _open(coordinator, file, create: false);
        final original = await _liveWorker!.read(_entryId);
        if (original?.version != 1 ||
            original?.content != _first ||
            !(await _liveWorker!.integrityCheck())) {
          throw StateError('Acknowledged first version not recovered');
        }
        final result = await _liveWorker!.commit(
          entryId: _entryId,
          expectedVersion: 1,
          content: _second,
        );
        if (result.version != 2 ||
            (await _liveWorker!.read(_entryId))?.content != _second) {
          throw StateError('Second fictional commit not verified');
        }
        await _diagnostic.invokeMethod<void>(
          'markPhase',
          {'marker': 'ACK_V2'},
        );
      case 'reopen_v2':
        _liveWorker = await _open(coordinator, file, create: false);
        final restored = await _liveWorker!.read(_entryId);
        if (restored?.version != 2 ||
            restored?.content != _second ||
            !(await _liveWorker!.integrityCheck())) {
          throw StateError('Acknowledged second version not recovered');
        }
        await _diagnostic.invokeMethod<void>(
          'markPhase',
          {'marker': 'RECOVERED_V2'},
        );
      default:
        throw StateError('Unknown ADB test phase');
    }
  } catch (_) {
    // Strictly code-only status. Never print journal text, key bytes, path,
    // native stack traces, or encryption metadata to CI/device logs.
    try {
      await _diagnostic.invokeMethod<void>(
        'markPhase',
        {'marker': 'FAILED'},
      );
    } catch (_) {
      // If reporting fails, external CI timeout still fails closed.
    }
  }
}

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Cannot run A3.4 diagnostic as a release application');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('A3.4 · Fictional encrypted recovery test ONLY'),
      ),
    ),
  ));
  unawaited(_executeForceStopPhase());
}
