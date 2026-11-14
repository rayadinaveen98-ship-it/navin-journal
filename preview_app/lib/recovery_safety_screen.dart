// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
/// APK02 read-only, fictional-only app navigation for interrupted restore
/// inspection. Not a consumer backup, resume, discard, or recovery interface.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';

import 'recovery_assessment_review.dart';
import 'visuals.dart';

class RecoverySafetyScreen extends StatefulWidget {
  final Directory privateRoot;
  /// Only a test caller holding the separately authenticated archive AND the
  /// staged database key may provide this. Never infer keys from filenames.
  final Future<RestoreAssessment> Function()? authenticatedAssessment;

  const RecoverySafetyScreen({
    super.key,
    required this.privateRoot,
    this.authenticatedAssessment,
  });

  @override
  State<RecoverySafetyScreen> createState() => RecoverySafetyScreenState();
}

class RecoverySafetyScreenState extends State<RecoverySafetyScreen> {
  bool _scanning = true;
  bool _assessing = false;
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
    if (!mounted || _assessing) return;
    setState(() {
      _scanning = true;
      _error = null;
      _report = null; // Never retain a stale assessment after re-scan.
      _candidates = null;
    });
    try {
      // This is ONLY a bounded read-only candidate inventory. It does not
      // open, decrypt, delete, rename or clean up any staging directory.
      final rootPath = widget.privateRoot.absolute.path;
      final items = await Isolate.run(() =>
          RestoreStagingInventory.inspect(Directory(rootPath)));
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
        _assessing || _scanning || !mounted) return;
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
                'or overwrite a journal. A detected folder is not proof '
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
          onPressed: _scanning || _assessing ? null : () {
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
              onPressed: _scanning || _assessing
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
        const SizedBox(height: 20),
        Text('No private diary input or automatic cleanup is permitted.',
          style: TextStyle(color: c.clay, height: 1.5, fontSize: 12)),
      ],
    );
  }
}
