// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
/// APK02 read-only recovery assessment display. FICTIONAL FIXTURES ONLY.
///
/// This component has NO recover/delete/retry buttons. The verdict is supplied
/// by an independently key-authenticated, background-isolate inspection of
/// encrypted COPIES; showing a favorable result never approves publication.
library;

import 'package:flutter/material.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';

import 'visuals.dart';

class RecoveryAssessmentReview extends StatelessWidget {
  final RestoreAssessment assessment;
  final bool dark;

  const RecoveryAssessmentReview({
    super.key,
    required this.assessment,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = JournalColors(dark);
    final report = assessment;
    final (title, explanation, icon) = switch (report.status) {
      RestoreAssessmentStatus.verifiedQuarantined => (
        'Encrypted records match',
        'The inspected copy matches the authenticated backup. '
        'The original interrupted restore is still quarantined. '
        'Nothing has been published, replaced or deleted.',
        Icons.verified_user_outlined,
      ),
      RestoreAssessmentStatus.incomplete => (
        'Interrupted restore detected',
        'The staging files are incomplete. They have been left untouched. '
        'Do not assume this journal is recoverable.',
        Icons.pending_outlined,
      ),
      RestoreAssessmentStatus.blocked => (
        'Unrecognized restore files',
        'The folder cannot be assessed safely. No automatic recovery or '
        'cleanup will be attempted.',
        Icons.shield_outlined,
      ),
      RestoreAssessmentStatus.untrustedArchive => (
        'Backup not authenticated',
        'The independent backup and recovery key could not be verified. '
        'No stored journal files were changed.',
        Icons.key_off_outlined,
      ),
      RestoreAssessmentStatus.notVerified => (
        'Journal contents not verified',
        'The encrypted staged copy could not be authenticated against '
        'the backup. Its files remain untouched.',
        Icons.error_outline,
      ),
    };

    final isMatch = report.isAuthenticatedMatch;
    return Semantics(
      container: true,
      label: 'Recovery assessment: ' + title,
      child: Container(
        key: const ValueKey('recovery-assessment-review'),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: c.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RESTORE REVIEW · TEST DATA ONLY',
              style: TextStyle(color: c.secondary, fontSize: 11,
                letterSpacing: 1.1, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Icon(icon, color: isMatch ? c.success : c.clay,
              size: 32, semanticLabel: 'Recovery status'),
            const SizedBox(height: 10),
            Text(title, key: const ValueKey('recovery-assessment-title'),
              style: editorial(c, 25)),
            const SizedBox(height: 12),
            Text(explanation, key: const ValueKey('recovery-assessment-detail'),
              style: TextStyle(color: c.secondary, height: 1.55,
                fontSize: 14)),
            if (isMatch) ...[
              const SizedBox(height: 14),
              Text(
                'Verified counts: ' + report.journalCount.toString() +
                ' journals · ' + report.entryCount.toString() +
                ' entries · ' + report.revisionCount.toString() +
                ' revisions · ' + report.attachmentCount.toString() +
                ' attachments',
                key: const ValueKey('recovery-assessment-counts'),
                style: TextStyle(color: c.ink, fontSize: 13, height: 1.5),
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: c.stroke),
            const SizedBox(height: 10),
            Text('No recovery or deletion is performed on this screen.',
              key: const ValueKey('recovery-no-destructive-action'),
              style: TextStyle(color: c.clay, fontWeight: FontWeight.w600,
                fontSize: 12, height: 1.4)),
            const SizedBox(height: 8),
            Text('Not approved for real personal journal data.',
              style: TextStyle(color: c.secondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
