/// Read-only inventory of abandoned restore staging paths.
///
/// Sudden process termination can leave a private .navin-journal-restore-*
/// directory. A scanner must never treat a marker or folder name as proof
/// of ownership, validity or authorization to delete or resume a restore.
///
/// Fictional-only APK02 engineering feature. This intentionally has NO
/// delete, merge, promote, resume or plaintext entry access.
library;

import 'dart:io';

import 'native_restore_publisher.dart';

enum StagingObservationKind { directory, suspiciousNonDirectory }

class StagingObservation {
  final String path;
  final StagingObservationKind kind;
  final bool encryptedDatabaseObserved;
  final bool publicationMarkerObserved;

  const StagingObservation({
    required this.path,
    required this.kind,
    required this.encryptedDatabaseObserved,
    required this.publicationMarkerObserved,
  });

  /// A "complete-looking" staging directory is still UNTRUSTED.
  /// It needs independent key-bound archive verification. Never publish or
  /// delete solely because this flag is true.
  bool get potentiallyCompleteButUnverified =>
      kind == StagingObservationKind.directory &&
      encryptedDatabaseObserved && publicationMarkerObserved;
}

class StagingInventoryLimitExceeded implements Exception {
  const StagingInventoryLimitExceeded();
  @override
  String toString() => 'StagingInventoryLimitExceeded';
}

class RestoreStagingInventory {
  static const maxCandidates = 128;

  /// Lists top-level staging candidates under an explicitly supplied
  /// private parent. Files and symlinks with a matching name are reported as
  /// suspicious but never followed, read, renamed, deleted or overwritten.
  ///
  /// The caller must treat every observation as QUARANTINED, even when a
  /// non-secret readiness marker is present. An inventory is never a restore
  /// receipt, an authentication check or an instruction to clean up data.
  static Future<List<StagingObservation>> inspect(Directory parent) async {
    if (!await parent.exists()) {
      return const <StagingObservation>[];
    }
    final found = <StagingObservation>[];
    await for (final item in parent.list(followLinks: false)) {
      final name = item.uri.pathSegments
          .where((segment) => segment.isNotEmpty).last;
      if (!name.startsWith(NativeRestorePublisher.stagePrefix)) continue;
      if (found.length >= maxCandidates) {
        throw const StagingInventoryLimitExceeded();
      }
      final kind = await FileSystemEntity.type(
        item.path, followLinks: false,
      );
      if (kind != FileSystemEntityType.directory) {
        found.add(StagingObservation(
          path: item.path,
          kind: StagingObservationKind.suspiciousNonDirectory,
          encryptedDatabaseObserved: false,
          publicationMarkerObserved: false,
        ));
        continue;
      }
      final base = item.path + Platform.pathSeparator;
      final dbType = await FileSystemEntity.type(
        base + 'journal.sqlite3', followLinks: false,
      );
      final markerType = await FileSystemEntity.type(
        base + NativeRestorePublisher.markerName, followLinks: false,
      );
      found.add(StagingObservation(
        path: item.path,
        kind: StagingObservationKind.directory,
        encryptedDatabaseObserved: dbType == FileSystemEntityType.file,
        publicationMarkerObserved: markerType == FileSystemEntityType.file,
      ));
    }
    found.sort((a, b) => a.path.compareTo(b.path));
    return List<StagingObservation>.unmodifiable(found);
  }
}
