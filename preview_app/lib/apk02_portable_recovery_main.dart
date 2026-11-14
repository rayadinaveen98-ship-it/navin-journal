// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings
/// APK02 PORTABLE clean-install recovery diagnostic. FICTIONAL DATA ONLY.
///
/// Three Android launch phases selected by ADB test intent:
///   export_fixture      - encrypted source vault -> portable archive + key
///   reject_wrong_key    - new install must reject wrong key without writing
///   restore_fixture     - independently keyed vault, fresh Android Keystore
///   reopen_fixture      - same restored vault after Android force-stop
///
/// The host test retrieves archive + separate secret outside the app sandbox,
/// uninstalls this entire diagnostic package, reinstalls, and only then
/// imports. There is no personal text input, app UI recovery or private beta.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/portable_recovery_worker.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

const channel = MethodChannel('navin_journal/test_lifecycle_v1');
const firstTitle = 'Imaginary portable page';
const firstBody = 'Fictional diary from the first device · తెలుగు 🌿';
const revisedTitle = 'Imaginary portable page revisited';
const revisedBody = 'Fictional revised memory after moving devices · 🪷';

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Portable recovery diagnostic may not run in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PortableRecoveryDiagnosticApp());
}

class PortableRecoveryDiagnosticApp extends StatefulWidget {
  const PortableRecoveryDiagnosticApp({super.key});
  @override
  State<PortableRecoveryDiagnosticApp> createState() =>
      _PortableRecoveryDiagnosticAppState();
}

