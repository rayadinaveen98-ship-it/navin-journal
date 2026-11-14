// ignore_for_file: deprecated_member_use
/// Stage 5B: disposable API34 Android DocumentsUI / SAF picker integration.
/// FICTIONAL ENCRYPTED DATA ONLY. NOT a private diary or production backup.
///
/// Uses the real native ACTION_CREATE_DOCUMENT/ACTION_OPEN_DOCUMENT channel,
/// while the host ADB script taps the *actual* Android document picker.
/// The independent 256-bit archive key never leaves this process or gets logged.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';

const _diagnostic = MethodChannel('navin_journal/test_lifecycle_v1');
const _picker = MethodChannel('navin_journal/fictional_export_v1');
const _titleV1 = 'Imagined SAF journal — version one';
const _bodyV1 = 'Fictional మాత్రమే · imagined Telugu page 🌿';
const _titleV2 = 'Imagined SAF journal — version two';
const _bodyV2 = 'Fictional మాత్రమే · a revised imaginary page 🪷';

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('SAF picker fixture is forbidden in release builds');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SafPickerProbe());
}

class _SafPickerProbe extends StatefulWidget {
  const _SafPickerProbe();

  @override
  State<_SafPickerProbe> createState() => _SafPickerProbeState();
}

class _SafPickerProbeState extends State<_SafPickerProbe> {
  String _notice = 'Starting fictional Android picker check…';

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _mark(String marker) =>
      _diagnostic.invokeMethod<void>('markPhase', {'marker': marker});

