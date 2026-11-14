// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// Fictional-only external encrypted document export and one-time key display.
/// This is NOT a production backup/restore UI and accepts no private writing.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:navin_journal_editor/fictional_archive_exporter.dart';

import 'visuals.dart';

class FictionalExternalExportSection extends StatefulWidget {
  /// Normal Android: uses ACTION_CREATE_DOCUMENT, verifies provider readback
  /// and sets FLAG_SECURE before yielding the key. Tests may inject a report.
  final Future<FictionalArchiveExportReceipt?> Function() export;
  /// Clears Android FLAG_SECURE after removing the transient key from view.
  final Future<void> Function() hideKey;

  const FictionalExternalExportSection({
    super.key, required this.export, required this.hideKey,
  });

  @override
  State<FictionalExternalExportSection> createState() =>
      FictionalExternalExportSectionState();
}

class FictionalExternalExportSectionState
    extends State<FictionalExternalExportSection>
    with WidgetsBindingObserver {
  bool _working = false;
  String? _message;
  FictionalArchiveExportReceipt? _receipt;
  Future<void>? _activeWork;

  @visibleForTesting
  Future<void> waitForIdle() async => _activeWork;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _hideNativeKey() async {
    try {
      await widget.hideKey();
    } catch (_) {
      // Do not surface platform errors or expose the key in logs. Android
      // hides this Activity on dispose/background independent of the result.
    }
  }

  void _forgetKey() {
    if (mounted) setState(() => _receipt = null);
    unawaited(_hideNativeKey());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_receipt == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _forgetKey();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receipt = null;
    unawaited(_hideNativeKey());
    super.dispose();
  }

  Future<void> _begin() async {
    if (!mounted || _working || _receipt != null) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final receipt = await widget.export();
      if (receipt == null) {
        if (mounted) setState(() =>
            _message = 'Export cancelled. No recovery key was disclosed.');
      } else if (!receipt.providerReadbackVerified ||
          receipt.keyCustodyVerified || receipt.cleanDeviceRestoreVerified ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$')
              .hasMatch(receipt.manualRecoveryKey)) {
        throw const FictionalExportUnavailable();
      } else if (mounted) {
        // Native must already have enabled FLAG_SECURE. This widget itself
        // never writes the key to disk, logs, clipboard or preferences.
        setState(() => _receipt = receipt);
      }
    } catch (_) {
      if (mounted) setState(() => _message =
          'Encrypted export was not verified. A partial or unusable '
          'document may remain at the selected location. No recovery key '
          'was retained. Do not rely on that document.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return Column(
      key: const ValueKey('fictional-external-export'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fictional encrypted document export',
          style: editorial(c, 24)),
        const SizedBox(height: 10),
        Text('Choose a destination in Android’s system file picker. '
          'Only an authenticated encrypted archive is written. The app '
          'then reads the document back to check its bytes. This does '
          'not establish recoverability on a different device.',
          key: const ValueKey('external-export-warning'),
          style: TextStyle(color: c.secondary, height: 1.5)),
        const SizedBox(height: 13),
        Text('The separate 43-character recovery key must be recorded '
          'OFF this device, ideally on paper, and kept away from the '
          'encrypted file. Do not screenshot, email or message the key. '
          'This app does not retain it.',
          key: const ValueKey('external-export-key-warning'),
          style: TextStyle(color: c.clay, height: 1.5, fontSize: 13)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('external-export-start'),
          onPressed: _working || _receipt != null ? null :
              () => _activeWork = _begin(),
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text('Export fictional encrypted file'),
        ),
        if (_working) const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(
            key: ValueKey('external-export-progress'))),
        if (_message != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_message!,
            key: const ValueKey('external-export-message'),
            style: TextStyle(color: c.clay, height: 1.5)),
        ),
        if (_receipt != null) ...[
          const SizedBox(height: 16),
          Text('Encrypted file written and read back',
            key: const ValueKey('external-export-success'),
            style: TextStyle(color: c.success,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('MANUAL RECOVERY KEY · Write this on paper. '
            'It is shown only until you leave this screen.',
            style: TextStyle(color: c.ink,
              fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.paper, border: Border.all(color: c.stroke),
              borderRadius: BorderRadius.circular(12)),
            child: Text(_receipt!.manualRecoveryKey,
              key: const ValueKey('external-recovery-key'),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.ink,
                fontFamily: 'monospace', fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: 1.0)),
          ),
          const SizedBox(height: 12),
          Text('NOT A VERIFIED BACKUP · A document provider readback '
            'passed, but an independently stored key and clean-device '
            'restore have not been demonstrated.',
            key: const ValueKey('external-export-not-recoverable'),
            style: TextStyle(color: c.clay, height: 1.5,
              fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('external-export-dismiss-key'),
            onPressed: _forgetKey,
            child: const Text('Hide this key permanently'),
          ),
        ],
      ],
    );
  }
}
