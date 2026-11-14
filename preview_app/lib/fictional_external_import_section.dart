// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures
/// Debug-only encrypted document import QA; no production journal restoration.
///
/// All input is fictional. The Android picker returns bounded ciphertext and
/// holds FLAG_SECURE for this window until the import screen releases it.
/// No archive, manually re-entered key or recovered text is cached/exported.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navin_journal_editor/fictional_archive_importer.dart';
import 'package:navin_journal_editor/fictional_retained_recovery_candidate.dart';

import 'visuals.dart';

class FictionalExternalImportSection extends StatefulWidget {
  final Future<Uint8List?> Function() selectEncryptedDocument;
  final Future<FictionalArchiveImportReport> Function(
      Uint8List document, String recoveryKey) inspect;
  final Future<void> Function() hideProtectedInput;
  final Future<FictionalRetainedRecoveryReport> Function(
      Uint8List archive, String key)? retainCandidate;
  final Future<FictionalRetainedRecoveryReport> Function()? reopenCandidate;
  const FictionalExternalImportSection({
    super.key,
    required this.selectEncryptedDocument,
    required this.inspect,
    required this.hideProtectedInput,
    this.retainCandidate,
    this.reopenCandidate,
  });

  @override
  State<FictionalExternalImportSection> createState() =>
      FictionalExternalImportSectionState();
}