class _PortableRecoveryDiagnosticAppState
    extends State<PortableRecoveryDiagnosticApp> {
  String _message = 'Inspecting fictional recovery fixture…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _marker(String status) async =>
      channel.invokeMethod<void>('markPhase', {'marker': status});

  Future<void> _run() async {
    try {
      final root = await channel.invokeMethod<String>('getPrivateRoot');
      final phase = await channel.invokeMethod<String>('getStartPhase');
      if (root == null || root.trim().isEmpty || phase == null) {
        throw StateError('Invalid disposable app fixture');
      }
      switch (phase) {
        case 'export_fixture':
          await _exportFixture(Directory(root));
          await _marker('PORTABLE_EXPORT_READY');
        case 'reject_wrong_key':
          await _rejectWrongKey(Directory(root));
          await _marker('PORTABLE_WRONG_KEY');
        case 'restore_fixture':
          await _restoreFixture(Directory(root));
          await _marker('PORTABLE_RESTORE_OK');
        case 'reopen_fixture':
          await _reopenFixture(Directory(root));
          await _marker('PORTABLE_REOPEN_OK');
        default:
          throw StateError('Unknown test phase');
      }
      if (mounted) {
        setState(() => _message =
            'Fictional diagnostic succeeded. Private writing is disabled.');
      }
    } catch (_) {
      _failed = true;
      try {
        await _marker('FAILED');
      } catch (_) {
        // If even the native test bridge has failed, the host times out.
      }
      if (mounted) setState(() => _message =
          'Fictional recovery validation failed. No user data was imported.');
    }
  }

  static KeyEnvelopeCoordinator _envelope(File path) =>
      KeyEnvelopeCoordinator(
        envelopeFile: path,
        protector: FlutterAndroidKeyProtector(),
      );

  static Future<TestVaultKey> _newDeviceKey(
    KeyEnvelopeCoordinator coordinator,
    String databasePath,
  ) async {
    final bytes = await coordinator.initialize(databasePath: databasePath);
    try {
      return TestVaultKey.fromBytes(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  static Future<TestVaultKey> _unlockDeviceKey(
    KeyEnvelopeCoordinator coordinator,
    String databasePath,
  ) async {
    final bytes = await coordinator.unlock(databasePath: databasePath);
    try {
      return TestVaultKey.fromBytes(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> _exportFixture(Directory privateRoot) async {
    final original = Directory(privateRoot.path + '/portable-source-only');
    final db = File(original.path + '/journal.sqlite3');
    final envelope = File(original.path + '/envelope.json');
    final archiveFile = File(privateRoot.path + '/portable_export.njr');
    final keyFile = File(privateRoot.path + '/portable_export.key');
    if (original.existsSync() || archiveFile.existsSync() ||
        keyFile.existsSync()) {
      throw StateError('Source fixture already exists; refuse reset');
    }
    original.createSync(recursive: true);
    final dbKey = await _newDeviceKey(_envelope(envelope), db.path);
    JournalEditorWorker? worker;
    final recovery = RecoveryKey.random();
    try {
      worker = await JournalEditorWorker.open(
        db.path, key: dbKey, create: true);
      final journal = await worker.createJournal('Fictional Portable Pages');
      final first = await worker.startSession(
        journalId: journal, debounce: const Duration(days: 1));
      first.controller.update(title: firstTitle, body: firstBody);
      await first.save();
      if (first.indicator.phase != SavePhase.saved ||
          first.indicator.databaseVersion != 1) {
        throw StateError('Fictional original version not committed');
      }
      final entryId = await first.persistedEntryId();
      if (entryId == null || !(await first.closeSafely())) {
        throw StateError('Fictional original page not closed safely');
      }
      final second = await worker.startSession(
        journalId: journal, existingEntryId: entryId,
        debounce: const Duration(days: 1));
      second.controller.update(title: revisedTitle, body: revisedBody);
      await second.save();
      if (second.indicator.phase != SavePhase.saved ||
          second.indicator.databaseVersion != 2 ||
          !(await second.closeSafely())) {
        throw StateError('Fictional historical revision not committed');
      }

      final archive = await worker.exportRecoveryArchive(recovery);
      try {
        final decoded = await ProductEncryptedArchiveCodec().verify(
          recoveryKey: recovery, archive: archive);
        if ((decoded['entries'] as List).length != 1 ||
            (decoded['revisions'] as List).length != 1 ||
            (decoded['journals'] as List).length != 1) {
          throw StateError('Exported archive mismatch');
        }
        await archiveFile.writeAsBytes(archive, flush: true);
        // Explicitly fictional test-only. Host pulls this OFF the app BEFORE
        // uninstall, then reinjects it into the fresh sandbox to simulate
        // a separately retained offline recovery key. Not consumer UX.
        await keyFile.writeAsString(
          recovery.exportForOfflineStorage(), flush: true);
      } finally {
        archive.fillRange(0, archive.length, 0);
      }
    } finally {
      await worker?.close();
      dbKey.destroy();
      recovery.destroy();
    }
  }

  Future<void> _rejectWrongKey(Directory privateRoot) async {
    final archive = File(privateRoot.path + '/portable_import.njr');
    final wrongFile = File(privateRoot.path + '/portable_wrong.key');
    final destination = Directory(privateRoot.path + '/portable-restored-vault');
    final envelope = File(privateRoot.path + '/portable-restored-envelope.json');
    if (!archive.existsSync() || !wrongFile.existsSync() ||
        destination.existsSync() || envelope.existsSync()) {
      throw StateError('Wrong-key test preconditions failed');
    }
    final wrong = RecoveryKey.parse((await wrongFile.readAsString()).trim());
    final bytes = await archive.readAsBytes();
    try {
      var rejected = false;
      try {
        await ProductEncryptedArchiveCodec().verify(
          recoveryKey: wrong, archive: bytes);
      } on ArchiveRejected {
        rejected = true;
      }
      if (!rejected || destination.existsSync() || envelope.existsSync()) {
        throw StateError('Wrong recovery key did not fail closed');
      }
    } finally {
      wrong.destroy();
      bytes.fillRange(0, bytes.length, 0);
      await wrongFile.delete();
    }
  }

  Future<void> _restoreFixture(Directory privateRoot) async {
    final archiveFile = File(privateRoot.path + '/portable_import.njr');
    final keyFile = File(privateRoot.path + '/portable_import.key');
    final destination = Directory(privateRoot.path + '/portable-restored-vault');
    // Envelope outside the ABSENT destination, otherwise a staged import
    // would (correctly) refuse the already occupied destination directory.
    final envelopeFile =
        File(privateRoot.path + '/portable-restored-envelope.json');
    final dbPath = destination.path + '/journal.sqlite3';
    if (!archiveFile.existsSync() || !keyFile.existsSync() ||
        destination.existsSync() || envelopeFile.existsSync()) {
      throw StateError('Clean restore preconditions failed');
    }
    final keyText = (await keyFile.readAsString()).trim();
    await keyFile.delete();
    final recovery = RecoveryKey.parse(keyText);
    final archive = await archiveFile.readAsBytes();
    TestVaultKey? deviceKey;
    try {
      // Authenticate/validate BEFORE provisioning any fresh Android key or
      // writing an encrypted staging directory.
      final verified = await ProductEncryptedArchiveCodec().verify(
        recoveryKey: recovery, archive: archive);
      if ((verified['journals'] as List).length != 1 ||
          (verified['entries'] as List).length != 1 ||
          (verified['revisions'] as List).length != 1) {
        throw StateError('Portable content unexpected');
      }
      deviceKey = await _newDeviceKey(
        _envelope(envelopeFile), dbPath);
      final receipt = await PortableRecoveryWorker.restoreToNewVault(
        encryptedArchive: archive,
        recoveryKey: recovery,
        destinationKey: deviceKey,
        destination: destination,
      );
      if (receipt.journals != 1 || receipt.entries != 1 ||
          receipt.revisions != 1) {
        throw StateError('Restored record counts differ');
      }
      await _verifyRestored(dbPath, deviceKey);
      await archiveFile.delete();
    } finally {
      recovery.destroy();
      archive.fillRange(0, archive.length, 0);
      deviceKey?.destroy();
    }
  }

  Future<void> _reopenFixture(Directory privateRoot) async {
    final destination = Directory(privateRoot.path + '/portable-restored-vault');
    final dbPath = destination.path + '/journal.sqlite3';
    final envelopeFile =
        File(privateRoot.path + '/portable-restored-envelope.json');
    if (!destination.existsSync() || !envelopeFile.existsSync() ||
        File(privateRoot.path + '/portable_import.key').existsSync()) {
      throw StateError('Previously restored vault/envelope missing');
    }
    final key = await _unlockDeviceKey(_envelope(envelopeFile), dbPath);
    try {
      await _verifyRestored(dbPath, key);
    } finally {
      key.destroy();
    }
  }

  Future<void> _verifyRestored(String databasePath, TestVaultKey key) async {
    final worker = await JournalEditorWorker.open(databasePath, key: key);
    try {
      if (!(await worker.integrityCheck())) {
        throw StateError('Restored encrypted store integrity failure');
      }
      final journals = await worker.listJournals();
      final entries = await worker.listEntries(includeTrash: true);
      if (journals.length != 1 ||
          journals.single['name'] != 'Fictional Portable Pages' ||
          entries.length != 1 ||
          entries.single['version'] != 2 ||
          entries.single['title'] != revisedTitle ||
          entries.single['body'] != revisedBody) {
        throw StateError('Restored fictional current entry mismatch');
      }
      final history = await worker.readRevisions(entries.single['id'] as String);
      if (history.length != 1 || history.single['version'] != 1 ||
          history.single['title'] != firstTitle ||
          history.single['body'] != firstBody) {
        throw StateError('Restored historical revision mismatch');
      }
    } finally {
      await worker.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.auto_stories_outlined, size: 42),
            const SizedBox(height: 16),
            const Text('Portable Recovery · Fictional Data Only',
              textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(_message, key: const ValueKey('portable-recovery-status'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _failed ? Colors.red : Colors.black87)),
            const SizedBox(height: 12),
            const Text('Not a real diary, backup UI or approved beta.',
              textAlign: TextAlign.center),
          ]),
        ))),
      ),
    );
  }
}
