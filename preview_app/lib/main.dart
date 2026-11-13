// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings
// Navin Journal · Stage 5 entry visual preview (test-only Android shell).
//
// IMPORTANT: NO local persistence, no real vault, no encryption, no backup,
// no account and no analytics. This app contains fictional sample entries.
// Do not enter private journal writing into this visual-review build.
import 'dart:async';

import 'package:flutter/material.dart';

import 'visuals.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JournalPreviewApp());
}

class PreviewEntry {
  final String title;
  final String journal;
  final String date;
  final String body;
  final int artwork;
  const PreviewEntry(this.title, this.journal, this.date, this.body, this.artwork);
}

const sampleEntries = <PreviewEntry>[
  PreviewEntry(
    'The quiet hour',
    'My Journal',
    '13 NOVEMBER 2026',
    'The evening seemed to move a little slower today.\n\n'
    'I watched the light settle on the windowsill and noticed the small '
    'details I usually rush past. Some days do not need a grand story. '
    'A little quiet can be enough.\n\n'
    'Fictional sample entry for the Navin Journal design preview.',
    0,
  ),
  PreviewEntry(
    'A train window',
    'Places & Moments',
    '08 NOVEMBER 2026',
    'A row of trees passed the window, then an open field, then a soft '
    'orange sky.\n\nFor a moment it felt like the world was holding '
    'a photograph still. This is fictional sample writing.',
    2,
  ),
  PreviewEntry(
    'Small celebrations',
    'My Journal',
    '02 NOVEMBER 2026',
    'A little laughter stayed with me after the day was done. '
    'A borrowed memory, a warm cup of tea, and some kind words.\n\n'
    'Sample content, not a personal journal.',
    1,
  ),
  PreviewEntry(
    'ఒక చిన్న జ్ఞాపకం',
    'Older Pages',
    '21 OCTOBER 2026',
    'ఈ రోజు ఒక చిన్న జ్ఞాపకం. తెలుగు మరియు English text can live '
    'on the same quiet page.\n\nFictional bilingual example.',
    0,
  ),
];

enum PreviewView {
  welcome, setup, today, journals, journalDetail, memories, discover,
  reader, writer, settings, trash, backup,
}

enum MemoryMode { timeline, calendar, gallery }

class JournalPreviewApp extends StatefulWidget {
  const JournalPreviewApp({super.key});

  @override
  State<JournalPreviewApp> createState() => _JournalPreviewAppState();
}

class _JournalPreviewAppState extends State<JournalPreviewApp> {
  PreviewView _view = PreviewView.welcome;
  PreviewView _rootTab = PreviewView.today;
  MemoryMode _memoryMode = MemoryMode.timeline;
  bool _dark = false;
  int _selectedEntry = 0;
  int _selectedJournal = 0;
  int _selectedDay = 13;
  String _search = '';
  final _searchController = TextEditingController();
  final _journalName = TextEditingController(text: 'My Journal');
  final _draftTitle = TextEditingController();
  final _draftBody = TextEditingController();

  JournalColors get c => JournalColors(_dark);
  String get journalTitle => _journalName.text.trim().isEmpty
      ? 'My Journal' : _journalName.text.trim();
  String get activeJournal => [
    journalTitle, 'Places & Moments', 'Older Pages', 'Little Things',
  ][_selectedJournal];

  bool get _onTab => const [
    PreviewView.today, PreviewView.journals, PreviewView.memories, PreviewView.discover,
  ].contains(_view);

  @override
  void dispose() {
    _searchController.dispose();
    _journalName.dispose();
    _draftTitle.dispose();
    _draftBody.dispose();
    super.dispose();
  }

