// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures, prefer_interpolation_to_compose_strings
/// APK02 PORTABLE clean-install recovery diagnostic. FICTIONAL DATA ONLY.
///
/// Three Android launch phases selected by ADB test intent:
///   export_fixture      - encrypted source vault -> portable archive + key
///   reject_wrong_key    - new install must reject wrong key without writing
///   restore_fixture     - independently keyed vault, fresh Android Keystore
///   reopen_fixture      - same restored vault after Android force-stop
///   fault_pre_publish   - simulated ENOSPC leaves no published vault
///   fault_post_publish  - simulated ENOSPC after native rename preserves vault
///   reopen_faulted      - Keystore unlock after force-stop of ambiguous restore
///   retain_candidate    - real AndroidKeystore wraps distinct retained vault
///   reopen_candidate    - independent process opens retained vault + history
///   retire_candidate_alias - key loss fails closed without deleting bytes
///   activate_candidate   - explicit safe promotion to ABSENT APK02 active slot
///   reopen_activated     - force-stop reopen of promoted encrypted directory
///   retire_active_alias  - key loss preserves promoted active and other vault
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
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';
import 'package:navin_journal_core/staged_product_restore.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';
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
        case 'fault_pre_publish':
          await _faultBeforePublication(Directory(root));
          await _marker('PORTABLE_ENOSPC_PRE');
        case 'fault_post_publish':
          await _faultAfterPublication(Directory(root));
          await _marker('PORTABLE_ENOSPC_POST');
        case 'reopen_faulted':
          await _reopenFaulted(Directory(root));
          await _marker('PORTABLE_ENOSPC_REOPEN');
        case 'restore_fixture':
          await _restoreFixture(Directory(root));
          await _marker('PORTABLE_RESTORE_OK');
        case 'reopen_fixture':
          await _reopenFixture(Directory(root));
          await _marker('PORTABLE_REOPEN_OK');
        case 'retain_candidate':
          await _retainCandidate(Directory(root));
          await _marker('CANDIDATE_RETAINED');
        case 'reopen_candidate':
          await _reopenCandidate(Directory(root));
          await _marker('CANDIDATE_REOPEN_OK');
        case 'retire_candidate_alias':
          await _retireCandidateAlias(Directory(root));
          await _marker('CANDIDATE_KEY_LOSS_SAFE');
        case 'activate_candidate':
          await _activateCandidate(Directory(root));
          await _marker('ACTIVE_ACTIVATED');
        case 'reopen_activated':
          await _reopenActivated(Directory(root));
          await _marker('ACTIVE_REOPEN_OK');
        case 'retire_active_alias':
          await _retireActiveAlias(Directory(root));
          await _marker('ACTIVE_KEY_LOSS_SAFE');
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

  /// Synthetic ENOSPC on the real Android encrypted background worker,
  /// before native no-clobber publication. No destination may be visible.
  Future<void> _faultBeforePublication(Directory privateRoot) async {
    final archiveFile = File(privateRoot.path + '/portable_import.njr');
    final keyFile = File(privateRoot.path + '/portable_import.key');
    final target = Directory(privateRoot.path + '/fault-pre-vault');
    if (!archiveFile.existsSync() || !keyFile.existsSync() ||
        target.existsSync()) {
      throw StateError('Pre-publish fixture preconditions failed');
    }
    final archive = await archiveFile.readAsBytes();
    final recovery = RecoveryKey.parse((await keyFile.readAsString()).trim());
    final transientKey = TestVaultKey.random();
    try {
      var rejected = false;
      try {
        await PortableRecoveryWorker.restoreToNewVault(
          encryptedArchive: archive,
          recoveryKey: recovery,
          destinationKey: transientKey,
          destination: target,
          faultCheckpointForDiagnostics: 'after_ready_marker_write',
        );
      } on ProductRestoreRejected {
        rejected = true;
      }
      if (!rejected || target.existsSync() ||
          await NativeRestorePublisher.isReady(target) ||
          (await RestoreStagingInventory.inspect(privateRoot)).isNotEmpty) {
        throw StateError('Prepublication storage fault exposed a journal');
      }
    } finally {
      transientKey.destroy();
      recovery.destroy();
      archive.fillRange(0, archive.length, 0);
    }
  }

  /// An ENOSPC acknowledgement failure AFTER the kernel published a complete
  /// encrypted vault. Keep the new Android Keystore key for revalidation on
  /// a separate process launch. Never auto-delete or overwrite this target.
  Future<void> _faultAfterPublication(Directory privateRoot) async {
    final archiveFile = File(privateRoot.path + '/portable_import.njr');
    final keyFile = File(privateRoot.path + '/portable_import.key');
    final target = Directory(privateRoot.path + '/fault-post-vault');
    final envelope = File(privateRoot.path + '/fault-post-envelope.json');
    final database = target.path + '/journal.sqlite3';
    if (!archiveFile.existsSync() || !keyFile.existsSync() ||
        target.existsSync() || envelope.existsSync()) {
      throw StateError('Post-publish fixture preconditions failed');
    }
    final archive = await archiveFile.readAsBytes();
    final recovery = RecoveryKey.parse((await keyFile.readAsString()).trim());
    TestVaultKey? freshKey;
    try {
      freshKey = await _newDeviceKey(_envelope(envelope), database);
      var rejected = false;
      try {
        await PortableRecoveryWorker.restoreToNewVault(
          encryptedArchive: archive,
          recoveryKey: recovery,
          destinationKey: freshKey,
          destination: target,
          faultCheckpointForDiagnostics: 'before_parent_post_rename_fsync',
        );
      } on ProductRestoreRejected {
        rejected = true;
      }
      if (!rejected || !await NativeRestorePublisher.isReady(target) ||
          (await RestoreStagingInventory.inspect(privateRoot)).isNotEmpty) {
        throw StateError('Ambiguous commit was deleted or not quarantined');
      }
      // A marker alone is not trusted: independently open the encrypted DB.
      await _verifyRestored(database, freshKey);
    } finally {
      recovery.destroy();
      freshKey?.destroy();
      archive.fillRange(0, archive.length, 0);
    }
  }

  /// Called only after the Android host test has force-stopped the process.
  Future<void> _reopenFaulted(Directory privateRoot) async {
    final target = Directory(privateRoot.path + '/fault-post-vault');
    final envelope = File(privateRoot.path + '/fault-post-envelope.json');
    final database = target.path + '/journal.sqlite3';
    if (!await NativeRestorePublisher.isReady(target) ||
        !envelope.existsSync()) {
      throw StateError('No independently recoverable post-rename journal');
    }
    final key = await _unlockDeviceKey(_envelope(envelope), database);
    try {
      await _verifyRestored(database, key);
      if ((await RestoreStagingInventory.inspect(privateRoot)).isNotEmpty) {
        throw StateError('Unexpected abandoned restore stage');
      }
    } finally {
      key.destroy();
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

  // This is the real AndroidKeystore bridge, NOT the Linux fake protector
  // used by unit tests. The original Android installation was uninstalled
  // and its Keystore alias destroyed before this phase runs.
  Future<void> _retainCandidate(Directory root) async {
    final archiveFile = File(root.path + '/portable_import.njr');
    final keyFile = File(root.path + '/portable_import.key');
    final target = Directory(root.path + '/' +
        FictionalRetainedRecoveryCandidate.candidateDirectoryName);
    final reservation = File(target.path + '.reservation');
    if (!archiveFile.existsSync() || !keyFile.existsSync() ||
        target.existsSync() || reservation.existsSync()) {
      throw StateError('Invalid retained candidate fixture');
    }
    final secret = (await keyFile.readAsString()).trim();
    // The disposable runner retains the key on the external CI host; it
    // must not persist in this Android sandbox after it is consumed.
    await keyFile.delete();
    final payload = await archiveFile.readAsBytes();
    try {
      final receipt = await FictionalRetainedRecoveryCandidate.prepare(
        encryptedArchive: Uint8List.fromList(payload),
        manuallyEnteredRecoveryKey: secret,
        trustedPrivateRoot: root,
        deviceProtector: FlutterAndroidKeyProtector(),
      );
      if (receipt.journals != 1 || receipt.entries != 1 ||
          receipt.revisions != 1 || receipt.attachments != 0 ||
          receipt.activeJournalReplaced ||
          receipt.activatedForPersonalWriting ||
          receipt.physicalDeviceRecoveryVerified ||
          !target.existsSync() || !reservation.existsSync() ||
          !await NativeRestorePublisher.isReady(Directory(
              target.path + '/vault'))) {
        throw StateError('Android retained recovery verification failed');
      }

      // A second attempted promotion into the same candidate MUST refuse
      // replacement. Neither ciphertext nor envelope may be changed.
      final envelope = File(target.path + '/envelope.json');
      final originalEnvelope = await envelope.readAsString();
      final db = File(target.path + '/vault/journal.sqlite3');
      final originalLength = await db.length();
      var refused = false;
      try {
        await FictionalRetainedRecoveryCandidate.prepare(
          encryptedArchive: Uint8List.fromList(payload),
          manuallyEnteredRecoveryKey: secret,
          trustedPrivateRoot: root,
          deviceProtector: FlutterAndroidKeyProtector(),
        );
      } on FictionalRetainedRecoveryRejected {
        refused = true;
      }
      if (!refused || !reservation.existsSync() ||
          await envelope.readAsString() != originalEnvelope ||
          await db.length() != originalLength) {
        throw StateError('Occupied protected candidate was replaced');
      }
      // Verify the candidate has a *different* non-exportable Android alias
      // from the older independent fixture, before the alias-loss drill.
      final candidateDocument = await _envelope(envelope).readEnvelope();
      final existingDocument = await _envelope(File(
          root.path + '/portable-restored-envelope.json')).readEnvelope();
      if (candidateDocument.activeAlias == existingDocument.activeAlias) {
        throw StateError('Independent recovered vault reused device alias');
      }
      // Existing fixture is decryptable before the candidate is sealed.
      await _reopenFixture(root);
      // Remove the imported file too: the later process has no archive,
      // manually entered recovery secret or database DEK to read.
      await archiveFile.delete();
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }

  Future<void> _reopenCandidate(Directory root) async {
    // Called only from a new Android app process AFTER adb force-stop.
    // The recovery archive, manual key and transient destination DEK are
    // not passed to this call, nor read from the filesystem.
    final report = await FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
    );
    if (report.journals != 1 || report.entries != 1 ||
        report.revisions != 1 || report.attachments != 0 ||
        report.activeJournalReplaced || report.activatedForPersonalWriting) {
      throw StateError('Retained candidate records differ after restart');
    }
    final folder = Directory(root.path + '/' +
        FictionalRetainedRecoveryCandidate.candidateDirectoryName);
    final dbPath = folder.path + '/vault/journal.sqlite3';
    // In addition to opaque counts, assert the recovered fictional title,
    // Telugu/emoji body and historical revision with the true Android key.
    final local = _envelope(File(folder.path + '/envelope.json'));
    final key = await _unlockDeviceKey(local, dbPath);
    try {
      await _verifyRestored(dbPath, key);
      await _reopenFixture(root); // Existing active fixture still works.
    } finally {
      key.destroy();
    }
  }

  Future<void> _retireCandidateAlias(Directory root) async {
    final folder = Directory(root.path + '/' +
        FictionalRetainedRecoveryCandidate.candidateDirectoryName);
    final envelopeFile = File(folder.path + '/envelope.json');
    final db = File(folder.path + '/vault/journal.sqlite3');
    final reservation = File(folder.path + '.reservation');
    if (!await envelopeFile.exists() || !await db.exists() ||
        !await reservation.exists()) {
      throw StateError('Protected candidate is missing');
    }
    final oldEnvelope = await envelopeFile.readAsString();
    final oldSize = await db.length();
    final keystore = FlutterAndroidKeyProtector();
    final coordinator = KeyEnvelopeCoordinator(
      envelopeFile: envelopeFile, protector: keystore);
    final doc = await coordinator.readEnvelope();
    // Explicit destructive action against the disposable candidate's
    // wrapping alias ONLY. The original independent vault stays intact.
    await keystore.retire(doc.activeAlias);
    var refused = false;
    try {
      await FictionalRetainedRecoveryCandidate.reopen(
        trustedPrivateRoot: root,
        deviceProtector: keystore,
      );
    } on FictionalRetainedRecoveryRejected {
      refused = true;
    }
    if (!refused ||
        !await envelopeFile.exists() ||
        !await db.exists() ||
        !await reservation.exists() ||
        await envelopeFile.readAsString() != oldEnvelope ||
        await db.length() != oldSize) {
      throw StateError('Lost wrapping key unexpectedly changed vault');
    }
    // The separate portable-restored fixture should remain unlockable.
    await _reopenFixture(root);
  }

  /// ADB sets an explicit test-intent phase representing a deliberate
  /// approval gesture. The real first-run UI separately requires a checkbox
  /// and exact typed confirmation before calling the same service.
  Future<void> _activateCandidate(Directory root) async {
    if (await FictionalRecoveryActivator.inspect(
          trustedPrivateRoot: root) !=
        FictionalActivationState.awaitingExplicitApproval) {
      throw StateError('Active destination not empty or candidate invalid');
    }
    final receipt = await FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
      userExplicitlyApproved: true,
    );
    if (receipt.journals != 1 || receipt.entries != 1 ||
        receipt.revisions != 1 || receipt.attachments != 0 ||
        receipt.existingVaultReplaced || receipt.privateWritingApproved ||
        receipt.deviceRecoveryCertified) {
      throw StateError('Fictional approval result not accepted');
    }
    if (Directory(root.path + '/' +
        FictionalRetainedRecoveryCandidate.candidateDirectoryName)
        .existsSync()) {
      throw StateError('Candidate source still present after atomic move');
    }
    await _reopenActivated(root);
  }

  Future<void> _reopenActivated(Directory root) async {
    final receipt = await FictionalRecoveryActivator.reopenActivated(
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
    );
    if (receipt.journals != 1 || receipt.entries != 1 ||
        receipt.revisions != 1 || receipt.attachments != 0) {
      throw StateError('Activated encrypted counts changed after restart');
    }
    final activated = Directory(root.path + '/' +
        FictionalRecoveryActivator.activeDirectoryName);
    final path = activated.path + '/vault/journal.sqlite3';
    final key = await _unlockDeviceKey(
      _envelope(File(activated.path + '/envelope.json')), path);
    try {
      await _verifyRestored(path, key);
      await _reopenFixture(root); // Separate journal remains untouched.
    } finally {
      key.destroy();
    }
  }

  Future<void> _retireActiveAlias(Directory root) async {
    final activated = Directory(root.path + '/' +
        FictionalRecoveryActivator.activeDirectoryName);
    final envelope = File(activated.path + '/envelope.json');
    final db = File(activated.path + '/vault/journal.sqlite3');
    final marker = File(activated.path + '/' +
        NativeRestorePublisher.fictionalActivationMarker);
    final lock = File(root.path + '/' +
        FictionalRecoveryActivator.activationReservationName);
    if (!await envelope.exists() || !await db.exists() ||
        !await marker.exists() || !await lock.exists()) {
      throw StateError('Promoted encrypted fixture missing');
    }
    final envelopeBefore = await envelope.readAsString();
    final dbBefore = await db.length();
    final keyProvider = FlutterAndroidKeyProtector();
    final doc = await KeyEnvelopeCoordinator(
      envelopeFile: envelope, protector: keyProvider).readEnvelope();
    await keyProvider.retire(doc.activeAlias);
    var refused = false;
    try {
      await FictionalRecoveryActivator.reopenActivated(
        trustedPrivateRoot: root, deviceProtector: keyProvider);
    } on FictionalActivationRejected {
      refused = true;
    }
    if (!refused ||
        !await db.exists() || !await envelope.exists() ||
        !await marker.exists() || !await lock.exists() ||
        await envelope.readAsString() != envelopeBefore ||
        await db.length() != dbBefore) {
      throw StateError('Key loss damaged activated encrypted bytes');
    }
    await _reopenFixture(root);
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
