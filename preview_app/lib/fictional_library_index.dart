/// Pure, bounded in-memory presentation index for APK02 fictional journal rows.
///
/// All records originate in the encrypted JournalEditorWorker. This index is
/// ephemeral: never persist search terms, plaintext titles, snippets or sort
/// results. The diagnostic only exposes predefined fictional query presets.
library;

enum FictionalPageFilter {
  all,
  telugu,
  afternoon,
  imagined,
}

enum FictionalPageOrder { newest, oldest, title }

class FictionalLibraryIndex {
  const FictionalLibraryIndex._();

  static String queryFor(FictionalPageFilter filter) => switch (filter) {
    FictionalPageFilter.all => '',
    FictionalPageFilter.telugu => 'తెలుగు',
    FictionalPageFilter.afternoon => 'afternoon',
    FictionalPageFilter.imagined => 'imagined',
  };

  /// Search across title and body already decrypted inside the active worker
  /// session, without a disk index, network call or permanent plaintext cache.
  /// A deterministic ID tie-breaker prevents apparent random order for entries
  /// that were written in the same millisecond.
  static List<Map<String, Object?>> visible({
    required List<Map<String, Object?>> source,
    FictionalPageFilter filter = FictionalPageFilter.all,
    FictionalPageOrder order = FictionalPageOrder.newest,
  }) {
    final q = queryFor(filter).toLowerCase();
    final result = <Map<String, Object?>>[
      for (final row in source)
        if (row['deletedAtMs'] == null &&
            (q.isEmpty ||
              (row['title'] as String).toLowerCase().contains(q) ||
              (row['body'] as String).toLowerCase().contains(q)))
          row,
    ];
    int compareStable(Map<String, Object?> a, Map<String, Object?> b) {
      final byId = (a['id'] as String).compareTo(b['id'] as String);
      return byId;
    }
    result.sort((a, b) {
      final diff = switch (order) {
        FictionalPageOrder.newest =>
          (b['updatedAtMs'] as int).compareTo(a['updatedAtMs'] as int),
        FictionalPageOrder.oldest =>
          (a['updatedAtMs'] as int).compareTo(b['updatedAtMs'] as int),
        FictionalPageOrder.title =>
          (a['title'] as String).toLowerCase()
            .compareTo((b['title'] as String).toLowerCase()),
      };
      return diff == 0 ? compareStable(a, b) : diff;
    });
    return List<Map<String, Object?>>.unmodifiable(result);
  }
}