  void _openTab(PreviewView view) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _rootTab = view;
      _view = view;
    });
  }

  void _openReader(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedEntry = index;
      _view = PreviewView.reader;
    });
  }

  void _openWriter() {
    _draftTitle.clear();
    _draftBody.clear();
    setState(() => _view = PreviewView.writer);
  }

  Future<void> _onBack() async {
    if (_view == PreviewView.writer &&
        (_draftTitle.text.trim().isNotEmpty || _draftBody.text.trim().isNotEmpty)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Leave this preview page?'),
          content: const Text(
            'This is only a visual demo. Your typed text is not saved. '
            'Leaving this screen will discard it.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep reviewing')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard demo text')),
          ],
        ),
      );
      if (!mounted || discard != true) return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (_view == PreviewView.setup) {
        _view = PreviewView.welcome;
      } else if (_view == PreviewView.welcome) {
        _view = PreviewView.welcome;
      } else if (_view == PreviewView.journalDetail) {
        _view = PreviewView.journals;
      } else {
        _view = _rootTab;
      }
    });
  }

  void _explain(String title, String explanation) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(explanation),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = c;
    final seed = palette.action;
    final brightness = _dark ? Brightness.dark : Brightness.light;
    return MaterialApp(
      title: 'Navin Journal · Design preview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          primary: seed,
          onPrimary: palette.onAction,
          surface: palette.paper,
          onSurface: palette.ink,
        ),
        scaffoldBackgroundColor: palette.canvas,
        dividerColor: palette.stroke,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: palette.action,
            foregroundColor: palette.onAction,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.action,
            minimumSize: const Size(48, 48),
            side: BorderSide(color: palette.stroke),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: palette.action,
            minimumSize: const Size(48, 48),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.paper,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: palette.stroke),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_onBack());
        },
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final expanded = constraints.maxWidth >= 900;
          return Scaffold(
            bottomNavigationBar: compact && _onTab ? _bottomNav() : null,
            body: SafeArea(
              child: Column(
                children: [
                  _previewRibbon(),
                  Expanded(
                    child: Row(
                      children: [
                        if (!compact && _onTab) _sidebar(expanded),
                        Expanded(
                          child: _view == PreviewView.welcome
                              ? _welcome()
                              : _view == PreviewView.setup
                                  ? _setup()
                                  : _view == PreviewView.writer
                                      ? _writer()
                                      : _pageScaffold(compact),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _previewRibbon() => Container(
    width: double.infinity,
    color: c.action,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Text(
      'DESIGN PREVIEW  ·  FICTIONAL ENTRIES  ·  NO SAVING',
      textAlign: TextAlign.center,
      style: TextStyle(color: c.onAction, fontSize: 10,
          letterSpacing: 1.1, fontWeight: FontWeight.w700),
    ),
  );

  Widget _bottomNav() {
    const tabs = <(PreviewView, String, IconData, IconData)>[
      (PreviewView.today, 'Today', Icons.wb_sunny_outlined, Icons.wb_sunny),
      (PreviewView.journals, 'Journals', Icons.auto_stories_outlined, Icons.auto_stories),
      (PreviewView.memories, 'Memories', Icons.calendar_month_outlined, Icons.calendar_month),
      (PreviewView.discover, 'Discover', Icons.search_outlined, Icons.search),
    ];
    return Container(
      decoration: BoxDecoration(color: c.paper,
          border: Border(top: BorderSide(color: c.stroke))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          for (final tab in tabs)
            Expanded(
              child: Semantics(
                selected: _view == tab.$1,
                button: true,
                child: InkWell(
                  key: ValueKey('nav-' + tab.$2.toLowerCase()),
                  onTap: () => _openTab(tab.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_view == tab.$1 ? tab.$4 : tab.$3,
                        size: 23, color: _view == tab.$1 ? c.action : c.secondary),
                      const SizedBox(height: 3),
                      Text(tab.$2, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: _view == tab.$1
                            ? FontWeight.w700 : FontWeight.w500,
                            color: _view == tab.$1 ? c.action : c.secondary)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sidebar(bool expanded) {
    const tabs = <(PreviewView, String, IconData)>[
      (PreviewView.today, 'Today', Icons.wb_sunny_outlined),
      (PreviewView.journals, 'Journals', Icons.auto_stories_outlined),
      (PreviewView.memories, 'Memories', Icons.calendar_month_outlined),
      (PreviewView.discover, 'Discover', Icons.search_outlined),
    ];
    return Container(
      width: expanded ? 228 : 86,
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
      decoration: BoxDecoration(color: c.paper, border: Border(right: BorderSide(color: c.stroke))),
      child: Column(
        crossAxisAlignment: expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const FoldedPageMark(size: 43),
              if (expanded) ...[
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Navin Journal', style: editorial(c, 20)),
                  Text('DESIGN PREVIEW', style: _eyebrow()),
                ]),
              ],
            ]),
          ),
          for (final tab in tabs)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(
              color: _view == tab.$1 ? c.subtle : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: ValueKey('nav-' + tab.$2.toLowerCase()),
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openTab(tab.$1),
                child: Padding(padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 14 : 12, vertical: 15),
                  child: Row(mainAxisAlignment: expanded
                      ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                    Icon(tab.$3, size: 23,
                        color: _view == tab.$1 ? c.action : c.secondary),
                    if (expanded) ...[
                      const SizedBox(width: 14),
                      Text(tab.$2, style: TextStyle(
                        fontWeight: _view == tab.$1 ? FontWeight.w700 : FontWeight.w500,
                        color: _view == tab.$1 ? c.action : c.ink,
                      )),
                    ],
                  ]),
                ),
              ),
            )),
          const Spacer(),
          IconButton(
            tooltip: 'Settings', onPressed: () => setState(() => _view = PreviewView.settings),
            icon: Icon(Icons.tune_outlined, color: c.secondary),
          ),
        ],
      ),
    );
  }

  Widget _pageScaffold(bool compact) => Column(children: [
    _topBar(compact),
    Expanded(child: SingleChildScrollView(
      key: ValueKey('scroll-' + _view.name),
      padding: EdgeInsets.fromLTRB(compact ? 20 : 36, 12, compact ? 20 : 50, 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: switch (_view) {
            PreviewView.today => _today(),
            PreviewView.journals => _journals(),
            PreviewView.journalDetail => _journalDetail(),
            PreviewView.memories => _memories(),
            PreviewView.discover => _discover(),
            PreviewView.reader => _reader(),
            PreviewView.settings => _settings(),
            PreviewView.trash => _trash(),
            PreviewView.backup => _backup(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    )),
  ]);

  Widget _topBar(bool compact) => Padding(
    padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 32, vertical: 10),
    child: Row(children: [
      if (!_onTab)
        IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back),
            onPressed: () => unawaited(_onBack()))
      else
        const FoldedPageMark(size: 30),
      const SizedBox(width: 10),
      Expanded(child: Text(
        _onTab ? 'Navin Journal' : _view == PreviewView.reader
            ? 'Reading a sample' : _pageName(_view),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: editorial(c, compact ? 20 : 23),
      )),
      IconButton(
        key: const ValueKey('quick-write'),
        tooltip: 'Write an entry (visual preview)',
        icon: const Icon(Icons.edit_outlined),
        color: c.action,
        onPressed: _openWriter,
      ),
      IconButton(
        key: const ValueKey('settings-button'),
        tooltip: 'Settings',
        icon: const Icon(Icons.more_horiz),
        onPressed: () => setState(() => _view = PreviewView.settings),
      ),
    ]),
  );

  String _pageName(PreviewView page) => switch (page) {
    PreviewView.journalDetail => 'Journal',
    PreviewView.reader => 'Reader',
    PreviewView.trash => 'Archive & Trash',
    PreviewView.backup => 'Backups',
    PreviewView.settings => 'Settings',
    _ => 'Journal',
  };

  TextStyle _eyebrow() => TextStyle(
    color: c.secondary, fontSize: 11,
    fontWeight: FontWeight.w800, letterSpacing: 1.5,
  );

  Widget _sectionTitle(String title, {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 27, 0, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: editorial(c, 25))),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action)),
        ]),
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(text.toUpperCase(), style: _eyebrow()),
  );

  Widget _notice(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.subtle, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.stroke),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline, color: c.action, size: 21),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(
        color: c.secondary, height: 1.55, fontSize: 13,
      ))),
    ]),
  );

  Widget _welcome() => SingleChildScrollView(
    child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final artwork = ScenicArt(
        variation: 0,
        height: wide ? 620 : 210,
        radius: BorderRadius.zero,
      );
      final copy = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 54 : 28,
          vertical: wide ? 70 : 36,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FoldedPageMark(size: 58),
              const SizedBox(height: 29),
              _label('Still Pages · Memory Atelier'),
              Text('A private home\nfor your stories.', style: editorial(c, wide ? 52 : 40)),
              const SizedBox(height: 21),
              Text(
                'The smallest moments deserve a beautiful place to live.',
                style: TextStyle(fontFamily: 'serif',
                  fontSize: 19, height: 1.5, color: c.secondary),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                key: const ValueKey('explore-preview'),
                onPressed: () => setState(() => _view = PreviewView.setup),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Explore the preview'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() {
                  _rootTab = PreviewView.today;
                  _view = PreviewView.today;
                }),
                child: const Text('Skip to sample journal'),
              ),
              const SizedBox(height: 22),
              Text(
                'DESIGN REVIEW ONLY · Does not save writing, back up memories or protect private information.',
                style: _eyebrow().copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      );
      return wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: artwork), Expanded(child: copy),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [artwork, copy]);
    }),
  );

  Widget _setup() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 570),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FoldedPageMark(size: 48),
        const SizedBox(height: 30),
        _label('01 / Your first journal'),
        Text('Give your pages\na place to belong.', style: editorial(c, 39)),
        const SizedBox(height: 20),
        Text('This is a visual setup demo. Your journal name is temporary.',
            style: TextStyle(fontSize: 15, height: 1.5, color: c.secondary)),
        const SizedBox(height: 27),
        TextField(
          key: const ValueKey('journal-name-field'),
          controller: _journalName,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Journal name'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          const BookCover(variation: 0, width: 62, height: 82),
          const SizedBox(width: 17),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Warm pine', style: TextStyle(
              color: c.ink, fontWeight: FontWeight.w700)),
            Text('Preview cover · change later',
                style: TextStyle(color: c.secondary, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 24),
        _notice('No account, encryption, biometric lock or storage is being configured in this preview.'),
        const SizedBox(height: 25),
        FilledButton.icon(
          key: const ValueKey('start-preview'),
          onPressed: () => setState(() {
            _rootTab = PreviewView.today;
            _view = PreviewView.today;
          }),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Enter sample journal'),
        ),
      ]),
    )),
  );

  Widget _today() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 15),
      _label('Friday · 13 November 2026'),
      Text('A little space\nfor today.', style: editorial(c, 43)),
      const SizedBox(height: 13),
      Text('Your thoughts, in your own time.',
          style: TextStyle(fontFamily: 'serif', fontSize: 18, color: c.secondary)),
      const SizedBox(height: 26),
      FilledButton.icon(
        key: const ValueKey('write-entry'),
        onPressed: _openWriter,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write an entry'),
      ),
      _sectionTitle('From the pages', action: 'All journals',
          onTap: () => _openTab(PreviewView.journals)),
      for (var i = 0; i < 3; i++)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _entryCard(i)),
      _sectionTitle('A moment to revisit', action: 'Memories',
          onTap: () => _openTab(PreviewView.memories)),
      InkWell(
        key: const ValueKey('throwback-card'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openReader(3),
        child: _surface(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ScenicArt(variation: 1, height: 180),
            const SizedBox(height: 14),
            _label('From an earlier page'),
            Text('ఒక చిన్న జ్ఞాపకం', style: editorial(c, 24)),
            const SizedBox(height: 6),
            Text('An imagined day to remember · 21 October',
                style: TextStyle(color: c.secondary, fontSize: 13)),
          ]),
        ),
      ),
    ],
  );

  Widget _surface({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(color: c.paper,
      border: Border.all(color: c.stroke),
      borderRadius: BorderRadius.circular(19)),
    child: child,
  );

  Widget _entryCard(int index) {
    final entry = sampleEntries[index];
    return Semantics(
      button: true,
      label: 'Open fictional entry: ' + entry.title,
      child: InkWell(
        key: ValueKey('entry-' + index.toString()),
        onTap: () => _openReader(index),
        borderRadius: BorderRadius.circular(18),
        child: _surface(child: Row(children: [
          SizedBox(width: 86, child: ScenicArt(variation: entry.artwork,
            height: 83, radius: BorderRadius.circular(12))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.journal.toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: _eyebrow().copyWith(color: c.action, fontSize: 10)),
            const SizedBox(height: 4),
            Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: editorial(c, 20)),
            const SizedBox(height: 5),
            Text(entry.body.replaceAll('\n', ' '),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.secondary, fontSize: 12, height: 1.5)),
          ])),
          Icon(Icons.chevron_right, color: c.secondary, size: 18),
        ])),
      ),
    );
  }

  Widget _journals() {
    final titles = [journalTitle, 'Places & Moments', 'Older Pages', 'Little Things'];
    final descriptions = [
      'Ordinary days, quietly kept', 'A map of memorable places',
      'Notes from earlier seasons', 'The details worth noticing',
    ];
    final width = MediaQuery.sizeOf(context).width;
    final oneColumn = width < 370;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 15),
      _label('Your private library · sample'),
      Text('Every story has\na home.', style: editorial(c, 41)),
      const SizedBox(height: 16),
      Text('A library of small worlds, one page at a time.',
          style: TextStyle(color: c.secondary, height: 1.5)),
      _sectionTitle('Journals', action: 'New journal', onTap: () => _explain(
        'New journal · preview',
        'Creating a real journal will be available in the functional beta. '
        'This APK displays fictional journal covers only.',
      )),
      LayoutBuilder(builder: (context, constraints) {
        final columns = oneColumn ? 1 : constraints.maxWidth >= 650 ? 3 : 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 227,
          ),
          itemBuilder: (context, i) => InkWell(
            key: ValueKey('journal-' + i.toString()),
            borderRadius: BorderRadius.circular(19),
            onTap: () => setState(() {
              _selectedJournal = i;
              _view = PreviewView.journalDetail;
            }),
            child: _surface(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(variation: i, width: 58, height: 79),
                const Spacer(),
                Text(titles[i], maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: editorial(c, 21)),
                const SizedBox(height: 5),
                Text(descriptions[i], maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.secondary, fontSize: 12)),
                const SizedBox(height: 8),
                Text('SAMPLE JOURNAL', style: _eyebrow().copyWith(fontSize: 9)),
              ],
            )),
          ),
        );
      }),
      const SizedBox(height: 18),
      _notice('All covers, counts and entries in this visual preview are fictional.'),
    ]);
  }

  Widget _journalDetail() {
    final matches = <int>[];
    for (var i = 0; i < sampleEntries.length; i++) {
      if (sampleEntries[i].journal == activeJournal) matches.add(i);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 15),
      _label('Inside this sample journal'),
      Row(children: [
        BookCover(variation: _selectedJournal, width: 65, height: 87),
        const SizedBox(width: 18),
        Expanded(child: Text(activeJournal, style: editorial(c, 34))),
      ]),
      _sectionTitle('Pages'),
      if (matches.isEmpty) _notice(
        'This fictional journal is empty. The functional build will let you create and move entries.'
      ),
      for (final i in matches)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _entryCard(i)),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _explain('Journal settings · preview',
          'Rename, archive, cover changes and Trash will be wired to real encrypted storage in the functional beta.'),
        icon: const Icon(Icons.tune_outlined),
        label: const Text('Journal settings'),
      ),
    ]);
  }

  Widget _memories() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 15),
    _label('A place to return'),
    Text('Moments that\nstay with us.', style: editorial(c, 40)),
    const SizedBox(height: 15),
    Text('Explore a fictional timeline through pages, dates and imagery.',
        style: TextStyle(color: c.secondary, height: 1.5)),
    const SizedBox(height: 18),
    Wrap(spacing: 8, runSpacing: 8, children: [
      _modeChip('Timeline', MemoryMode.timeline),
      _modeChip('Calendar', MemoryMode.calendar),
      _modeChip('Gallery', MemoryMode.gallery),
    ]),
    const SizedBox(height: 15),
    switch (_memoryMode) {
      MemoryMode.timeline => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('November 2026'),
          for (final i in [0, 1, 2])
            Padding(padding: const EdgeInsets.only(bottom: 12), child: _entryCard(i)),
          _sectionTitle('October 2026'),
          _entryCard(3),
        ],
      ),
      MemoryMode.calendar => _calendar(),
      MemoryMode.gallery => _gallery(),
    },
  ]);

  Widget _modeChip(String text, MemoryMode mode) => ChoiceChip(
    key: ValueKey('memory-' + text.toLowerCase()),
    label: Text(text),
    selected: _memoryMode == mode,
    onSelected: (_) => setState(() => _memoryMode = mode),
    selectedColor: c.action,
    labelStyle: TextStyle(color: _memoryMode == mode ? c.onAction : c.ink),
  );

  Widget _calendar() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('November 2026'),
    _surface(child: Column(children: [
      const SizedBox(height: 6),
      Row(children: [
        for (final label in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
          Expanded(child: Center(child: Text(label,
            style: _eyebrow().copyWith(fontSize: 12)))),
      ]),
      const SizedBox(height: 14),
      GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 35,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 5),
        itemBuilder: (context, index) {
          final day = index + 1;
          if (day > 30) return const SizedBox.shrink();
          final hasEntry = [2, 8, 13].contains(day);
          final selected = _selectedDay == day;
          return InkWell(
            key: ValueKey('calendar-day-' + day.toString()),
            onTap: () => setState(() => _selectedDay = day),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? c.action : c.canvas,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(day.toString(), style: TextStyle(fontWeight: selected
                    ? FontWeight.bold : FontWeight.w500,
                    color: selected ? c.onAction : c.ink)),
                if (hasEntry) Container(margin: const EdgeInsets.only(top: 3),
                  width: 4, height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    color: selected ? c.onAction : c.clay)),
              ]),
            ),
          );
        },
      ),
    ])),
    const SizedBox(height: 18),
    _label('Selected · ' + _selectedDay.toString() + ' November'),
    if ([2, 8, 13].contains(_selectedDay))
      _entryCard(_selectedDay == 2 ? 2 : _selectedDay == 8 ? 1 : 0)
    else
      _notice('No fictional sample entries exist for this day.'),
  ]);

  Widget _gallery() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sectionTitle('Gallery · illustrated samples'),
    LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 520 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns, mainAxisSpacing: 12,
          crossAxisSpacing: 12, mainAxisExtent: 232,
        ),
        itemBuilder: (context, index) => InkWell(
          key: ValueKey('gallery-' + index.toString()),
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openReader(index),
          child: _surface(padding: const EdgeInsets.all(9), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScenicArt(variation: sampleEntries[index].artwork, height: 140),
              const SizedBox(height: 9),
              Text(sampleEntries[index].title, maxLines: 2,
                overflow: TextOverflow.ellipsis, style: editorial(c, 17)),
              const Spacer(),
              Text('ILLUSTRATION · SAMPLE', style: _eyebrow().copyWith(fontSize: 9)),
            ],
          )),
        ),
      );
    }),
  ]);

  Widget _discover() {
    final matching = <int>[];
    for (var i = 0; i < sampleEntries.length; i++) {
      final e = sampleEntries[i];
      if ((e.title + ' ' + e.body + ' ' + e.journal)
          .toLowerCase().contains(_search.toLowerCase())) {
        matching.add(i);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 15),
      _label('Find what matters'),
      Text('Return to\na moment.', style: editorial(c, 41)),
      const SizedBox(height: 18),
      TextField(
        key: const ValueKey('search-input'),
        controller: _searchController,
        onChanged: (value) => setState(() => _search = value),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_outlined),
          hintText: 'Search fictional memories',
          suffixIcon: _search.isEmpty ? null : IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              _searchController.clear();
              setState(() => _search = '');
            },
            icon: const Icon(Icons.close)),
        ),
      ),
      const SizedBox(height: 13),
      Text('Search works only on the four sample entries in this preview.',
          style: TextStyle(color: c.secondary, fontSize: 12)),
      _sectionTitle(_search.isEmpty ? 'Suggested pages' : 'Matching pages (' +
          matching.length.toString() + ')'),
      if (matching.isEmpty) _notice('No fictional entry matches that phrase.'),
      for (final i in matching)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _entryCard(i)),
    ]);
  }

  Widget _reader() {
    final entry = sampleEntries[_selectedEntry];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      _notice('This entry is fictional demo content. There is no saved journal or reader database yet.'),
      const SizedBox(height: 23),
      ScenicArt(variation: entry.artwork, height: 206),
      const SizedBox(height: 26),
      _label(entry.date + ' · ' + entry.journal),
      Text(entry.title, style: editorial(c, 40)),
      const SizedBox(height: 24),
      Text(entry.body, style: TextStyle(
        fontFamily: 'serif', color: c.ink, fontSize: 19, height: 1.7)),
      const SizedBox(height: 30),
      Divider(color: c.stroke),
      const SizedBox(height: 17),
      Wrap(spacing: 10, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: _openWriter,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Explore editor'),
        ),
        TextButton(
          onPressed: () => unawaited(_onBack()),
          child: const Text('Back to browsing'),
        ),
      ]),
    ]);
  }

  Widget _writer() => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(15, 9, 16, 7),
      child: Row(children: [
        IconButton(
          key: const ValueKey('close-writer'),
          tooltip: 'Close preview editor',
          onPressed: () => unawaited(_onBack()),
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 7),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(journalTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
          Text('VISUAL PREVIEW · NOT SAVED',
              style: _eyebrow().copyWith(fontSize: 9, color: c.clay)),
        ])),
        IconButton(
          tooltip: 'Attachment unavailable',
          onPressed: () => _explain('Media · not available',
            'Photo and audio attachments will work in the functional encrypted beta.'),
          icon: const Icon(Icons.attach_file),
        ),
      ]),
    ),
    Divider(height: 1, color: c.stroke),
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 705),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _notice('Please use fictional text only. This screen does not autosave, encrypt, or retain anything.'),
          const SizedBox(height: 25),
          _label('13 November 2026 · fictional entry'),
          TextField(
            key: const ValueKey('preview-title'),
            controller: _draftTitle,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: editorial(c, 32),
            decoration: InputDecoration(
              hintText: 'Give this page a title',
              hintStyle: editorial(c, 29).copyWith(
                  color: c.secondary.withValues(alpha: .65)),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            key: const ValueKey('preview-body'),
            controller: _draftBody,
            minLines: 12, maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontFamily: 'serif', fontSize: 19,
                height: 1.68, color: c.ink),
            decoration: InputDecoration(
              hintText: 'What would you like to remember?',
              hintStyle: TextStyle(fontFamily: 'serif', fontSize: 19,
                color: c.secondary.withValues(alpha: .65)),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 9, runSpacing: 9, children: [
            OutlinedButton.icon(
              onPressed: () => _explain('Formatting · preview',
                'Rich writing tools are planned but not functional in this visual-only APK.'),
              icon: const Icon(Icons.format_bold),
              label: const Text('Format'),
            ),
            OutlinedButton.icon(
              onPressed: () => _explain('Add a photo · preview',
                'No permissions or real media are requested by this test build.'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Media'),
            ),
          ]),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('leave-preview-editor'),
            onPressed: () => unawaited(_onBack()),
            icon: const Icon(Icons.close),
            label: const Text('Leave preview (nothing saved)'),
          ),
        ]),
      )),
    )),
  ]);

  Widget _settings() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 14),
    _label('Make this space yours'),
    Text('Settings', style: editorial(c, 40)),
    _sectionTitle('Appearance'),
    _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Color theme', style: TextStyle(color: c.ink,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Still Pages light / Midnight Archive dark',
          style: TextStyle(color: c.secondary, fontSize: 13)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, children: [
        ChoiceChip(
          key: const ValueKey('theme-light'),
          label: const Text('Light'),
          avatar: const Icon(Icons.wb_sunny_outlined, size: 17),
          selected: !_dark,
          onSelected: (_) => setState(() => _dark = false),
        ),
        ChoiceChip(
          key: const ValueKey('theme-dark'),
          label: const Text('Dark'),
          avatar: const Icon(Icons.nightlight_outlined, size: 17),
          selected: _dark,
          onSelected: (_) => setState(() => _dark = true),
        ),
      ]),
    ])),
    _sectionTitle('Privacy and recovery'),
    _settingsRow('App lock & privacy', 'Requires the functional secure-vault build',
      Icons.lock_outline, () => _explain('Privacy controls · preview',
        'No private data should be entered here. This preview has no real encrypted vault or app lock.')),
    _settingsRow('Backup & restore', 'See the planned recovery experience',
      Icons.backup_outlined, () => setState(() => _view = PreviewView.backup)),
    _settingsRow('Archive & Trash', 'Preview recovery language',
      Icons.restore_from_trash_outlined,
      () => setState(() => _view = PreviewView.trash)),
    _sectionTitle('About'),
    _notice('Navin Journal is a provisional project name. Folded Page, the A+C design, and Midnight Archive dark theme are approved visual directions. This APK is for UI review only.'),
  ]);

  Widget _settingsRow(String title, String subtitle, IconData icon, VoidCallback onTap) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: _surface(child: Row(children: [
        Icon(icon, color: c.action),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.ink,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: c.secondary, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right, color: c.secondary),
      ])),
    ));

  Widget _trash() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 15),
    _label('Recovery · concept'),
    Text('Nothing lost,\nwithout a trace.', style: editorial(c, 39)),
    const SizedBox(height: 22),
    _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.delete_outline, size: 31, color: c.action),
      const SizedBox(height: 16),
      Text('Nothing in sample Trash.', style: editorial(c, 25)),
      const SizedBox(height: 8),
      Text('The functional app will keep recoverable entries and journals here, '
        'separate from the archive.', style: TextStyle(color: c.secondary, height: 1.5)),
    ])),
    const SizedBox(height: 14),
    _notice('Deletion, restoration and permanent removal are not active in this preview.'),
  ]);

  Widget _backup() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 15),
    _label('Your memories belong to you'),
    Text('Keep every page\nwithin reach.', style: editorial(c, 39)),
    const SizedBox(height: 23),
    _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.shield_outlined, color: c.action, size: 32),
      const SizedBox(height: 16),
      Text('No backup available in preview.', style: editorial(c, 26)),
      const SizedBox(height: 9),
      Text('The finished app will provide independently recoverable encrypted '
        'archives, explicit verification and clear restore status.',
        style: TextStyle(color: c.secondary, height: 1.55)),
      const SizedBox(height: 17),
      OutlinedButton(
        onPressed: () => _explain('Backup unavailable',
          'The production backup and Android clean-device restore remain under engineering validation. This preview cannot create or recover any archive.'),
        child: const Text('How backup will work'),
      ),
    ])),
    const SizedBox(height: 16),
    _notice('Never rely on this design APK to preserve your writing.'),
  ]);
}
