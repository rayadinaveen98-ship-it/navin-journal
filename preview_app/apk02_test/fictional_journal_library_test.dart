// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
// Full encrypted Library → Reader → Writer Flutter integration.
// Fictional data and disposable SQLite3MultipleCiphers vault ONLY.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
import 'package:navin_journal_core/restore_staging_inventory.dart';
import 'package:navin_journal_core/restore_staging_assessment.dart';
import 'package:navin_journal_editor/journal_editor_isolate.dart';
import 'package:navin_journal_editor/portable_recovery_worker.dart';
import 'package:navin_journal_encrypted_spike/encrypted_journal_spike.dart';
import 'package:navin_journal_recovery_archive_spike/product_encrypted_archive.dart';
import 'package:navin_journal_recovery_archive_spike/recovery_archive.dart';
import 'package:navin_journal_preview/fictional_journal_library.dart';
import 'package:navin_journal_preview/recovery_safety_screen.dart';

void main() {
  late Directory temp;
  late String path;
  late TestVaultKey key;
  late JournalEditorWorker worker;
  late String journal;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('nj-library-fixture-');
    path = temp.path + Platform.pathSeparator + 'encrypted.sqlite3';
    key = TestVaultKey.random();
    worker = await JournalEditorWorker.open(path, key: key, create: true);
    journal = await worker.createJournal('Fictional Pages');
  });

  tearDown(() async {
    await worker.close();
    key.destroy();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  // The encrypted worker is a real Dart isolate, not a fake-async timer.
  // Give the worker event loop a short real-async turn before settling frames.
  Future<void> settleRealWorker(WidgetTester tester) async {
    // Render the route before waiting on its native filesystem / isolate
    // work; Flutter's fake time cannot complete native Directory streams.
    await tester.pump();
    await tester.runAsync(() async {
      final recoveryRoute = find.byType(RecoverySafetyScreen);
      if (recoveryRoute.evaluate().isNotEmpty) {
        await tester.state<RecoverySafetyScreenState>(recoveryRoute)
            .waitForIdle();
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 140));
      }
    });
    await tester.pumpAndSettle();
  }

  /// Flutter testWidgets runs with fake async; background isolate I/O
  /// must be awaited within the binding's real async zone instead.
  Future<T> workerCall<T>(
    WidgetTester tester, Future<T> Function() operation,
  ) async {
    final output = await tester.runAsync(operation);
    if (output == null) throw StateError('Encrypted worker gave no result');
    return output;
  }

  Future<void> workerVoid(
    WidgetTester tester, Future<void> Function() operation,
  ) async {
    final completed = await tester.runAsync(() async {
      await operation();
      return true;
    });
    if (completed != true) {
      throw StateError('Encrypted worker did not complete');
    }
  }

  Future<void> mount(WidgetTester tester, {
    Directory? recoveryRoot,
    Future<RestoreAssessment> Function()? assessment,
    Future<List<StagingObservation>> Function(Directory)? inventoryLoader,
  }) async {
    await tester.pumpWidget(MaterialApp(home: FictionalJournalLibrary(
      worker: worker, journalId: journal,
      recoveryPrivateRoot: recoveryRoot,
      authenticatedAssessment: assessment,
      inventoryLoader: inventoryLoader,
    )));
    await settleRealWorker(tester);
  }

  Future<void> tapVisible(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settleRealWorker(tester);
  }

  testWidgets('empty encrypted library opens fictional studio and saves',
      (tester) async {
    await mount(tester);
    expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
    await tapVisible(tester, 'library-create-fictional');
    expect(find.byKey(const ValueKey('connected-title')), findsOneWidget);
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('connected-title'))).readOnly, isTrue);
    await tapVisible(tester, 'insert-fictional-sample');
    expect(find.text('Saved locally · version 1'), findsOneWidget);
    await tapVisible(tester, 'connected-back');
    final entries = await workerCall(tester, () => worker.listEntries(journalId: journal));
    expect(entries.length, 1);
    expect(entries.single['title'], 'A quiet afternoon');
    expect(entries.single['version'], 1);
    expect(find.byKey(ValueKey(
      'library-open-' + (entries.single['id'] as String))), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reader shows actual encrypted entry; editing preserves revision',
      (tester) async {
    final page = await workerCall(tester, () => worker.startSession(journalId: journal));
    page.controller.update(
      title: 'A quiet afternoon',
      body: 'First fictional memory. తెలుగు sample · an imagined day. 🌿',
    );
    await workerVoid(tester, page.save);
    final id = (await workerCall(tester, page.persistedEntryId))!;
    expect(await workerCall(tester, page.closeSafely), isTrue);

    await mount(tester);
    await tapVisible(tester, 'library-open-' + id);
    expect(find.byKey(const ValueKey('reader-title')), findsOneWidget);
    expect(find.text('Encrypted version 1'), findsOneWidget);
    await tapVisible(tester, 'reader-edit');
    await tapVisible(tester, 'insert-fictional-sample');
    expect(find.text('Saved locally · version 2'), findsOneWidget);
    await tapVisible(tester, 'connected-back');
    await tapVisible(tester, 'library-open-' + id);
    expect(find.text('Encrypted version 2'), findsOneWidget);
    expect(find.textContaining('Second fictional memory'), findsOneWidget);
    final revisions = await workerCall(tester, () => worker.readRevisions(id));
    expect(revisions.length, 1);
    expect(revisions.single['version'], 1);
    expect(revisions.single['body'], contains('First fictional memory'));
    expect((await workerCall(tester, () => worker.readEntry(id)))!['version'], 2);
    await tapVisible(tester, 'reader-back');
    expect(find.text('Saved pages'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('library reload after independent encrypted worker reopen',
      (tester) async {
    final session = await workerCall(tester, () => worker.startSession(journalId: journal));
    session.controller.update(
      title: 'Original fictional entry',
      body: 'Nothing personal or private',
    );
    await workerVoid(tester, session.save);
    final id = (await workerCall(tester, session.persistedEntryId))!;
    expect(await workerCall(tester, session.closeSafely), isTrue);
    await workerVoid(tester, worker.close);
    worker = await workerCall(tester, () => JournalEditorWorker.open(path, key: key));
    await mount(tester);
    await tapVisible(tester, 'library-open-' + id);
    expect(find.text('Original fictional entry'), findsOneWidget);
    expect(find.textContaining('Nothing personal'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('narrow phone and tablet render encrypted library without overflow',
      (tester) async {
    for (final size in [const Size(360, 720), const Size(1024, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await mount(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('library-create-fictional')));
      expect(find.byKey(const ValueKey('library-create-fictional')),
        findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Library recovery safety route scans and returns without mutation',
      (tester) async {
    final items = await workerCall(tester,
        () => RestoreStagingInventory.inspect(temp));
    await mount(tester, recoveryRoot: temp,
      inventoryLoader: (_) async => items);
    await tapVisible(tester, 'library-review-recovery');
    expect(find.byKey(const ValueKey('recovery-safety-screen')), findsOneWidget);
    expect(find.text('No interrupted restore folders detected.'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-assess-test-fixture')), findsNothing);
    expect(find.byKey(const ValueKey('recovery-read-only-disclaimer')),
        findsOneWidget);
    await tapVisible(tester, 'recovery-rescan');
    expect(find.text('No interrupted restore folders detected.'), findsOneWidget);
    await tapVisible(tester, 'reader-back');
    expect(find.byKey(const ValueKey('library-create-fictional')), findsOneWidget);
    expect(await workerCall(tester, () => worker.integrityCheck()), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unknown abandoned stage has no usable assessment or delete',
      (tester) async {
    final orphan = Directory(temp.path + '/' +
        NativeRestorePublisher.stagePrefix + 'unknownABC123')..createSync();
    File(orphan.path + '/journal.sqlite3').writeAsBytesSync([1, 2, 3]);
    final items = await workerCall(tester,
        () => RestoreStagingInventory.inspect(temp));
    await mount(tester, recoveryRoot: temp,
      inventoryLoader: (_) async => items);
    await tapVisible(tester, 'library-review-recovery');
    expect(find.text('Interrupted restore candidates detected: 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-assessment-locked')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-assess-test-fixture')),
        findsNothing);
    expect(find.textContaining('No restore or delete actions'),
        findsNothing); // The safe disclaimer has different, explicit copy.
    expect(orphan.existsSync(), isTrue);
    await tapVisible(tester, 'reader-back');
    expect(File(orphan.path + '/journal.sqlite3').readAsBytesSync(),
        [1, 2, 3]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('real encrypted assessment is reachable but never promotes stage',
      (tester) async {
    final session = await workerCall(tester, () =>
        worker.startSession(journalId: journal));
    session.controller.update(
      title: 'An imaginary page',
      body: 'Only fictional content · తెలుగు',
    );
    await workerVoid(tester, session.save);
    expect(await workerCall(tester, session.closeSafely), isTrue);

    final recoveryKey = RecoveryKey.random();
    final stageKey = TestVaultKey.random();
    try {
      final encryptedArchive = await workerCall(tester,
          () => worker.exportRecoveryArchive(recoveryKey));
      final stageName = NativeRestorePublisher.stagePrefix + 'fixtureABC123';
      final stage = Directory(temp.path + '/' + stageName)..createSync();
      final expected = await workerCall(tester, () =>
          ProductEncryptedArchiveCodec().verify(
            recoveryKey: recoveryKey, archive: encryptedArchive));
      await workerVoid(tester, () async {
        final vault = JournalVault.open(
          stage.path + '/journal.sqlite3', key: stageKey, create: true,
        );
        try {
          await vault.importIntoEmpty(expected);
        } finally {
          vault.close();
        }
      });
      final items = await workerCall(tester,
          () => RestoreStagingInventory.inspect(temp));
      final authenticated = await workerCall(tester,
          () => PortableRecoveryWorker.assessQuarantinedStage(
            privateParent: temp,
            candidateBasename: stageName,
            encryptedArchive: encryptedArchive,
            recoveryKey: recoveryKey,
            stagedDatabaseKey: stageKey,
          ));
      expect(authenticated.isAuthenticatedMatch, isTrue);
      await mount(tester, recoveryRoot: temp,
        inventoryLoader: (_) async => items,
        assessment: () async => authenticated,
      );
      await tapVisible(tester, 'library-review-recovery');
      expect(find.text('Interrupted restore candidates detected: 1'),
          findsOneWidget);
      await tapVisible(tester, 'recovery-assess-test-fixture');
      expect(find.text('Encrypted records match'), findsOneWidget);
      expect(find.textContaining('still quarantined'), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-no-destructive-action')),
          findsOneWidget);
      expect(stage.existsSync(), isTrue);
      expect(Directory(temp.path + '/restored').existsSync(), isFalse);
      await tapVisible(tester, 'reader-back');
      expect(find.byKey(const ValueKey('library-create-fictional')),
          findsOneWidget);
      expect(await workerCall(tester, () => worker.integrityCheck()), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      recoveryKey.destroy();
      stageKey.destroy();
    }
  });


  testWidgets('encrypted Library presets filter actual Telugu/English saved pages',
      (tester) async {
    Future<String> seed(String title, String body) async {
      final session = await workerCall(tester, () =>
          worker.startSession(journalId: journal));
      session.controller.update(title: title, body: body);
      await workerVoid(tester, session.save);
      final id = (await workerCall(tester, session.persistedEntryId))!;
      expect(await workerCall(tester, session.closeSafely), isTrue);
      return id;
    }

    final afternoonId = await seed(
      'A Quiet Afternoon', 'A completely invented moment.',
    );
    final teluguId = await seed(
      'Moonlit Room', 'తెలుగు fictional example',
    );
    await mount(tester);
    expect(find.byKey(ValueKey('library-open-' + afternoonId)), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + teluguId)), findsOneWidget);
    expect(find.textContaining('2 of 2 fictional pages'), findsOneWidget);

    await tapVisible(tester, 'library-filter-telugu');
    expect(find.byKey(ValueKey('library-open-' + teluguId)), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + afternoonId)), findsNothing);
    expect(find.textContaining('1 of 2 fictional pages'), findsOneWidget);

    await tapVisible(tester, 'library-filter-afternoon');
    expect(find.byKey(ValueKey('library-open-' + afternoonId)), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + teluguId)), findsNothing);

    await tapVisible(tester, 'library-filter-imagined');
    expect(find.byKey(const ValueKey('library-filter-empty')), findsOneWidget);

    await tapVisible(tester, 'library-filter-all');
    expect(find.byKey(ValueKey('library-open-' + afternoonId)), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + teluguId)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reader shows encrypted historical version without restoring it',
      (tester) async {
    final session = await workerCall(tester, () =>
        worker.startSession(journalId: journal));
    session.controller.update(
      title: 'First made-up chapter', body: 'Original fictional scene తెలుగు',
    );
    await workerVoid(tester, session.save);
    final id = (await workerCall(tester, session.persistedEntryId))!;
    session.controller.update(
      title: 'Second made-up chapter', body: 'Current fictional scene only',
    );
    await workerVoid(tester, session.save);
    expect(await workerCall(tester, session.closeSafely), isTrue);

    await mount(tester);
    await tapVisible(tester, 'library-open-' + id);
    expect(find.text('Second made-up chapter'), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-history-version-1')), findsNothing);

    await tapVisible(tester, 'reader-history');
    expect(find.byKey(const ValueKey('reader-history-safe-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-history-version-1')), findsOneWidget);
    expect(find.text('First made-up chapter'), findsOneWidget);
    expect(find.textContaining('Original fictional scene'), findsOneWidget);
    expect(find.text('Second made-up chapter'), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-history-error')), findsNothing);

    // Seeing an old version never writes it back over the current record.
    final current = await workerCall(tester, () => worker.readEntry(id));
    expect(current!['version'], 2);
    expect(current['title'], 'Second made-up chapter');
    expect(await workerCall(tester, () => worker.historyCount(id)), 1);
    await tapVisible(tester, 'reader-back');
    expect(find.byKey(const ValueKey('reader-history-version-1')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a first version exposes only an explicit empty history state',
      (tester) async {
    final session = await workerCall(tester, () =>
        worker.startSession(journalId: journal));
    session.controller.update(
      title: 'Only fictional version', body: 'One saved test chapter',
    );
    await workerVoid(tester, session.save);
    final id = (await workerCall(tester, session.persistedEntryId))!;
    expect(await workerCall(tester, session.closeSafely), isTrue);
    await mount(tester);
    await tapVisible(tester, 'library-open-' + id);
    await tapVisible(tester, 'reader-history');
    expect(find.byKey(const ValueKey('reader-history-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-history-version-1')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('encrypted journal switching never mixes saved pages',
      (tester) async {
    final second = await workerCall(tester,
      () => worker.createJournal('Second Fictional Notebook'));
    final session = await workerCall(tester,
      () => worker.startSession(journalId: second));
    session.controller.update(
      title: 'Another imaginary notebook',
      body: 'A fictional passage in journal two · తెలుగు',
    );
    await workerVoid(tester, session.save);
    final secondEntry = (await workerCall(tester,
      session.persistedEntryId))!;
    expect(await workerCall(tester, session.closeSafely), isTrue);

    await mount(tester);
    expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + secondEntry)), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('library-journal-switch')));
    await tester.tap(find.byKey(const ValueKey('library-journal-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second Fictional Notebook').last);
    await settleRealWorker(tester);
    expect(find.byKey(ValueKey('library-open-' + secondEntry)),
      findsOneWidget);

    await tapVisible(tester, 'library-open-' + secondEntry);
    expect(find.text('Another imaginary notebook'), findsOneWidget);
    expect(find.textContaining('journal two'), findsOneWidget);
    await tapVisible(tester, 'reader-back');

    // Scripted save is scoped to the explicitly selected journal.
    await tapVisible(tester, 'library-create-fictional');
    await tapVisible(tester, 'insert-fictional-sample');
    await tapVisible(tester, 'connected-back');
    final secondPages = await workerCall(tester,
      () => worker.listEntries(journalId: second));
    final firstPages = await workerCall(tester,
      () => worker.listEntries(journalId: journal));
    expect(secondPages.length, 2);
    expect(firstPages, isEmpty);
    expect(secondPages.every((row) => row['journalId'] == second), isTrue);

    await tester.ensureVisible(
      find.byKey(const ValueKey('library-journal-switch')));
    await tester.tap(find.byKey(const ValueKey('library-journal-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fictional Pages').last);
    await settleRealWorker(tester);
    expect(find.byKey(ValueKey('library-open-' + secondEntry)), findsNothing);
    expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('predefined fictional notebook persists without plaintext selection',
      (tester) async {
    await mount(tester);
    await tapVisible(tester, 'library-create-journal');
    final journals = await workerCall(tester, worker.listJournals);
    expect(journals.length, 2);
    final newId = journals.firstWhere(
      (j) => j['name'] == 'Imagined Notebook 2')['id'] as String;
    // Creation and the subsequent encrypted shelf refresh are two separate
    // isolate operations. Wait for the UI's second acknowledgement instead
    // of asserting while Flutter's fake-async frame is still pending.
    await settleRealWorker(tester);
    expect(find.text('Imagined Notebook 2'), findsWidgets);

    await tapVisible(tester, 'library-create-fictional');
    await tapVisible(tester, 'insert-fictional-sample');
    await tapVisible(tester, 'connected-back');
    expect((await workerCall(tester,
      () => worker.listEntries(journalId: newId))).length, 1);
    expect(await workerCall(tester,
      () => worker.listEntries(journalId: journal)), isEmpty);

    // Restart the widget: the catalog is re-read from encrypted SQLite.
    // The starting selection is explicit and is not restored from a plaintext
    // preference, so the initial fictional journal opens again.
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester);
    expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-journal-switch')),
      findsOneWidget);
    expect((await workerCall(tester, worker.listJournals)).length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('archived encrypted notebooks can be read but not written',
      (tester) async {
    await workerVoid(tester, worker.close);
    late String archived;
    late String archivedEntry;
    final vault = JournalVault.open(path, key: key);
    try {
      archived = vault.createJournal('Archived Fictional Scenes');
      archivedEntry = vault.createEntry(
        journalId: archived,
        title: 'The imagined archive',
        body: 'A read-only fictional record',
      );
      vault.archiveJournal(archived, archived: true);
    } finally {
      vault.close();
    }
    worker = await workerCall(tester,
      () => JournalEditorWorker.open(path, key: key));
    await mount(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('library-journal-switch')));
    await tester.tap(find.byKey(const ValueKey('library-journal-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archived Fictional Scenes · archived').last);
    await settleRealWorker(tester);
    expect(find.byKey(const ValueKey('library-archived-readonly')),
      findsOneWidget);
    expect(tester.widget<FilledButton>(
        find.byKey(const ValueKey('library-create-fictional'))).onPressed,
      isNull);
    await tapVisible(tester, 'library-open-' + archivedEntry);
    expect(find.text('The imagined archive'), findsOneWidget);
    expect(tester.widget<FilledButton>(
        find.byKey(const ValueKey('reader-edit'))).onPressed, isNull);
    expect((await workerCall(tester,
        () => worker.readEntry(archivedEntry)))!['journalId'], archived);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fictional rename archive unarchive and Trash preserve encrypted history',
      (tester) async {
    await mount(tester);
    await tapVisible(tester, 'library-create-journal');
    final catalog = await workerCall(tester, worker.listJournals);
    final secondId = catalog.firstWhere(
      (j) => j['name'] == 'Imagined Notebook 2')['id'] as String;

    // Scripted v1 and v2 are persisted in this second journal only.
    await tapVisible(tester, 'library-create-fictional');
    await tapVisible(tester, 'insert-fictional-sample');
    await tapVisible(tester, 'connected-back');
    final firstPage = (await workerCall(tester,
      () => worker.listEntries(journalId: secondId))).single;
    final pageId = firstPage['id'] as String;
    await tapVisible(tester, 'library-open-' + pageId);
    await tapVisible(tester, 'reader-edit');
    await tapVisible(tester, 'insert-fictional-sample');
    await tapVisible(tester, 'connected-back');
    expect((await workerCall(tester,
        () => worker.readEntry(pageId)))!['version'], 2);

    await tapVisible(tester, 'library-journal-rename');
    expect(find.text('Imagined Notebook 2 · revised'), findsWidgets);
    expect((await workerCall(tester, worker.listJournals)).firstWhere(
      (j) => j['id'] == secondId)['name'], 'Imagined Notebook 2 · revised');

    await tapVisible(tester, 'library-journal-archive');
    expect(find.byKey(const ValueKey('library-archived-readonly')),
      findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('library-create-fictional'))).onPressed,
      isNull);
    await tapVisible(tester, 'library-open-' + pageId);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('reader-edit'))).onPressed, isNull);
    await tapVisible(tester, 'reader-back');

    await tapVisible(tester, 'library-journal-archive');
    expect(find.byKey(const ValueKey('library-archived-readonly')),
      findsNothing);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('library-create-fictional'))).onPressed,
      isNotNull);

    await tapVisible(tester, 'library-journal-trash');
    expect(find.byKey(const ValueKey('journal-trash-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('journal-trash-cancel')));
    await settleRealWorker(tester);
    expect((await workerCall(tester, () => worker.listJournals(
        includeTrash: true))).firstWhere(
        (j) => j['id'] == secondId)['deletedAtMs'], isNull);

    await tapVisible(tester, 'library-journal-trash');
    await tester.tap(find.byKey(const ValueKey('journal-trash-confirm')));
    await settleRealWorker(tester);
    expect(find.byKey(ValueKey('library-trashed-' + secondId)), findsOneWidget);
    expect(find.byKey(ValueKey('library-open-' + pageId)), findsNothing);
    final trashed = await workerCall(tester,
      () => worker.listJournals(includeTrash: true));
    expect(trashed.firstWhere(
        (j) => j['id'] == secondId)['deletedAtMs'], isNotNull);
    expect((await workerCall(tester,
        () => worker.listEntries(journalId: secondId,
          includeTrash: true))).single['version'], 2);

    await tapVisible(tester, 'library-restore-' + secondId);
    final restored = await workerCall(tester, worker.listJournals);
    expect(restored.firstWhere(
        (j) => j['id'] == secondId)['deletedAtMs'], isNull);
    expect(await workerCall(tester, () => worker.historyCount(pageId)), 1);
    expect((await workerCall(tester,
        () => worker.readEntry(pageId)))!['version'], 2);
    expect(find.byKey(ValueKey('library-trashed-' + secondId)), findsNothing);
    expect(await workerCall(tester, worker.integrityCheck), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('last accessible journal cannot be trashed in UI or worker',
      (tester) async {
    await mount(tester);
    expect(tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('library-journal-trash'))).onPressed, isNull);
    final rejected = await workerCall(tester, () async {
      try {
        await worker.manageFictionalJournal(
          journalId: journal, activeJournalId: journal,
          operation: 'trash');
        return false;
      } on JournalEditorWorkerUnavailable {
        return true;
      }
    });
    expect(rejected, isTrue);
    final journals = await workerCall(tester,
      () => worker.listJournals(includeTrash: true));
    expect(journals.length, 1);
    expect(journals.single['deletedAtMs'], isNull);
    expect(find.byKey(const ValueKey('library-empty')), findsOneWidget);
    expect(await workerCall(tester, worker.integrityCheck), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restore preserves archived state and does not replace current journal',
      (tester) async {
    await workerVoid(tester, worker.close);
    late String archivedId;
    late String pageId;
    final vault = JournalVault.open(path, key: key);
    try {
      archivedId = vault.createJournal('Imaginary Forgotten Journal');
      pageId = vault.createEntry(
        journalId: archivedId, title: 'Recovered imaginary page',
        body: 'Fictional content only · తెలుగు',
      );
      vault.archiveJournal(archivedId, archived: true);
      vault.trashJournal(archivedId);
    } finally {
      vault.close();
    }
    worker = await workerCall(tester,
        () => JournalEditorWorker.open(path, key: key));
    await mount(tester);
    expect(find.byKey(ValueKey('library-trashed-' + archivedId)),
      findsOneWidget);
    await tapVisible(tester, 'library-restore-' + archivedId);
    final catalog = await workerCall(tester, worker.listJournals);
    final found = catalog.firstWhere((j) => j['id'] == archivedId);
    expect(found['deletedAtMs'], isNull);
    expect(found['archived'], isTrue);
    expect(find.byKey(ValueKey('library-open-' + pageId)), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('library-journal-switch')));
    await tester.tap(find.byKey(const ValueKey('library-journal-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Imaginary Forgotten Journal · archived').last);
    await settleRealWorker(tester);
    expect(find.byKey(ValueKey('library-open-' + pageId)), findsOneWidget);
    expect(find.byKey(const ValueKey('library-archived-readonly')),
      findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('library-create-fictional'))).onPressed,
      isNull);
    expect(await workerCall(tester, worker.integrityCheck), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