  /// The only archived content originates in a disposable native-Keystore
  /// encrypted journal with two fictional acknowledged versions. Nothing is
  /// written to an ordinary plaintext preferences store or to CI logs.
  Future<void> _withFictionalArchive(
    Directory root,
    Future<void> Function(Uint8List archive, RecoveryKey key) exercise, {
    void Function(String)? onCleanupStage,
  }) async {
    final folder = Directory('${root.path}/saf-scripted-source-v1');
    if (await FileSystemEntity.type(folder.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Refuse reuse of unknown fictional source');
    }
    await folder.create();
    final db = File('${folder.path}/journal.sqlite3');
    final envelope = File('${folder.path}/envelope.json');
    final wrapper = KeyEnvelopeCoordinator(
      envelopeFile: envelope,
      protector: FlutterAndroidKeyProtector(),
    );
    final deviceBytes = await wrapper.initialize(databasePath: db.path);
    TestVaultKey? dbKey;
    JournalEditorWorker? worker;
    Uint8List? archive;
    final recoveryKey = RecoveryKey.random();
    try {
      dbKey = TestVaultKey.fromBytes(deviceBytes);
      worker = await JournalEditorWorker.open(
        db.path, key: dbKey, create: true);
      final journalId = await worker.createJournal('Imaginary SAF Pages');
      final v1 = await worker.startSession(
        journalId: journalId, debounce: const Duration(days: 1));
      v1.controller.update(title: _titleV1, body: _bodyV1);
      await v1.save();
      if (v1.indicator.phase != SavePhase.saved ||
          v1.indicator.databaseVersion != 1) {
        throw StateError('Fictional v1 did not commit');
      }
      final entryId = await v1.persistedEntryId();
      if (entryId == null || !(await v1.closeSafely())) {
        throw StateError('Fictional v1 cannot be safely closed');
      }
      final v2 = await worker.startSession(
        journalId: journalId, existingEntryId: entryId,
        debounce: const Duration(days: 1));
      v2.controller.update(title: _titleV2, body: _bodyV2);
      await v2.save();
      if (v2.indicator.phase != SavePhase.saved ||
          v2.indicator.databaseVersion != 2 ||
          !(await v2.closeSafely())) {
        throw StateError('Fictional v2 did not commit');
      }
      archive = await worker.exportRecoveryArchive(recoveryKey);
      final verified = await ProductEncryptedArchiveCodec().verify(
        archive: archive, recoveryKey: recoveryKey);
      _verifyFictionalSnapshot(verified);
      await exercise(archive, recoveryKey);
    } finally {
      // Even if the disposable encrypted worker cannot close, continue to
      // destroy every process-local key. A cleanup failure still fails CI.
      onCleanupStage?.call('SAF_ERROR_ARCHIVE_ZEROIZE');
      var sourceClosed = false;
      try {
        archive?.fillRange(0, archive.length, 0);
        onCleanupStage?.call('SAF_ERROR_WORKER_CLOSE');
        await worker?.close();
        sourceClosed = true;
      } finally {
        if (sourceClosed) onCleanupStage?.call('SAF_ERROR_KEY_ZEROIZE');
        try {
          dbKey?.destroy();
          deviceBytes.fillRange(0, deviceBytes.length, 0);
        } finally {
          recoveryKey.destroy();
        }
      }
    }
  }

  void _verifyFictionalSnapshot(Map<String, dynamic> snapshot) {
    final journals = snapshot['journals'] as List;
    final entries = snapshot['entries'] as List;
    final revisions = snapshot['revisions'] as List;
    if (journals.length != 1 || entries.length != 1 ||
        revisions.length != 1 ||
        (entries.single as Map)['title'] != _titleV2 ||
        (entries.single as Map)['body'] != _bodyV2 ||
        (entries.single as Map)['version'] != 2 ||
        (revisions.single as Map)['title'] != _titleV1 ||
        (revisions.single as Map)['body'] != _bodyV1 ||
        (revisions.single as Map)['version'] != 1) {
      throw StateError('Fictional encrypted archive content mismatch');
    }
  }

  Future<void> _run() async {
    // Only these fixed, nonsecret classifications are allowed in CI. Never
    // log exception messages, ciphertext, recovery keys or provider URIs.
    var failurePhase = 'SAF_ERROR_SETUP';
    try {
      final phase = await _diagnostic.invokeMethod<String>('getStartPhase');
      final rootPath =
          await _diagnostic.invokeMethod<String>('getPrivateRoot');
      if (phase == null || rootPath == null || rootPath.trim().isEmpty) {
        throw StateError('Disposable Android test context unavailable');
      }
      if (phase == 'saf_import_cancel') {
        await _mark('SAF_IMPORT_READY');
        try {
          final cancelled =
              await _picker.invokeMethod<Uint8List>('openFictionalArchive');
          if (cancelled != null) {
            cancelled.fillRange(0, cancelled.length, 0);
            throw StateError('Cancelled import returned encrypted bytes');
          }
        } finally {
          await _picker.invokeMethod<void>('hideImportRecoveryInput');
        }
        await _mark('SAF_IMPORT_CANCELLED');
      } else if (phase == 'saf_export_cancel') {
        await _withFictionalArchive(Directory(rootPath), (archive, _) async {
          await _mark('SAF_EXPORT_READY');
          try {
            final result = await _picker.invokeMethod<bool>(
              'saveFictionalArchive', {'archive': archive});
            if (result != false) {
              throw StateError('Cancelled export was marked successful');
            }
          } finally {
            await _picker.invokeMethod<void>('hideRecoveryKey');
          }
        });
        await _mark('SAF_EXPORT_CANCELLED');
      } else if (phase == 'saf_roundtrip') {
        await _withFictionalArchive(Directory(rootPath), (archive, key) async {
          failurePhase = 'SAF_ERROR_EXPORT';
          await _mark('SAF_ROUNDTRIP_EXPORT_READY');
          bool saved;
          try {
            saved = await _picker.invokeMethod<bool>(
              'saveFictionalArchive', {'archive': archive}) ?? false;
          } finally {
            await _picker.invokeMethod<void>('hideRecoveryKey');
          }
          if (!saved) {
            throw StateError('Android provider export not verified');
          }
          await _mark('SAF_ROUNDTRIP_IMPORT_READY');
          Uint8List? channelBytes;
          Uint8List? picked;
          var authenticated = false;
          failurePhase = 'SAF_ERROR_NATIVE_OPEN';
          try {
            channelBytes = await _picker.invokeMethod<Uint8List>(
              'openFictionalArchive');
            failurePhase = 'SAF_ERROR_SELECTED_BYTES';
            if (channelBytes == null ||
                !listEquals(channelBytes, archive)) {
              throw StateError('Selected SAF bytes differ from export');
            }
            // Platform-message storage can be a read-only/external view.
            // Validate using an independently owned mutable ciphertext copy,
            // without assuming the Android codec's backing bytes are writable.
            picked = Uint8List.fromList(channelBytes);
            await _mark('SAF_ROUNDTRIP_BYTES_RETURNED');
            failurePhase = 'SAF_ERROR_AUTH';
            final verified = await ProductEncryptedArchiveCodec().verify(
              archive: picked, recoveryKey: key);
            _verifyFictionalSnapshot(verified);
            await _mark('SAF_ROUNDTRIP_AUTH_OK');
            authenticated = true;
          } finally {
            if (authenticated) {
              failurePhase = 'SAF_ERROR_RETURNED_BYTES_ZEROIZE';
            }
            picked?.fillRange(0, picked.length, 0);
            if (channelBytes != null) {
              try {
                channelBytes.fillRange(0, channelBytes.length, 0);
              } on UnsupportedError {
                // Only encrypted ciphertext in the platform-owned view;
                // the authenticated copy and independent key are destroyed.
              }
            }
            if (authenticated) failurePhase = 'SAF_ERROR_IMPORT_HIDE';
            await _picker.invokeMethod<void>('hideImportRecoveryInput');
            if (authenticated) {
              // Source-worker close and process-local key destruction must
              // still succeed before the final positive marker is written.
              failurePhase = 'SAF_ERROR_SOURCE_CLOSE';
            }
          }
        }, onCleanupStage: (stage) {
          // Preserve an earlier export/import/auth failure classification;
          // only refine the successful-authentication cleanup path.
          if (failurePhase == 'SAF_ERROR_SOURCE_CLOSE' ||
              failurePhase == 'SAF_ERROR_ARCHIVE_ZEROIZE' ||
              failurePhase == 'SAF_ERROR_WORKER_CLOSE') {
            failurePhase = stage;
          }
        });
        failurePhase = 'SAF_ERROR_FINAL_MARKER';
        await _mark('SAF_ROUNDTRIP_VERIFIED');
      } else {
        throw StateError('Unsupported SAF test-only phase');
      }
      if (mounted) {
        setState(() => _notice = 'Fictional picker test verified.');
      }
    } catch (_) {
      try {
        await _mark(failurePhase);
      } catch (_) {
        // Missing native marker will be detected by the bounded ADB timeout.
      }
      if (mounted) {
        setState(() => _notice =
            'Fictional picker validation failed. No private writing accepted.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(_notice, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
}
