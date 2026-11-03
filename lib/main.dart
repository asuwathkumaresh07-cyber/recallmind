import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'domain.dart';
import 'state.dart';
import 'study_screen.dart';
import 'knowledge_map.dart';

const ink = Color(0xFF202B28),
    green = Color(0xFF287858),
    paper = Color(0xFFF7F8F5),
    muted = Color(0xFF7A827C),
    line = Color(0xFFE6EAE3);
void main() => runApp(const ProviderScope(child: RecallMindApp()));

class RecallMindApp extends StatelessWidget {
  const RecallMindApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RecallMind',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        surface: Colors.white,
      ),
      fontFamily: 'Recall Sans',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, color: ink),
        bodySmall: TextStyle(color: muted),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
          color: ink,
        ),
      ),
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 21),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});
  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  int page = 0;
  String filter = 'All subjects', query = '';
  final names = [
    'Overview',
    'My decks',
    'Study session',
    'Teach it back',
    'Knowledge map',
    'Insights',
  ];
  final icons = [
    Icons.grid_view_rounded,
    Icons.layers_outlined,
    Icons.style_outlined,
    Icons.forum_outlined,
    Icons.hub_outlined,
    Icons.bar_chart_rounded,
  ];
  void start(List<StudyCard> cards, {bool teach = false}) {
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You’re all caught up. Add a card or explore your decks.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyScreen(cards: cards, teach: teach),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(studyProvider);
    return LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 1000;
        return Scaffold(
          drawer: wide ? null : Drawer(child: sidebar()),
          body: Row(
            children: [
              if (wide) SizedBox(width: 232, child: sidebar()),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 78,
                      padding: EdgeInsets.symmetric(horizontal: wide ? 38 : 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: line)),
                      ),
                      child: Row(
                        children: [
                          if (!wide)
                            Builder(
                              builder: (c) => IconButton(
                                onPressed: () => Scaffold.of(c).openDrawer(),
                                icon: const Icon(Icons.menu),
                              ),
                            ),
                          Text(
                            'Workspace',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 13),
                            child: Text('/', style: TextStyle(color: line)),
                          ),
                          Text(
                            names[page],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          if (bounds.maxWidth > 650)
                            SizedBox(
                              width: 230,
                              child: TextField(
                                onChanged: (v) => setState(() => query = v),
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'Search your knowledge…',
                                  prefixIcon: Icon(Icons.search, size: 18),
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          const SizedBox(width: 20),
                          const CircleAvatar(
                            radius: 17,
                            backgroundColor: Color(0xFFE8EEE4),
                            child: Text(
                              'JD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: data.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not open your study library.',
                                ),
                                const SizedBox(height: 10),
                                Text('$e', textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(studyProvider),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (cards) => SingleChildScrollView(
                          padding: EdgeInsets.all(wide ? 38 : 20),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1300),
                              child: content(cards, bounds.maxWidth),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget sidebar() => LayoutBuilder(
    builder: (_, bounds) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bounds.maxHeight),
        child: IntrinsicHeight(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFCFDFB),
              border: Border(right: BorderSide(color: line)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 29, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 35,
                          height: 35,
                          decoration: BoxDecoration(
                            color: green,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.psychology_outlined,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'RecallMind',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 21,
                              letterSpacing: -.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        'YOUR WORKSPACE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < names.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Material(
                          color: page == i
                              ? const Color(0xFFE9F1E8)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() => page = i);
                              if (Scaffold.maybeOf(context)?.isDrawerOpen ??
                                  false) {
                                Navigator.pop(context);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icons[i],
                                    size: 19,
                                    color: page == i ? green : muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      names[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: page == i
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: page == i ? green : ink,
                                      ),
                                    ),
                                  ),
                                  if (i == 3) ...[
                                    const Text(
                                      'AI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: paper,
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            size: 20,
                            color: green,
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'Understanding > memorizing',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Build knowledge that stays with you.',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => const AboutDialog(
                                applicationName: 'RecallMind',
                                applicationVersion: '1.0.0',
                                children: [
                                  Text(
                                    'RecallMind finds prerequisite gaps and helps you explain concepts clearly. Built with Flutter, Riverpod, Drift, and a hand-coded SM-2 scheduler.',
                                  ),
                                ],
                              ),
                            ),
                            child: const Text(
                              'Meet your study companion',
                              style: TextStyle(
                                fontSize: 10,
                                color: green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 10),
                        leading: const Icon(
                          Icons.settings_outlined,
                          size: 19,
                          color: muted,
                        ),
                        title: const Text(
                          'Settings',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: settings,
                      ),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 12),
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: green, size: 7),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Local-first. Always yours.',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget content(List<StudyCard> cards, double width) {
    final due = cards.where((c) => !c.due.isAfter(DateTime.now())).toList();
    final history = ref.watch(historyProvider).value ?? [];
    final successes = history.where((r) => (r['quality'] as int) >= 3).length;
    final visible = cards
        .where(
          (c) =>
              (filter == 'All subjects' || c.deck == filter) &&
              '${c.concept} ${c.deck}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page == 0 ? 'A little progress, every day.' : names[page],
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    page == 0
                        ? 'Welcome back. Let’s turn what you learn into what you know.'
                        : 'Make connections. Build understanding. Keep growing.',
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
            if (width > 650)
              OutlinedButton.icon(
                onPressed: addCard,
                icon: const Icon(Icons.add, size: 17),
                label: const Text(
                  'Create a card',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              IconButton(
                onPressed: addCard,
                tooltip: 'Create a card',
                icon: const Icon(Icons.add_circle_outline, color: green),
              ),
          ],
        ),
        const SizedBox(height: 30),
        if (page == 0) ...[
          LayoutBuilder(
            builder: (_, b) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                stat(
                  'Cards to review',
                  '${due.length}',
                  'Ready when you are',
                  Icons.style_outlined,
                  b.maxWidth,
                ),
                stat(
                  'Concepts explored',
                  '${cards.map((c) => c.concept).toSet().length}',
                  'Your knowledge is growing',
                  Icons.hub_outlined,
                  b.maxWidth,
                ),
                stat(
                  'Review accuracy',
                  history.isEmpty
                      ? '—'
                      : '${(successes / history.length * 100).round()}%',
                  history.isEmpty
                      ? 'Your first session starts here'
                      : 'Across ${history.length} reviews',
                  Icons.track_changes_outlined,
                  b.maxWidth,
                ),
                stat(
                  'Study streak',
                  '${streak(history)}',
                  'days of showing up',
                  Icons.local_fire_department_outlined,
                  b.maxWidth,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2E8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE6D6)),
            ),
            child: LayoutBuilder(
              builder: (_, b) => Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BadgeLabel(
                            'A GOOD DAY TO GROW',
                            icon: Icons.wb_sunny_outlined,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Don’t just remember it.\nReally understand it.',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(height: 13),
                          const Text(
                            'A focused session, a few stronger connections.\nYour future self will thank you.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF687561),
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 15,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: () => start(due),
                                label: const Text(
                                  'Start studying',
                                  style: TextStyle(fontSize: 12),
                                ),
                                icon: const Icon(Icons.arrow_forward, size: 16),
                              ),
                              Text(
                                '${due.length} cards  ·  ~${(due.length * .75).ceil()} min',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (b.maxWidth > 680)
                    const Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 260,
                        child: CustomPaint(painter: GrowthPainter()),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 27),
          LayoutBuilder(
            builder: (_, b) {
              final left = masteryPanel(cards);
              final right = teachPanel(cards);
              return b.maxWidth > 740
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: left),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: right),
                      ],
                    )
                  : Column(children: [left, const SizedBox(height: 18), right]);
            },
          ),
          const SizedBox(height: 27),
        ],
        if (page == 0 || page == 1) ...[
          Row(
            children: [
              const Text(
                'Your decks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(width: 9),
              BadgeLabel('${cards.map((c) => c.deck).toSet().length}'),
              const Spacer(),
              DropdownButton<String>(
                value: filter,
                underline: const SizedBox(),
                style: const TextStyle(fontSize: 11, color: muted),
                items:
                    [
                          'All subjects',
                          'Biology',
                          'Computer Science',
                          'Mathematics',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) => setState(() => filter = v!),
              ),
            ],
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (_, b) => Wrap(
              spacing: 17,
              runSpacing: 17,
              children: [
                for (final deck in visible.map((c) => c.deck).toSet())
                  SizedBox(
                    width: b.maxWidth > 850
                        ? (b.maxWidth - 34) / 3
                        : b.maxWidth > 540
                        ? (b.maxWidth - 17) / 2
                        : b.maxWidth,
                    child: deckTile(
                      deck,
                      visible.where((c) => c.deck == deck).toList(),
                    ),
                  ),
              ],
            ),
          ),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('No cards match your search.'),
            ),
        ],
        if (page == 2 || page == 3) ...[
          const SizedBox(height: 10),
          page == 3
              ? teachPanel(cards)
              : panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.style_outlined, color: green, size: 35),
                      const SizedBox(height: 18),
                      Text(
                        '${due.length} cards ready for your attention',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Swipe left to revisit. Swipe right when you understand.\nRepeated misses help us find the concept underneath.',
                        style: TextStyle(color: muted, height: 1.8),
                      ),
                      const SizedBox(height: 25),
                      FilledButton(
                        onPressed: () => start(due),
                        child: const Text('Begin review'),
                      ),
                    ],
                  ),
                ),
        ],
        if (page == 4) ...[
          KnowledgeMap(cards: visible, onPractice: (card) => start([card])),
          const SizedBox(height: 28),
          const Text(
            'Concepts and their foundations',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Follow each connection to see what a concept depends on.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          for (final c in visible.where((c) => c.prerequisites.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.concept,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in c.prerequisites)
                          ActionChip(
                            avatar: const Icon(
                              Icons.subdirectory_arrow_right,
                              size: 15,
                              color: green,
                            ),
                            label: Text(p),
                            onPressed: () => start(
                              cards.where((c) => c.concept == p).toList(),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (page == 5) ...[
          masteryPanel(cards),
          const SizedBox(height: 20),
          weakSpotsPanel(cards),
          const SizedBox(height: 20),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review activity',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: List.generate(7, (i) {
                        final date = DateTime.now().subtract(
                          Duration(days: 6 - i),
                        );
                        final count = history
                            .where(
                              (r) => sameDay(
                                DateTime.parse(r['reviewed_at'] as String),
                                date,
                              ),
                            )
                            .length;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: green,
                              width: 25,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Last 7 days · completed reviews',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Small sessions. Deeper understanding. Lasting knowledge.',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget stat(
    String label,
    String value,
    String sub,
    IconData icon,
    double w,
  ) => SizedBox(
    width: w > 800 ? (w - 48) / 4 : (w - 16) / 2,
    child: panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              Icon(icon, size: 18, color: green),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w600,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(fontSize: 10, color: muted)),
        ],
      ),
      padding: 20,
    ),
  );
  Widget weakSpotsPanel(List<StudyCard> cards) {
    final weakest = [...cards]
      ..sort(
        (a, b) => (b.lapses * 3 - b.repetitions).compareTo(
          a.lapses * 3 - a.repetitions,
        ),
      );
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where to focus next',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Concepts with repeated misses rise to the top. Unreviewed concepts need evidence.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (final card in weakest.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.concept,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${card.lapses} misses · ${card.repetitions} successful repetitions',
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => start([card]),
                    child: const Text('Practice'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget masteryPanel(List<StudyCard> cards) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'A clearer picture of your knowledge',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => page = 5),
              icon: const Icon(Icons.north_east, size: 16, color: muted),
            ),
          ],
        ),
        const Text(
          'Find your footing. Then build on it.',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 22),
        for (final deck in ['Biology', 'Computer Science', 'Mathematics']) ...[
          Row(
            children: [
              Icon(deckIcon(deck), size: 16, color: muted),
              const SizedBox(width: 8),
              Text(deck, style: const TextStyle(fontSize: 11)),
              const Spacer(),
              Text(
                '${mastery(cards.where((c) => c.deck == deck).toList())}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mastery(cards.where((c) => c.deck == deck).toList()) / 100,
              minHeight: 6,
              color: green,
              backgroundColor: paper,
            ),
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            const Icon(Icons.info_outline, size: 13, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Mastery grows with successful, spaced reviews.',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget teachPanel(List<StudyCard> cards) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.forum_outlined, color: green, size: 23),
            Spacer(),
            BadgeLabel('LEARN BY TEACHING'),
          ],
        ),
        const SizedBox(height: 21),
        const Text(
          'If you can teach it,\nyou understand it.',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 13),
        const Text(
          'Meet your most curious student. Explain a concept, answer follow-ups, and discover what clicks.',
          style: TextStyle(fontSize: 12, color: muted, height: 1.7),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => start(cards, teach: true),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Try teach-it-back', style: TextStyle(fontSize: 11)),
              SizedBox(width: 14),
              Icon(Icons.arrow_forward, size: 15),
            ],
          ),
        ),
      ],
    ),
    padding: 25,
  );
  Widget deckTile(String deck, List<StudyCard> cards) => InkWell(
    borderRadius: BorderRadius.circular(13),
    onTap: () => start(cards),
    child: panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: paper,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(deckIcon(deck), color: green, size: 21),
              ),
              const Spacer(),
              const Icon(Icons.arrow_outward, size: 15, color: muted),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            deck,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            '${cards.length} cards · ${cards.where((c) => !c.due.isAfter(DateTime.now())).length} due today',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mastery(cards) / 100,
                    minHeight: 4,
                    backgroundColor: paper,
                    color: green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${mastery(cards)}%',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ],
      ),
      padding: 22,
    ),
  );
  void settings() {
    final ai = ref.read(aiProvider);
    final key = TextEditingController(text: ai.key);
    final model = TextEditingController(text: ai.model);
    String provider = ai.provider;
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Your study companion'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Without a key, RecallMind uses an offline practice demo. Live AI is needed to assess teach-it-back mastery.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  items: ['OpenAI', 'Gemini']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (p) => update(() {
                    provider = p!;
                    model.text = p == 'Gemini'
                        ? 'gemini-2.5-flash'
                        : 'gpt-4.1-mini';
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: model,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: key,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API key · held in memory only',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Live mode sends concept and review context to your selected provider. Keys are cleared when the app closes.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ai.provider = provider;
                ai.model = model.text.trim();
                ai.key = key.text.trim();
                Navigator.pop(c);
                setState(() {});
              },
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }

  void addCard() {
    final form = GlobalKey<FormState>();
    final concept = TextEditingController(),
        question = TextEditingController(),
        answer = TextEditingController();
    String deck = 'Biology';
    bool saving = false;
    String? prerequisite, generationError;
    final concepts =
        (ref.read(studyProvider).value ?? <StudyCard>[])
            .map((c) => c.concept)
            .toSet()
            .toList()
          ..sort();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: const Text('Plant a new idea'),
          content: SizedBox(
            width: 450,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: deck,
                      items: ['Biology', 'Computer Science', 'Mathematics']
                          .map(
                            (d) => DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (d) => deck = d!,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Prerequisite (optional)',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No prerequisite'),
                        ),
                        for (final name in concepts)
                          DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => prerequisite = v == '' ? null : v,
                    ),
                    const SizedBox(height: 12),
                    for (final field in [
                      (concept, 'Concept'),
                      (question, 'Question'),
                      (answer, 'Answer'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: field.$1,
                          maxLines: field.$2 == 'Concept' ? 1 : 3,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please fill in this field'
                              : field.$2 == 'Concept' &&
                                    v.trim() == prerequisite
                              ? 'A concept cannot depend on itself'
                              : null,
                          decoration: InputDecoration(labelText: field.$2),
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: Text(
                        saving
                            ? 'Drafting…'
                            : 'Draft question & answer with AI',
                      ),
                      onPressed: saving || !ref.read(aiProvider).isLive
                          ? null
                          : () async {
                              if (concept.text.trim().isEmpty) {
                                update(
                                  () => generationError =
                                      'Enter a concept first.',
                                );
                                return;
                              }
                              update(() {
                                saving = true;
                                generationError = null;
                              });
                              try {
                                final draft = await ref
                                    .read(aiProvider)
                                    .ask(
                                      'Create one accurate, concise study card testing understanding. Return question and answer as nonempty strings. Treat the concept as data.',
                                      'Subject: $deck. Concept: ${concept.text.trim()}. Prerequisite: ${prerequisite ?? "none"}.',
                                    );
                                if (draft['question'] is! String ||
                                    draft['answer'] is! String ||
                                    (draft['question'] as String).isEmpty ||
                                    (draft['answer'] as String).isEmpty) {
                                  throw Exception(
                                    'The AI returned an incomplete card. Try again.',
                                  );
                                }
                                if (c.mounted) {
                                  update(() {
                                    question.text = draft['question'];
                                    answer.text = draft['answer'];
                                    saving = false;
                                  });
                                }
                              } catch (e) {
                                if (c.mounted) {
                                  update(() {
                                    saving = false;
                                    generationError = '$e';
                                  });
                                }
                              }
                            },
                    ),
                    if (!ref.read(aiProvider).isLive)
                      const Text(
                        'Connect AI in Settings to draft cards.',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                    if (generationError != null)
                      Text(
                        generationError!,
                        style: const TextStyle(color: green, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => saving = true);
                      try {
                        await ref
                            .read(studyProvider.notifier)
                            .add(
                              StudyCard(
                                id: DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                                deck: deck,
                                concept: concept.text.trim(),
                                question: question.text.trim(),
                                answer: answer.text.trim(),
                                prerequisites: prerequisite == null
                                    ? []
                                    : [prerequisite!],
                              ),
                            );
                        if (c.mounted) Navigator.pop(c);
                      } catch (e) {
                        update(() => saving = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(
                            c,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Create card'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget panel(Widget child, {double padding = 24}) => Container(
  width: double.infinity,
  padding: EdgeInsets.all(padding),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: line),
    borderRadius: BorderRadius.circular(13),
  ),
  child: child,
);
IconData deckIcon(String d) => d == 'Biology'
    ? Icons.eco_outlined
    : d == 'Mathematics'
    ? Icons.functions
    : Icons.code_rounded;
int mastery(List<StudyCard> cards) => cards.isEmpty
    ? 0
    : (cards
                  .map((c) => (c.repetitions / 5).clamp(0, 1))
                  .reduce((a, b) => a + b) /
              cards.length *
              100)
          .round();
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
int streak(List<Map<String, dynamic>> history) {
  final dates = history
      .map((r) => DateTime.parse(r['reviewed_at'] as String))
      .toList();
  var day = DateTime.now();
  if (!dates.any((d) => sameDay(d, day))) {
    day = day.subtract(const Duration(days: 1));
  }
  int result = 0;
  while (dates.any((d) => sameDay(d, day))) {
    result++;
    day = day.subtract(const Duration(days: 1));
  }
  return result;
}

class BadgeLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  const BadgeLabel(this.text, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9F1E8),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: green),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: .7,
            color: green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class GrowthPainter extends CustomPainter {
  const GrowthPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .48, size.height * .59);
    final ring = Paint()
      ..color = green.withValues(alpha: .09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [60.0, 100.0, 140.0]) {
      canvas.drawCircle(center, r, ring);
    }
    final nodes = [
      Offset(center.dx - 80, center.dy + 45),
      Offset(center.dx + 82, center.dy - 28),
      Offset(center.dx - 48, center.dy - 85),
      Offset(center.dx + 58, center.dy + 77),
    ];
    for (final p in nodes) {
      canvas.drawLine(
        center,
        p,
        Paint()
          ..color = green.withValues(alpha: .22)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(p, 12, Paint()..color = const Color(0xFFDCE8D6));
      canvas.drawCircle(p, 4, Paint()..color = green.withValues(alpha: .65));
    }
    canvas.drawCircle(center, 37, Paint()..color = green);
    final spark = Path()
      ..moveTo(center.dx, center.dy - 20)
      ..lineTo(center.dx + 6, center.dy - 6)
      ..lineTo(center.dx + 20, center.dy)
      ..lineTo(center.dx + 6, center.dy + 6)
      ..lineTo(center.dx, center.dy + 20)
      ..lineTo(center.dx - 6, center.dy + 6)
      ..lineTo(center.dx - 20, center.dy)
      ..lineTo(center.dx - 6, center.dy - 6)
      ..close();
    canvas.drawPath(spark, Paint()..color = Colors.white);
    void label(String text, Offset pos) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontFamily: 'Recall Sans',
            color: green,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rect = Rect.fromLTWH(
        pos.dx - t.width / 2 - 13,
        pos.dy,
        t.width + 26,
        29,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = const Color(0xFFFCFDF9),
      );
      t.paint(canvas, Offset(rect.left + 13, rect.top + 8));
    }

    label('Connect the dots', Offset(center.dx + 55, 35));
    label('Make it click', Offset(center.dx - 85, size.height - 34));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
