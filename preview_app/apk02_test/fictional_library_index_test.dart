// Pure fictional search and sort behavior. No disk or user-entered text.
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_preview/fictional_library_index.dart';

Map<String, Object?> entry(
  String id, String title, String body, int at, {
  bool trashed = false,
}) => {
  'id': id, 'title': title, 'body': body,
  'updatedAtMs': at, 'deletedAtMs': trashed ? at : null,
};

void main() {
  final rows = [
    entry('id-b', 'The Imagined Lantern', 'First fictional walk', 200),
    entry('id-c', 'A Quiet Afternoon', 'తెలుగు కథ', 100),
    entry('id-a', 'An Imagined Beginning', 'An afternoon by the sea', 200),
    entry('id-d', 'Trashed afternoon', 'తెలుగు', 300, trashed: true),
  ];

  test('newest sort is stable for matching timestamps and excludes Trash', () {
    final visible = FictionalLibraryIndex.visible(source: rows);
    expect(visible.map((r) => r['id']).toList(), ['id-a', 'id-b', 'id-c']);
    expect(visible.any((r) => r['id'] == 'id-d'), isFalse);
  });

  test('oldest sort is deterministic without mutation of worker rows', () {
    final oldOrder = FictionalLibraryIndex.visible(
      source: rows, order: FictionalPageOrder.oldest);
    expect(oldOrder.map((r) => r['id']).toList(), ['id-c', 'id-a', 'id-b']);
    expect(rows.first['id'], 'id-b');
  });

  test('title sort is case-insensitive and deterministic', () {
    final sorted = FictionalLibraryIndex.visible(
      source: rows, order: FictionalPageOrder.title);
    expect(sorted.map((r) => r['id']).toList(), ['id-c', 'id-a', 'id-b']);
  });

  test('preset searches match title and body including Telugu', () {
    final telugu = FictionalLibraryIndex.visible(
      source: rows, filter: FictionalPageFilter.telugu);
    expect(telugu.map((e) => e['id']).toList(), ['id-c']);

    final afternoon = FictionalLibraryIndex.visible(
      source: rows, filter: FictionalPageFilter.afternoon);
    expect(afternoon.map((e) => e['id']).toList(), ['id-a', 'id-c']);

    final imagined = FictionalLibraryIndex.visible(
      source: rows, filter: FictionalPageFilter.imagined);
    expect(imagined.map((e) => e['id']).toList(), ['id-a', 'id-b']);
  });

  test('no results and missing phrases do not manufacture a journal', () {
    final unmatched = FictionalLibraryIndex.visible(
      source: [entry('safe', 'A Winter Scene', 'pure fiction', 1)],
      filter: FictionalPageFilter.telugu);
    expect(unmatched, isEmpty);
    expect(FictionalLibraryIndex.queryFor(FictionalPageFilter.all), isEmpty);
  });

  test('returned result is unmodifiable, original source remains usable', () {
    final result = FictionalLibraryIndex.visible(source: rows);
    expect(() => result.add(entry('bad', 'Private', 'Not allowed', 1)),
        throwsUnsupportedError);
    expect(rows, hasLength(4));
  });
}
