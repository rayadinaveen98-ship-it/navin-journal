/// Android API-35 emulator tests for isolated A3.3 fictional editor.
///
/// These exercise real Flutter widgets, Flutter→Android Keystore unwrap and
/// SQLite3MultipleCiphers storage work in a background isolate. They do NOT
/// test device force-stop, reboot/reinstall, physical IME, or backup/restore.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:navin_journal_autosave_spike/draft_autosave.dart';
import 'package:navin_journal_bridge_probe/autosave_probe.dart';

Future<void> _ready(
  WidgetTester tester,
  GlobalKey<FictionalAutosavePageState> key,
) async {
  final result = await tester.runAsync(() async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (key.currentState?.readyForTest == true) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  });
  expect(result, isTrue, reason: 'Fixture should initialize via native Keystore');
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fictional Flutter typing commits to encrypted worker and reopens',
      (tester) async {
    final key = GlobalKey<FictionalAutosavePageState>();
    await tester.pumpWidget(
      MaterialApp(home: FictionalAutosavePage(key: key)),
    );
    await _ready(tester, key);

    const exampleTitle = 'నా రోజు · Demo';
    const exampleBody = 'ఈ రోజు ఒక చిన్న కల. Today is peaceful. 🌿';
    await tester.enterText(
      find.byKey(const ValueKey('fictional-title')),
      exampleTitle,
    );
    await tester.enterText(
      find.byKey(const ValueKey('fictional-body')),
      exampleBody,
    );
    expect(key.currentState!.saveIndicatorForTest!.hasUnsavedChanges, isTrue);

    await tester.runAsync(key.currentState!.forceSaveForTest);
    await tester.pump();
    expect(key.currentState!.saveIndicatorForTest!.phase, SavePhase.saved);
    final saved = await tester.runAsync(key.currentState!.readPersistedForTest);
    expect(saved?.content.title, exampleTitle);
    expect(saved?.content.body, exampleBody);
    expect(saved?.version, 1);

    final reopened = await tester.runAsync(key.currentState!.verifyReopenForTest);
    await tester.pump();
    expect(reopened, isTrue);
    expect(key.currentState!.saveIndicatorForTest?.phase, SavePhase.saved);
    expect(find.byKey(const ValueKey('save-status')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('fictional-body')),
      exampleBody + ' Second revision.',
    );
    await tester.runAsync(key.currentState!.forceSaveForTest);
    final next = await tester.runAsync(key.currentState!.readPersistedForTest);
    expect(next?.version, 2);
    expect(next?.content.body, contains('Second revision.'));
    expect(await tester.runAsync(key.currentState!.verifyReopenForTest), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inactive lifecycle requests flush; only committed text is saved',
      (tester) async {
    final key = GlobalKey<FictionalAutosavePageState>();
    await tester.pumpWidget(MaterialApp(home: FictionalAutosavePage(key: key)));
    await _ready(tester, key);

    await tester.enterText(
      find.byKey(const ValueKey('fictional-body')),
      'A pretend note before backgrounding. 🪷',
    );
    expect(key.currentState!.saveIndicatorForTest!.phase, SavePhase.dirty);
    final count = key.currentState!.backgroundFlushesForTest;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(key.currentState!.backgroundFlushesForTest, greaterThan(count));

    final committed = await tester.runAsync(() async {
      for (var i = 0; i < 100; i++) {
        final saved = await key.currentState!.readPersistedForTest();
        if (saved != null && saved.version == 1) return saved;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return null;
    });
    expect(committed?.content.body,
        'A pretend note before backgrounding. 🪷');
    await tester.pump();
    expect(key.currentState!.saveIndicatorForTest!.phase, SavePhase.saved);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
