// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK02 fictional-only end-to-end Library / Reader / Editor Android shell.
/// Not a consumer app, private diary, or independently recoverable vault.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_bridge_probe/android_key_bridge.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/fictional_archive_importer.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';
import 'package:navin_journal_editor/fictional_recovery_activator.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_key_lifecycle_spike/key_envelope_coordinator.dart';

import 'fictional_journal_library.dart';
import 'fictional_external_import_section.dart';
import 'fictional_activation_consent_panel.dart';
import 'visuals.dart';

const _diagnostic = MethodChannel('navin_journal/test_lifecycle_v1');
const _fictionalArchivePicker =
    MethodChannel('navin_journal/fictional_export_v1');

void main() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Fictional-only APK 02 test must never run in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Apk02LibraryDiagnosticApp());
}

class Apk02LibraryDiagnosticApp extends StatefulWidget {
  /// Widget tests inject a fictional private root/state to isolate first-run
  /// presentation from Android MethodChannel and native filesystem timing.
  /// The actual Android app always supplies neither parameter.
  final Directory? debugTestPrivateRoot;
  final FictionalActivationState? debugTestActivationState;
  const Apk02LibraryDiagnosticApp({
    super.key,
    this.debugTestPrivateRoot,
    this.debugTestActivationState,
  });

  @override
  State<Apk02LibraryDiagnosticApp> createState() =>
      Apk02LibraryDiagnosticAppState();
}

