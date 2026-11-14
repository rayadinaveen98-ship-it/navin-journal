// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK02 read-only, fictional-only app navigation for interrupted restore
/// inspection. Not a consumer backup, resume, discard, or recovery interface.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';
import 'package:navin_journal_editor/fictional_recovery_rehearsal.dart';

import 'recovery_assessment_review.dart';
import 'visuals.dart';

class RecoverySafetyScreen extends StatefulWidget {
  final Directory privateRoot;
  /// Optional injected inventory for deterministic Flutter tests. The actual
  /// Android app leaves this null and scans its real private filesystem.
  final Future<List<StagingObservation>> Function(Directory)? inventoryLoader;
  /// Only a test caller holding the separately authenticated archive AND the
  /// staged database key may provide this. Never infer keys from filenames.
  final Future<RestoreAssessment> Function()? authenticatedAssessment;
  /// Debug-only: user requests an ephemeral encrypted export -> new-vault
  /// restore -> independent reopen. No archive or key is exported or kept.
  final Future<FictionalRecoveryRehearsalReport> Function()? rehearsal;

  const RecoverySafetyScreen({
    super.key,
    required this.privateRoot,
    this.authenticatedAssessment,
    this.inventoryLoader,
    this.rehearsal,
  });

  @override
  State<RecoverySafetyScreen> createState() => RecoverySafetyScreenState();
}

class RecoverySafetyScreenState extends State<RecoverySafetyScreen> {
  bool _scanning = true;
  bool _assessing = false;
  bool _rehearsing = false;
  FictionalRecoveryRehearsalReport? _rehearsalReport;
  String? _rehearsalError;
  int? _candidates;
  String? _error;
  RestoreAssessment? _report;
  Future<void>? _activeWork;

  /// Test harnesses can await real filesystem/worker completion rather than
  /// trying to advance fake Flutter time around native asynchronous I/O.
  @visibleForTesting
  Future<void> waitForIdle() async => await _activeWork;

  @override
  void initState() {
    super.initState();
    _activeWork = _scan();
  }

