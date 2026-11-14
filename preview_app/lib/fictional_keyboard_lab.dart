// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
/// Disposable Android keyboard and accessibility acceptance lab.
///
/// This screen deliberately has no database, network, analytics, preferences,
/// file writes or autosave. All entered text exists only in TextEditingController
/// memory and is discarded when the process dies or Reset is pressed.
/// Do not enter personal information. The separate encrypted diagnostic still
/// accepts only predefined fictional fixtures.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'visuals.dart';

const fictionalKeyboardTitle = 'నా రోజు — A quiet afternoon';
const fictionalKeyboardBody =
    'ఈ రోజు నిశ్శబ్దంగా గడిచింది. I walked outside and wrote down '
    'one small thought. 🌿 2026.\n\n'
    'నా బాల్యంలోని అందమైన జ్ఞాపకాలు — this is a fictional example.';

enum KeyboardQaCheck {
  teluguComposition,
  cursorAndSelection,
  keyboardAvoidance,
  rotateAndResume,
  largeFont,
  screenReader,
}

const keyboardQaLabels = <KeyboardQaCheck, String>{
  KeyboardQaCheck.teluguComposition: 'Telugu Gboard composition and conjuncts',
  KeyboardQaCheck.cursorAndSelection: 'Mid-paragraph cursor and selection',
  KeyboardQaCheck.keyboardAvoidance: 'Keyboard never hides writing or controls',
  KeyboardQaCheck.rotateAndResume: 'Rotation and background/resume',
  KeyboardQaCheck.largeFont: '200% font scale and reflow',
  KeyboardQaCheck.screenReader: 'TalkBack names and focus order',
};

class FictionalKeyboardLabApp extends StatelessWidget {
  const FictionalKeyboardLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Navin Journal · Keyboard QA (fictional)',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: c.canvas,
        colorScheme: ColorScheme.fromSeed(seedColor: c.action),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.paper,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: c.stroke),
          ),
          contentPadding: const EdgeInsets.all(15),
        ),
      ),
      home: const FictionalKeyboardLab(),
    );
  }
}

class FictionalKeyboardLab extends StatefulWidget {
  const FictionalKeyboardLab({super.key});

  @override
  State<FictionalKeyboardLab> createState() => FictionalKeyboardLabState();
}