class Apk02LibraryDiagnosticAppState
    extends State<Apk02LibraryDiagnosticApp> {
  JournalEditorWorker? _worker;
  Directory? _privateRoot;
  String? _journalId;
  String _status = 'Unlocking fictional encrypted journal…';
  bool _failed = false;
  bool _firstRun = false;
  FictionalActivationState? _firstRunState;
  Future<void>? _firstBoot;
  final _activationPanelKey =
      GlobalKey<FictionalActivationConsentPanelState>();

  /// Waits for the real file/MethodChannel bootstrap in Flutter tests;
  /// no time-based polling and no generic pumpAndSettle spinner timeout.
  @visibleForTesting
  Future<void> waitForFirstBoot() async {
    final pending = _firstBoot;
    if (pending != null) await pending;
  }

  @override
  void initState() {
    super.initState();
    _firstBoot = _open();
  }

  Future<void> _open({bool startNew = false}) async {
    JournalEditorWorker? opened;
    if (mounted) setState(() {
      _failed = false;
      _status = 'Unlocking fictional encrypted journal…';
    });
    try {
      final root = widget.debugTestPrivateRoot?.path ??
          await _diagnostic.invokeMethod<String>('getPrivateRoot');
      if (root == null || root.trim().isEmpty) {
        throw StateError('App private root is unavailable');
      }
      // A separate test-only vault, not shared with other probe APKs.
      final folder = Directory(
        root + Platform.pathSeparator + 'nj_apk02_library_fixture');
      final legacyDb = File(
        folder.path + Platform.pathSeparator + 'journal.sqlite3');
      final activeRecoveredDb = File(folder.path +
          Platform.pathSeparator + 'vault' +
          Platform.pathSeparator + 'journal.sqlite3');
      final envelope = File(
        folder.path + Platform.pathSeparator + 'envelope.json');
      final rootDirectory = Directory(root);
      final state = widget.debugTestActivationState ??
          await FictionalRecoveryActivator.inspect(
            trustedPrivateRoot: rootDirectory);
      final legacy = legacyDb.existsSync();
      final activated = activeRecoveredDb.existsSync();
      if (legacy && activated) {
        throw StateError('Conflicting encrypted library layouts');
      }
      if (!legacy && !activated) {
        // Do not silently create a demo vault on a fresh installation:
        // that would occupy the only safe destination before recovery.
        if (state == FictionalActivationState.unsafeOrInterrupted ||
            folder.existsSync() || envelope.existsSync()) {
          throw StateError('Incomplete or interrupted vault: refuse reset');
        }
        if (!startNew) {
          if (!mounted) return;
          setState(() {
            _privateRoot = rootDirectory;
            _firstRunState = state;
            _firstRun = true;
          });
          return;
        }
        // Even if the screen was displayed before a candidate was retained,
        // recheck at action time: never occupy a recovery destination while
        // an encrypted candidate or unknown reservation exists.
        if (state != FictionalActivationState.notPrepared) {
          throw StateError('Recovery candidate pending or unsafe');
        }
        folder.createSync(recursive: false);
      } else if (activated) {
        if (state != FictionalActivationState.activeFictionalVault ||
            !await FictionalRecoveryActivator.reopenActivated(
              trustedPrivateRoot: rootDirectory,
              deviceProtector: FlutterAndroidKeyProtector(),
            ).then((report) => report.entries >= 0)) {
          throw StateError('Activated journal not independently verified');
        }
      } else if (!envelope.existsSync()) {
        throw StateError('Existing legacy journal lost key envelope');
      }
      final create = !legacy && !activated;
      final dbFile = activated ? activeRecoveredDb : legacyDb;
      final protector = KeyEnvelopeCoordinator(
        envelopeFile: envelope,
        protector: FlutterAndroidKeyProtector(),
      );
      final bytes = create
        ? await protector.initialize(databasePath: dbFile.path)
        : await protector.unlock(databasePath: dbFile.path);
      try {
        final key = TestVaultKey.fromBytes(bytes);
        try {
          opened = await JournalEditorWorker.open(
            dbFile.path, key: key, create: create);
        } finally {
          key.destroy();
        }
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }

      // No journal names, titles or entry text are mirrored into
      // SharedPreferences or any other plaintext local metadata.
      String active;
      if (create) {
        active = await opened.createJournal('Fictional Pages');
      } else {
        final journals = await opened.listJournals();
        // The encrypted vault may now contain several fictional notebooks.
        // Never create/reset a journal on an existing installation and never
        // copy a selection into plaintext SharedPreferences. Select the most
        // recent writable journal, otherwise the latest archived one for
        // read-only viewing. A fully trashed vault fails closed.
        final available = journals.where(
            (item) => item['deletedAtMs'] == null).toList();
        if (available.isEmpty) {
          throw StateError('No accessible fictional journal');
        }
        final writable = available.where(
            (item) => item['archived'] == false).toList();
        active = (writable.isNotEmpty ? writable.first : available.first)
            ['id'] as String;
      }
      if (!(await opened.integrityCheck())) {
        throw StateError('Encrypted database integrity check failed');
      }
      if (!mounted) {
        await opened.close();
        return;
      }
      setState(() {
        _worker = opened;
        _journalId = active;
        _privateRoot = rootDirectory;
        _firstRun = false;
      });
    } catch (_) {
      if (opened != null) {
        try { await opened.close(); } catch (_) {}
      }
      if (mounted) setState(() {
        _failed = true;
        _status = 'Could not unlock this fictional journal. '
            'No data has been reset. Do not enter personal writing.';
      });
    }
  }

  Future<Uint8List?> _chooseFictionalArchive() =>
      _fictionalArchivePicker.invokeMethod<Uint8List>('openFictionalArchive');

  Future<void> _hideFictionalInput() =>
      _fictionalArchivePicker.invokeMethod<void>('hideImportRecoveryInput');

  Future<FictionalArchiveImportReport> _inspectSelected(
      Uint8List document, String key) {
    final root = _privateRoot;
    if (root == null) throw const FictionalArchiveImportRejected();
    return FictionalArchiveImporter.inspect(
      encryptedArchive: document,
      manuallyEnteredRecoveryKey: key,
      trustedPrivateRoot: root,
    );
  }

  Future<FictionalRetainedRecoveryReport> _retainSelected(
      Uint8List document, String key) {
    final root = _privateRoot;
    if (root == null) throw const FictionalRetainedRecoveryRejected();
    return FictionalRetainedRecoveryCandidate.prepare(
      encryptedArchive: document,
      manuallyEnteredRecoveryKey: key,
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
    );
  }

  Future<FictionalRetainedRecoveryReport> _reopenCandidate() {
    final root = _privateRoot;
    if (root == null) throw const FictionalRetainedRecoveryRejected();
    return FictionalRetainedRecoveryCandidate.reopen(
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
    );
  }

  Future<FictionalActivationState> _inspectActivation() {
    final root = _privateRoot;
    if (root == null) throw const FictionalActivationRejected();
    return FictionalRecoveryActivator.inspect(trustedPrivateRoot: root);
  }

  // First-run-only presentation refresh after an independently retained
  // candidate. This does not call activate, reset or create any vault.
  Future<void> _candidateRetained() async {
    FictionalActivationState state;
    try {
      state = await _inspectActivation();
    } catch (_) {
      state = FictionalActivationState.unsafeOrInterrupted;
    }
    if (!mounted || !_firstRun) return;
    setState(() => _firstRunState = state);
    await _activationPanelKey.currentState?.refresh();
  }

  Future<FictionalActivationReceipt> _activateApproved() {
    final root = _privateRoot;
    if (root == null) throw const FictionalActivationRejected();
    return FictionalRecoveryActivator.approveAndActivate(
      trustedPrivateRoot: root,
      deviceProtector: FlutterAndroidKeyProtector(),
      userExplicitlyApproved: true,
    );
  }

  Widget _firstLaunchView(JournalColors colors) =>
      Scaffold(body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              const FoldedPageMark(size: 56),
              const SizedBox(height: 16),
              Text('Your fictional journal', style: editorial(colors, 32)),
              const SizedBox(height: 11),
              Text('Choose a fresh demo or recover a separate fictional '
                'encrypted archive before creating the active Library. '
                'Nothing is restored or overwritten automatically.',
                key: const ValueKey('first-run-choice'),
                style: TextStyle(color: colors.secondary, height: 1.5)),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('first-run-new-journal'),
                onPressed: _firstRunState ==
                    FictionalActivationState.notPrepared
                    ? () => _open(startNew: true) : null,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('Create a fresh fictional journal'),
              ),
              if (_firstRunState ==
                  FictionalActivationState.awaitingExplicitApproval) ...[
                const SizedBox(height: 10),
                Text('A protected recovery candidate is waiting. Creating '
                  'a new Library is disabled until recovery is reviewed.',
                  key: const ValueKey('first-run-candidate-pending'),
                  style: TextStyle(color: colors.clay, height: 1.4)),
              ] else if (_firstRunState !=
                  FictionalActivationState.notPrepared) ...[
                const SizedBox(height: 10),
                Text('An existing or uncertain encrypted state blocks '
                  'new-Library creation. Nothing has been reset.',
                  key: const ValueKey('first-run-candidate-unsafe'),
                  style: TextStyle(color: colors.clay, height: 1.4)),
              ],
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 17),
              FictionalExternalImportSection(
                selectEncryptedDocument: _chooseFictionalArchive,
                inspect: _inspectSelected,
                retainCandidate: _retainSelected,
                reopenCandidate: _reopenCandidate,
                hideProtectedInput: _hideFictionalInput,
                onCandidateRetained: _candidateRetained,
              ),
              const SizedBox(height: 25),
              const Divider(),
              const SizedBox(height: 17),
              FictionalActivationConsentPanel(
                key: _activationPanelKey,
                inspect: widget.debugTestActivationState == null
                    ? _inspectActivation
                    : () async => widget.debugTestActivationState!,
                activateApproved: _activateApproved,
                onActivated: () => _open(),
              ),
              const SizedBox(height: 25),
            ],
          ),
        )),
      )));

  @override
  void dispose() {
    final worker = _worker;
    _worker = null;
    if (worker != null) unawaited(worker.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = JournalColors(false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Navin Journal · Fictional APK 02',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: colors.canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: colors.action),
      ),
      home: _worker != null && _journalId != null
        ? FictionalJournalLibrary(
            worker: _worker!,
            journalId: _journalId!,
            recoveryPrivateRoot: _privateRoot,
          )
        : _firstRun && _privateRoot != null && !_failed
        ? _firstLaunchView(colors)
        : Scaffold(body: SafeArea(child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const FoldedPageMark(size: 60),
                  const SizedBox(height: 23),
                  Text('Fictional Journal', style: editorial(colors, 32)),
                  const SizedBox(height: 17),
                  Text(_status, key: const ValueKey('library-unlock-status'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _failed
                      ? colors.clay : colors.secondary, height: 1.5)),
                  if (!_failed) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ]),
              ),
            ),
          ))),
    );
  }
}