class FictionalExternalImportSectionState
    extends State<FictionalExternalImportSection>
    with WidgetsBindingObserver {
  final TextEditingController _manualKey = TextEditingController();
  Uint8List? _selectedDocument;
  bool _selecting = false;
  bool _checking = false;
  String? _notice;
  FictionalArchiveImportReport? _report;
  FictionalRetainedRecoveryReport? _retainedReport;
  Future<void>? _activeWork;

  @visibleForTesting
  Future<void> waitForIdle() async => await _activeWork;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _manualKey.addListener(_textChanged);
  }

  void _textChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _hideNativeInput() async {
    try {
      await widget.hideProtectedInput();
    } catch (_) {
      // Never log document names, entered keys or platform exception text.
    }
  }

  void _clearSelection() {
    final old = _selectedDocument;
    _selectedDocument = null;
    old?.fillRange(0, old.length, 0);
    _manualKey.clear();
    unawaited(_hideNativeInput());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_selectedDocument == null || _selecting || _checking) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _clearSelection();
      if (mounted) setState(() {
        _notice = 'Import cancelled after leaving the screen. '
            'No journal was changed.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Do not trigger setState from TextEditingController listeners during
    // widget teardown.
    _manualKey.removeListener(_textChanged);
    _clearSelection();
    _manualKey.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_selecting || _checking || _selectedDocument != null || !mounted) return;
    setState(() {
      _selecting = true;
      _notice = null;
      _report = null;
      _retainedReport = null;
    });
    try {
      final ciphertext = await widget.selectEncryptedDocument();
      if (ciphertext == null) {
        if (mounted) setState(() =>
            _notice = 'File selection cancelled. No recovery was performed.');
        await _hideNativeInput();
        return;
      }
      if (ciphertext.isEmpty || ciphertext.length > 32 * 1024 * 1024) {
        ciphertext.fillRange(0, ciphertext.length, 0);
        throw const FictionalArchiveImportRejected();
      }
      if (mounted) {
        setState(() => _selectedDocument = ciphertext);
      } else {
        ciphertext.fillRange(0, ciphertext.length, 0);
        await _hideNativeInput();
      }
    } catch (_) {
      _clearSelection();
      if (mounted) setState(() => _notice =
          'Encrypted document could not be read. Nothing was restored.');
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _verify({bool retain = false}) async {
    final ciphertext = _selectedDocument;
    if (_selecting || _checking || ciphertext == null || !mounted ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(_manualKey.text)) return;
    final key = _manualKey.text;
    _manualKey.clear();
    setState(() {
      _checking = true;
      _notice = null;
      _selectedDocument = null; // transfer ownership to isolated inspector
    });
    try {
      if (retain) {
        final action = widget.retainCandidate;
        if (action == null) throw const FictionalArchiveImportRejected();
        final candidate = await action(ciphertext, key);
        if (candidate.activeJournalReplaced ||
            candidate.activatedForPersonalWriting ||
            candidate.physicalDeviceRecoveryVerified) {
          throw const FictionalArchiveImportRejected();
        }
        if (mounted) setState(() => _retainedReport = candidate);
      } else {
        final result = await widget.inspect(ciphertext, key);
        if (result.activeVaultReplaced ||
            result.importedVaultRetained ||
            result.independentlyRecoverableBackupVerified) {
          throw const FictionalArchiveImportRejected();
        }
        if (mounted) setState(() => _report = result);
      }
    } catch (_) {
      if (mounted) setState(() => _notice =
          'Recovery verification failed. The key may be incorrect, '
          'the archive may be damaged or storage may be unavailable. '
          'No existing journal was replaced. A reserved candidate '
          'may remain quarantined for manual inspection.');
    } finally {
      ciphertext.fillRange(0, ciphertext.length, 0);
      await _hideNativeInput();
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _reopenRetained() async {
    final action = widget.reopenCandidate;
    if (action == null || _selectedDocument != null ||
        _selecting || _checking || !mounted) return;
    setState(() {
      _checking = true;
      _notice = null;
      _report = null;
      _retainedReport = null;
    });
    try {
      final retained = await action();
      if (retained.activeJournalReplaced ||
          retained.activatedForPersonalWriting ||
          retained.physicalDeviceRecoveryVerified) {
        throw const FictionalArchiveImportRejected();
      }
      if (mounted) setState(() => _retainedReport = retained);
    } catch (_) {
      if (mounted) setState(() => _notice =
          'Protected candidate could not reopen. It was not deleted, '
          'repaired or activated. Your current journal was not changed.');
    } finally {
      await _hideNativeInput();
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return Column(
      key: const ValueKey('fictional-external-import'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fictional encrypted archive import', style: editorial(c, 24)),
        const SizedBox(height: 9),
        Text('Select an existing .njr encrypted document, then manually '
          're-enter its separate recovery key. Verification uses a new '
          'disposable encrypted vault by default. An optional separate '
          'retained-candidate test keeps a new device-wrapped encrypted '
          'vault without changing your current journal.',
          key: const ValueKey('import-safety-warning'),
          style: TextStyle(color: c.secondary, height: 1.5)),
        const SizedBox(height: 10),
        Text('This is an engineering diagnostic, not a backup or a '
          'production clean-device restore. Use fictional files only.',
          key: const ValueKey('import-fictional-warning'),
          style: TextStyle(color: c.clay, height: 1.5, fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('import-select-document'),
          onPressed: _selecting || _checking || _selectedDocument != null
            ? null : () => _activeWork = _pick(),
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Choose fictional encrypted file'),
        ),
        if (_selectedDocument != null) ...[
          const SizedBox(height: 15),
          TextField(
            key: const ValueKey('import-recovery-key'),
            controller: _manualKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.visiblePassword,
            maxLength: 43,
            decoration: const InputDecoration(
              labelText: 'Manually re-enter 43-character recovery key',
              hintText: 'Recovery key from separate offline record',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 9),
          FilledButton.icon(
            key: const ValueKey('import-verify'),
            onPressed: _checking ||
                !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(_manualKey.text)
                ? null : () => _activeWork = _verify(),
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Verify in separate encrypted vault'),
          ),
          if (widget.retainCandidate != null) ...[
            const SizedBox(height: 9),
            Text('STAGE 5A TEST · Retains one separate protected candidate. '
              'Never replaces or activates the current journal. '
              'Repeated imports refuse an occupied candidate.',
              key: const ValueKey('import-retain-warning'),
              style: TextStyle(color: c.clay,
                height: 1.4, fontWeight: FontWeight.w600, fontSize: 12)),
            OutlinedButton.icon(
              key: const ValueKey('import-retain-candidate'),
              onPressed: _checking ||
                  !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(_manualKey.text)
                  ? null : () => _activeWork = _verify(retain: true),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Keep separate protected candidate (test)'),
            ),
          ],
          TextButton(
            key: const ValueKey('import-cancel'),
            onPressed: _checking ? null : () {
              _clearSelection();
              setState(() =>
                  _notice = 'Import cancelled. No journal was changed.');
            },
            child: const Text('Cancel without restoring'),
          ),
        ],
        if (_selecting || _checking) const Padding(
          padding: EdgeInsets.only(top: 10),
          child: LinearProgressIndicator(key: ValueKey('import-progress')),
        ),
        if (widget.reopenCandidate != null &&
            _selectedDocument == null)
          OutlinedButton.icon(
            key: const ValueKey('import-reopen-candidate'),
            onPressed: _selecting || _checking ? null :
                () => _activeWork = _reopenRetained(),
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Recheck stored protected candidate (test)'),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_notice!, key: const ValueKey('import-notice'),
              style: TextStyle(color: c.clay, height: 1.5)),
          ),
        if (_retainedReport != null) ...[
          const SizedBox(height: 12),
          Text('Separate protected recovery candidate reopened',
            key: const ValueKey('import-retained-verified'),
            style: TextStyle(color: c.success,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('${_retainedReport!.journals} notebooks · '
            '${_retainedReport!.entries} pages · '
            '${_retainedReport!.revisions} revisions · '
            '${_retainedReport!.attachments} attachments',
            key: const ValueKey('import-retained-counts'),
            style: TextStyle(color: c.ink)),
          const SizedBox(height: 7),
          Text('QUARANTINED CANDIDATE ONLY · Not activated, not merged '
            'with your Library, not approved for private writing.',
            key: const ValueKey('import-retained-not-activated'),
            style: TextStyle(color: c.clay,
              fontWeight: FontWeight.w700, fontSize: 12)),
        ],
        if (_report != null) ...[
          const SizedBox(height: 13),
          Text('Separate fictional encrypted restore verified',
            key: const ValueKey('import-verified'),
            style: TextStyle(color: c.success,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text('${_report!.journals} notebooks · ${_report!.entries} '
            'pages · ${_report!.revisions} revisions · '
            '${_report!.attachments} attachments',
            key: const ValueKey('import-counts'),
            style: TextStyle(color: c.ink)),
          const SizedBox(height: 7),
          Text('TEMPORARY REVIEW ONLY · restored test vault was removed. '
            'No existing journal was changed and no new usable journal '
            'was installed.',
            key: const ValueKey('import-not-installed'),
            style: TextStyle(color: c.clay, height: 1.5,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}
