// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
// Full encrypted Library → Reader → Writer Flutter integration.
// Fictional data and disposable SQLite3MultipleCiphers vault ONLY.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_core/journal_vault.dart';
import 'package:navin_journal_core/native_restore_publisher.dart';
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
  }) async {
    await tester.pumpWidget(MaterialApp(home: FictionalJournalLibrary(
      worker: worker, journalId: journal,
      recoveryPrivateRoot: recoveryRoot,
      authenticatedAssessment: assessment,
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
    await mount(tester, recoveryRoot: temp);
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
    await mount(tester, recoveryRoot: temp);
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
      await mount(tester, recoveryRoot: temp,
        assessment: () => PortableRecoveryWorker.assessQuarantinedStage(
          privateParent: temp,
          candidateBasename: stageName,
          encryptedArchive: encryptedArchive,
          recoveryKey: recoveryKey,
          stagedDatabaseKey: stageKey,
        ),
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

}
