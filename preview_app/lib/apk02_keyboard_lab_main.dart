// ignore_for_file: deprecated_member_use
// Standalone debug-only physical-device fictional keyboard rehearsal.
// No journal persistence, cloud, personal data, keys or export.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'fictional_keyboard_lab.dart';

void main() {
  if (kReleaseMode) {
    throw StateError('Fictional Keyboard Lab must never run in release');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FictionalKeyboardLabApp());
}