class FictionalKeyboardLabState extends State<FictionalKeyboardLab>
    with WidgetsBindingObserver {
  final titleInput = TextEditingController();
  final bodyInput = TextEditingController();
  final titleFocus = FocusNode();
  final bodyFocus = FocusNode();
  final Map<KeyboardQaCheck, bool> _checks = {
    for (final item in KeyboardQaCheck.values) item: false,
  };
  AppLifecycleState _lastLifecycle = AppLifecycleState.resumed;
  bool _composing = false;
  bool _insertedSample = false;

  bool get isComposing => _composing;
  bool get enteredTextIsOnlyInMemory => true;

  @override
  void initState() {
    super.initState();
    titleInput.addListener(_watchText);
    bodyInput.addListener(_watchText);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    titleInput.removeListener(_watchText);
    bodyInput.removeListener(_watchText);
    titleInput.dispose();
    bodyInput.dispose();
    titleFocus.dispose();
    bodyFocus.dispose();
    super.dispose();
  }

  void _watchText() {
    final title = titleInput.value.composing;
    final body = bodyInput.value.composing;
    final next = (title.isValid && !title.isCollapsed) ||
        (body.isValid && !body.isCollapsed);
    if (next != _composing && mounted) {
      setState(() => _composing = next);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() => _lastLifecycle = state);
    // No lifecycle flush is possible: this lab has no persistent draft.
  }

  void _insertFictionalExample() {
    titleFocus.unfocus();
    bodyFocus.unfocus();
    titleInput.text = fictionalKeyboardTitle;
    bodyInput.text = fictionalKeyboardBody;
    setState(() => _insertedSample = true);
  }

  void _reset() {
    titleFocus.unfocus();
    bodyFocus.unfocus();
    titleInput.clear();
    bodyInput.clear();
    setState(() {
      _insertedSample = false;
      _composing = false;
      for (final check in KeyboardQaCheck.values) {
        _checks[check] = false;
      }
    });
  }

  String _sanitizedReport() {
    final report = StringBuffer()
      ..writeln('Navin Journal — fictional keyboard QA')
      ..writeln('NO user-entered text is included.')
      ..writeln('Testing on actual Android hardware: human observation only.');
    for (final check in KeyboardQaCheck.values) {
      report
        ..write(keyboardQaLabels[check])
        ..write(': ')
        ..writeln(_checks[check] == true ? 'USER CHECKED' : 'NOT VERIFIED');
    }
    return report.toString();
  }

  Future<void> _copyChecklist() async {
    await Clipboard.setData(ClipboardData(text: _sanitizedReport()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'Checklist copied without any typed title or body text.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const c = JournalColors(false);
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final checked = _checks.values.where((done) => done).length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: c.canvas,
        titleSpacing: 13,
        title: const Text('Keyboard lab',
          maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: FoldedPageMark(size: 35),
        ),
        actions: [
          IconButton(
            key: const ValueKey('lab-reset-appbar'),
            tooltip: 'Reset temporary text and checklist',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('lab-scroll'),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            width < 450 ? 16 : 28, 8, width < 450 ? 16 : 28, 28),
          children: [
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('lab-no-private-warning'),
                    decoration: BoxDecoration(
                      color: c.action,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'FICTIONAL QA ONLY · NEVER ENTER PRIVATE WRITING\n'
                      'Nothing here is saved. This is not your diary.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.onAction, fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 23),
                  Text('Feel the words, test the keyboard',
                    style: editorial(c, width < 450 ? 27 : 33)),
                  const SizedBox(height: 9),
                  Text(
                    'Use actual Telugu Gboard to type the fictional example. '
                    'Check conjuncts, cursor placement, landscape, '
                    'keyboard overlap and TalkBack. This screen has no '
                    'encrypted journal connection, storage or automatic saving.',
                    style: TextStyle(
                      color: c.secondary, height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: c.paper,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FICTIONAL TEXT TO TYPE',
                            style: TextStyle(
                              color: c.secondary, fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            )),
                          const SizedBox(height: 9),
                          SelectableText(fictionalKeyboardTitle,
                            style: TextStyle(color: c.ink)),
                          const SizedBox(height: 8),
                          SelectableText(fictionalKeyboardBody,
                            style: TextStyle(color: c.ink, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 21),
                  TextField(
                    key: const ValueKey('lab-title'),
                    controller: titleInput,
                    focusNode: titleFocus,
                    maxLines: 1,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Practice title (temporary)',
                      hintText: 'Type the fictional title here',
                    ),
                    onSubmitted: (_) => bodyFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('lab-body'),
                    controller: bodyInput,
                    focusNode: bodyFocus,
                    minLines: 5,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    scrollPadding: const EdgeInsets.only(bottom: 135),
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Practice body (temporary)',
                      hintText: 'Use the Telugu keyboard and edit inside text',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('lab-insert-sample'),
                        onPressed: _insertFictionalExample,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Insert sample'),
                      ),
                      TextButton.icon(
                        key: const ValueKey('lab-reset'),
                        onPressed: _reset,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear test'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _insertedSample
                      ? 'Inserted by the app: NOT a real keyboard test.'
                      : 'Type using the system keyboard. No title or body '
                        'is copied into the QA report.',
                    key: const ValueKey('lab-input-source'),
                    style: TextStyle(color: c.secondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _composing
                        ? 'Keyboard composition is in progress'
                        : 'No active keyboard composing range',
                      key: const ValueKey('lab-composition'),
                      style: TextStyle(
                        color: _composing ? c.clay : c.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last app lifecycle: ' + _lastLifecycle.name +
                    ' · visible keyboard area: ' +
                    (media.viewInsets.bottom > 0 ? 'inset detected' : 'none'),
                    key: const ValueKey('lab-lifecycle'),
                    style: TextStyle(color: c.secondary, fontSize: 12),
                  ),
                  const SizedBox(height: 26),
                  Text('Physical-device checklist',
                    style: editorial(c, 25)),
                  const SizedBox(height: 8),
                  Text(
                    'Mark only what you personally checked. These are '
                    'not automated success claims.',
                    style: TextStyle(color: c.secondary),
                  ),
                  const SizedBox(height: 10),
                  for (final check in KeyboardQaCheck.values)
                    CheckboxListTile(
                      key: ValueKey('lab-check-' + check.name),
                      title: Text(keyboardQaLabels[check]!),
                      value: _checks[check],
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 3),
                      onChanged: (value) => setState(
                        () => _checks[check] = value ?? false),
                    ),
                  const SizedBox(height: 9),
                  Text(
                    'User-marked: ' + checked.toString() + ' / ' +
                        KeyboardQaCheck.values.length.toString(),
                    key: const ValueKey('lab-progress'),
                    style: TextStyle(
                      color: c.secondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('lab-copy-checklist'),
                    onPressed: _copyChecklist,
                    icon: const Icon(Icons.copy_all_outlined),
                    label: const Text('Copy checklist only'),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'The clipboard report contains only your six checkboxes. '
                    'The title, body, lifecycle events and keyboard input '
                    'are never transmitted or persisted by this lab. '
                    'Closing the process discards this session.',
                    style: TextStyle(
                      color: c.secondary, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