  Future<void> _scan() async {
    if (!mounted || _assessing || _rehearsing) return;
    setState(() {
      _scanning = true;
      _error = null;
      _report = null; // Never retain a stale assessment after re-scan.
      _candidates = null;
    });
    try {
      // This is ONLY a bounded read-only candidate inventory. It does not
      // open, decrypt, delete, rename or clean up any staging directory.
      final items = await (widget.inventoryLoader ?? RestoreStagingInventory.inspect)(widget.privateRoot);
      if (mounted) setState(() => _candidates = items.length);
    } on StagingInventoryLimitExceeded {
      if (mounted) setState(() =>
          _error = 'Too many interrupted restore candidates to assess safely.');
    } catch (_) {
      if (mounted) setState(() =>
          _error = 'Restore safety inventory is unavailable. No files were changed.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _assess() async {
    final callback = widget.authenticatedAssessment;
    if (callback == null || _candidates == null || _candidates == 0 ||
        _assessing || _scanning || _rehearsing || !mounted) return;
    setState(() {
      _assessing = true;
      _report = null;
      _error = null;
    });
    try {
      final result = await callback();
      if (mounted) setState(() => _report = result);
    } catch (_) {
      if (mounted) setState(() => _error =
          'The encrypted assessment could not be verified. No recovery was performed.');
    } finally {
      if (mounted) setState(() => _assessing = false);
    }
  }

  /// A synthetic, in-memory *rehearsal*, never a user-facing backup or
  /// authorized restore. Source journal and unknown stages remain untouched.
  Future<void> _runRehearsal() async {
    final callback = widget.rehearsal;
    if (callback == null || _rehearsing || _assessing || _scanning ||
        !mounted) return;
    setState(() {
      _rehearsing = true;
      _rehearsalReport = null;
      _rehearsalError = null;
    });
    try {
      final report = await callback();
      // A positive result MUST NEVER be interpreted as an external backup.
      if (report.isOffDeviceBackup || report.replacedActiveJournal) {
        throw const RecoveryRehearsalUnavailable();
      }
      if (mounted) setState(() => _rehearsalReport = report);
    } catch (_) {
      if (mounted) setState(() => _rehearsalError =
          'Fictional encrypted recovery test did not verify. '
          'Your current notebook was not replaced.');
    } finally {
      if (mounted) setState(() => _rehearsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return Column(
      key: const ValueKey('recovery-safety-screen'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Restore Safety', style: editorial(c, 34)),
        const SizedBox(height: 10),
        Text('A quiet, read-only check of interrupted restoration files.',
          style: TextStyle(color: c.secondary, height: 1.5)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.subtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FICTIONAL DATA · ENGINEERING REVIEW',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 11, letterSpacing: 1, color: c.action)),
              const SizedBox(height: 11),
              Text('This screen does not restore, discard, publish, '
                'or overwrite your current journal. An optional fictional '
                'rehearsal uses a separate disposable vault, never an '
                'off-device backup. An interrupted folder is not proof '
                'of recoverable content.',
                key: const ValueKey('recovery-read-only-disclaimer'),
                style: TextStyle(color: c.secondary, height: 1.5,
                    fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_scanning)
          const LinearProgressIndicator(key: ValueKey('recovery-scan-progress'))
        else if (_error != null)
          Text(_error!, key: const ValueKey('recovery-scan-error'),
            style: TextStyle(color: c.clay, height: 1.5))
        else
          Text(
            _candidates == 0
                ? 'No interrupted restore folders detected.'
                : 'Interrupted restore candidates detected: $_candidates',
            key: const ValueKey('recovery-candidate-count'),
            style: editorial(c, 19),
          ),
        const SizedBox(height: 13),
        Text('Candidate count comes from a read-only scan; '
          'no keys, journal titles, or private text are displayed.',
          style: TextStyle(color: c.secondary, fontSize: 12,
            height: 1.5)),
        const SizedBox(height: 17),
        OutlinedButton.icon(
          key: const ValueKey('recovery-rescan'),
          onPressed: _scanning || _assessing || _rehearsing ? null : () {
            _activeWork = _scan();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Check folders again'),
        ),
        if (_candidates != null && _candidates! > 0) ...[
          const SizedBox(height: 18),
          if (widget.authenticatedAssessment != null)
            FilledButton.icon(
              key: const ValueKey('recovery-assess-test-fixture'),
              onPressed: _scanning || _assessing || _rehearsing
                  ? null : () {
                    _activeWork = _assess();
                  },
              icon: const Icon(Icons.security),
              label: const Text('Verify fictional stage'),
            )
          else
            Text('Authenticated review requires the separately retained '
              'encrypted backup and the correct staging key. These are '
              'not available in this diagnostic screen.',
              key: const ValueKey('recovery-assessment-locked'),
              style: TextStyle(color: c.secondary, fontSize: 13,
                height: 1.5)),
        ],
        if (_assessing) ...[
          const SizedBox(height: 19),
          const LinearProgressIndicator(
            key: ValueKey('recovery-assessment-progress')),
        ],
        if (_report != null) ...[
          const SizedBox(height: 20),
          RecoveryAssessmentReview(assessment: _report!),
        ],
        if (widget.rehearsal != null) ...[
          const SizedBox(height: 26),
          Divider(color: c.stroke),
          const SizedBox(height: 15),
          Text('Fictional backup rehearsal',
            style: editorial(c, 24)),
          const SizedBox(height: 10),
          Text('Tests a real encrypted snapshot and restore into a '
            'separate disposable vault. It checks the restored records '
            'and destroys temporary keys and data. Nothing is saved '
            'off-device, and your current journal is never replaced.',
            key: const ValueKey('rehearsal-no-backup-warning'),
            style: TextStyle(color: c.secondary, height: 1.5)),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            key: const ValueKey('recovery-run-rehearsal'),
            onPressed: _scanning || _assessing || _rehearsing ? null : () {
              _activeWork = _runRehearsal();
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Test fictional encrypted recovery'),
          ),
          if (_rehearsing) const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(
              key: ValueKey('rehearsal-progress')),
          ),
          if (_rehearsalError != null)
            Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_rehearsalError!,
                key: const ValueKey('rehearsal-error'),
                style: TextStyle(color: c.clay, height: 1.5))),
          if (_rehearsalReport != null) ...[
            const SizedBox(height: 13),
            Text('Independent encrypted reopen verified',
              key: const ValueKey('rehearsal-success'),
              style: TextStyle(color: c.success,
                fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Text(
              '${_rehearsalReport!.journals} notebooks · '
              '${_rehearsalReport!.entries} pages · '
              '${_rehearsalReport!.revisions} revisions · '
              '${_rehearsalReport!.attachments} attachments',
              key: const ValueKey('rehearsal-counts'),
              style: TextStyle(color: c.ink, height: 1.5)),
            const SizedBox(height: 7),
            Text('NOT BACKED UP · No archive or recovery key '
              'was saved outside this temporary test.',
              key: const ValueKey('rehearsal-not-backup'),
              style: TextStyle(color: c.clay,
                fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ],
        const SizedBox(height: 20),
        Text('No private diary input or cleanup of unknown restore folders is permitted.',
          style: TextStyle(color: c.clay, height: 1.5, fontSize: 12)),
      ],
    );
  }
}
