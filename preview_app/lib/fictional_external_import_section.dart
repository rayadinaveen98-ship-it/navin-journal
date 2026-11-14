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

import 'visuals.dart';

class FictionalExternalImportSection extends StatefulWidget {
  final Future<Uint8List?> Function() selectEncryptedDocument;
  final Future<FictionalArchiveImportReport> Function(
      Uint8List document, String recoveryKey) inspect;
  final Future<void> Function() hideProtectedInput;
  const FictionalExternalImportSection({
    super.key,
    required this.selectEncryptedDocument,
    required this.inspect,
    required this.hideProtectedInput,
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

  Future<void> _verify() async {
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
      final result = await widget.inspect(ciphertext, key);
      if (result.activeVaultReplaced ||
          result.importedVaultRetained ||
          result.independentlyRecoverableBackupVerified) {
        throw const FictionalArchiveImportRejected();
      }
      if (mounted) setState(() => _report = result);
    } catch (_) {
      if (mounted) setState(() => _notice =
          'Recovery verification failed. The key may be incorrect, '
          'the archive may be damaged or storage may be unavailable. '
          'No existing journal was replaced.');
    } finally {
      ciphertext.fillRange(0, ciphertext.length, 0);
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
          'disposable encrypted vault. It NEVER modifies or merges your '
          'current journal and does not keep recovered pages.',
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
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_notice!, key: const ValueKey('import-notice'),
              style: TextStyle(color: c.clay, height: 1.5)),
          ),
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
