// ignore_for_file: deprecated_member_use
// New APK02 installations must offer recovery BEFORE occupying active slot.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navin_journal_preview/apk02_library_main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lifecycle = MethodChannel('navin_journal/test_lifecycle_v1');
  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('nj-new-install-widget-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(lifecycle, (call) async {
        if (call.method == 'getPrivateRoot') return root.path;
        throw PlatformException(code: 'UNEXPECTED_DIAGNOSTIC_CALL');
      });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(lifecycle, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  testWidgets('new installation offers explicit create or recover without '
      'silently creating an active encrypted journal', (tester) async {
    await tester.pumpWidget(const Apk02LibraryDiagnosticApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-run-choice')), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-new-journal')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('fictional-external-import')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('fictional-activation-consent')),
      findsOneWidget);
    expect(Directory('${root.path}/nj_apk02_library_fixture')
      .existsSync(), isFalse);
    expect(File('${root.path}/nj_apk02_library_fixture.activation-reservation')
      .existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('incomplete existing active directory refuses automatic '
      'new vault/reset and does not open setup that could overwrite',
      (tester) async {
    final occupied = Directory('${root.path}/nj_apk02_library_fixture')
      ..createSync();
    final marker = File('${occupied.path}/unknown-stage')
      ..writeAsStringSync('UNKNOWN CURRENT USER STATE');
    await tester.pumpWidget(const Apk02LibraryDiagnosticApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('No data has been reset'), findsOneWidget);
    expect(find.byKey(const ValueKey('first-run-new-journal')), findsNothing);
    expect(marker.readAsStringSync(), 'UNKNOWN CURRENT USER STATE');
    expect(File('${occupied.path}/journal.sqlite3').existsSync(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
