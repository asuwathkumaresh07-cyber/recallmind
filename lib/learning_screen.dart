import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'import_service.dart';
import 'learning_models.dart';
import 'learning_service.dart';
import 'state.dart';

const _green = Color(0xFF287858), _muted = Color(0xFF7A827C);

class LearningWorkspace extends ConsumerStatefulWidget {
  const LearningWorkspace({
    super.key,
    required this.onSettings,
    required this.onPractice,
  });
  final VoidCallback onSettings;
  final ValueChanged<List<StudyCard>> onPractice;
  @override
  ConsumerState<LearningWorkspace> createState() => _LearningWorkspaceState();
}

class _LearningWorkspaceState extends ConsumerState<LearningWorkspace> {
  final source = TextEditingController(),
      instructions = TextEditingController(),
      title = TextEditingController();
  LearningSet? active;
  String tab = 'Plan';
  String? error;
  bool busy = false, importing = false, editing = true;
  @override
  void dispose() {
    source.dispose();
    instructions.dispose();
    title.dispose();
    super.dispose();
  }

  Future<void> importFile() async {
    setState(() {
      importing = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'docx'],
      );
      if (file == null) return;
      if ((await file.length() ?? 0) > 5 * 1024 * 1024) {
        throw const FormatException('Choose a file smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final text = extractDocument(file.name, bytes);
      if (!mounted) return;
      setState(() {
        source.text = text;
        title.text = file.name;
      });
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> generate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final request = LearningRequest.parse(instructions.text);
      final result = await LearningService(ref.read(aiProvider)).generate(
        title.text.trim().isEmpty ? 'My study notes' : title.text.trim(),
        source.text,
        request,
      );
      await ref.read(databaseProvider).saveLearningSet(result, addCards: true);
      ref.invalidate(learningSetsProvider);
      ref.invalidate(studyProvider);
      if (!mounted) return;
      setState(() {
        active = result;
        editing = false;
        tab = result.items('plan').isNotEmpty
            ? 'Plan'
            : result.items('summary').isNotEmpty
            ? 'Summary'
            : result.items('quiz').isNotEmpty
            ? 'Quiz'
            : 'Flashcards';
      });
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleDay(int day, bool done) async {
    final set = active!;
    setState(() {
      if (done) {
        set.completedDays.add(day);
      } else {
        set.completedDays.remove(day);
      }
    });
    try {
      await ref.read(databaseProvider).saveLearningSet(set);
      ref.invalidate(learningSetsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (done) {
          set.completedDays.remove(day);
        } else {
          set.completedDays.add(day);
        }
        error = _message(e);
      });
    }
  }

  Future<void> takeQuiz() async {
    final set = active!;
    final answers = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => MaterialQuiz(set: set)),
    );
    if (answers == null || !mounted) return;
    set.attempts.add(answers);
    try {
      await ref.read(databaseProvider).saveLearningSet(set);
      ref.invalidate(learningSetsProvider);
      if (mounted) setState(() {});
    } catch (e) {
      set.attempts.removeLast();
      if (mounted) setState(() => error = _message(e));
    }
  }

  void showSource(int number) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Source passage $number'),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: SelectableText(active!.passage(number)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget panel(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE6EAE3)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
  Widget citation(int number) => TextButton.icon(
    onPressed: () => showSource(number),
    icon: const Icon(Icons.format_quote, size: 15),
    label: Text('Source $number'),
  );

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(learningSetsProvider);
    final ai = ref.watch(aiProvider);
    final request = LearningRequest.parse(instructions.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 12,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your material. Your study plan.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bring your notes and tell RecallMind what you need.',
                  style: TextStyle(color: _muted),
                ),
              ],
            ),
            if (!editing)
              FilledButton.icon(
                onPressed: () => setState(() {
                  active = null;
                  editing = true;
                  source.clear();
                  instructions.clear();
                  title.clear();
                  error = null;
                }),
                icon: const Icon(Icons.add),
                label: const Text('New study set'),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (error != null)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not complete that action',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9B3E32),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(error!),
              ],
            ),
          ),
        if (editing) ...[
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1  Add your study material',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy || importing ? null : importFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    importing ? 'Reading document…' : 'Upload a document',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TXT, Markdown, or Word (.docx) · up to 5 MB\nOr paste your notes below. PDF and image imports are not supported yet.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: title,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Study set name',
                    hintText: 'e.g. Biology — chapter 3',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('source-input'),
                  controller: source,
                  enabled: !busy,
                  minLines: 7,
                  maxLines: 14,
                  maxLength: maxSourceCharacters,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Paste your notes',
                    alignLabelWithHint: true,
                    hintText:
                        'Paste lecture notes, textbook sections, or your own explanations…',
                  ),
                ),
                Text(
                  '${source.text.trim().isEmpty ? 0 : source.text.trim().split(RegExp(r'\s+')).length} words · stored on this device',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2  Tell me what to create',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('instructions-input'),
                  controller: instructions,
                  enabled: !busy,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Your instructions',
                    alignLabelWithHint: true,
                    hintText:
                        'Create a 5-day study plan, 10 quiz questions, 12 flashcards, and a summary. I have 30 minutes each day.',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final output in request.outputs)
                      Chip(
                        label: Text(
                          {
                            'plan': '${request.days}-day plan',
                            'quiz': '${request.quizCount} quiz questions',
                            'cards': '${request.cardCount} flashcards',
                            'summary': 'Summary',
                          }[output]!,
                        ),
                      ),
                    if (request.outputs.contains('plan'))
                      Chip(label: Text('${request.minutes} min/day')),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F5EF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ai.isLive
                            ? 'AI generation connected · ${ai.provider}'
                            : 'Source extraction · no API key needed',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ai.isLive
                            ? 'Your instructions and notes will be sent to ${ai.provider} to create the study set.'
                            : 'Creates a reading plan, source excerpts, fill-in-the-blank quizzes, and flashcards. Connect AI to follow custom difficulty, language, exam style, and other open-ended requests.',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                      TextButton(
                        onPressed: busy ? null : widget.onSettings,
                        child: Text(
                          ai.isLive
                              ? 'AI settings'
                              : 'Connect AI for custom instructions',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('generate-study-set'),
                  onPressed: busy || importing ? null : generate,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    busy
                        ? 'Creating from your material…'
                        : 'Generate my study set',
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!editing && active != null) ...[
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${active!.sourceName} · ${active!.method}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your request: ${active!.request.instructions}',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        source.text = active!.sourceText;
                        instructions.text = active!.request.instructions;
                        title.text = active!.sourceName;
                        editing = true;
                        error = null;
                      }),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Change instructions'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final text = _export(active!);
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Study guide copied.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy study guide'),
                    ),
                  ],
                ),
                if ((active!.generated['warnings'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in active!.generated['warnings'])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              w,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                                height: 1.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in [
                'Plan',
                'Summary',
                'Quiz',
                'Flashcards',
                'More',
                'Source',
              ])
                ChoiceChip(
                  label: Text(name),
                  selected: tab == name,
                  onSelected: (_) => setState(() => tab = name),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ...results(),
        ],
        const SizedBox(height: 22),
        const Text(
          'Your saved study sets',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        saved.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => TextButton(
            onPressed: () => ref.invalidate(learningSetsProvider),
            child: const Text('Could not load saved sets. Retry'),
          ),
          data: (sets) => Column(
            children: [
              if (sets.isEmpty)
                panel(
                  const Text(
                    'Your library starts with your material. Add notes above to create your first study set.',
                    style: TextStyle(color: _muted, height: 1.7),
                  ),
                ),
              for (final set in sets)
                panel(
                  Row(
                    children: [
                      const Icon(Icons.description_outlined, color: _green),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InkWell(
                          onTap: busy
                              ? null
                              : () => setState(() {
                                  active = set;
                                  editing = false;
                                  tab = 'Plan';
                                  error = null;
                                }),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                set.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${set.items('quiz').length} questions · ${set.items('cards').length} cards · ${set.completedDays.length}/${set.items('plan').length} sessions done',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open study set',
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                active = set;
                                editing = false;
                                tab = 'Plan';
                                error = null;
                              }),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      IconButton(
                        tooltip: 'Delete study set',
                        onPressed: busy ? null : () => deleteSet(set),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> results() {
    final set = active!;
    if (tab == 'Plan') {
      final plan = set.items('plan');
      if (plan.isEmpty) {
        return [
          panel(
            const Text(
              'No study plan was requested. Use Change instructions to generate one.',
            ),
          ),
        ];
      }
      return [
        Text(
          '${set.completedDays.length} of ${plan.length} sessions completed',
          style: const TextStyle(color: _muted),
        ),
        const SizedBox(height: 12),
        for (final p in plan)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: set.completedDays.contains(p['day']),
                  onChanged: (v) => toggleDay(p['day'], v ?? false),
                  title: Text(
                    'Day ${p['day']} · ${p['title']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${p['minutes']} minutes · ${_date(set.created.add(Duration(days: (p['day'] as int) - 1)))}',
                  ),
                ),
                for (final task in p['tasks'])
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 10),
                    child: Text('• $task', style: const TextStyle(height: 1.6)),
                  ),
                Wrap(
                  children: [
                    for (final number in p['sources']) citation(number),
                  ],
                ),
              ],
            ),
          ),
      ];
    }
    if (tab == 'Summary' || tab == 'More') {
      final items = set.items(tab == 'More' ? 'extras' : 'summary');
      return [
        if (items.isEmpty)
          panel(
            Text(
              tab == 'More'
                  ? 'Additional requested study aids appear here when generated with AI.'
                  : 'No summary was requested. Change your instructions to add one.',
            ),
          ),
        for (final item in items)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  item['text'],
                  style: const TextStyle(height: 1.7),
                ),
                citation(item['source']),
              ],
            ),
          ),
      ];
    }
    if (tab == 'Quiz') {
      final quiz = set.items('quiz');
      return [
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${quiz.length} questions from your notes',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Take the quiz, check explanations, and open the supporting source passages.',
                style: TextStyle(color: _muted, height: 1.6),
              ),
              const SizedBox(height: 18),
              if (quiz.isNotEmpty)
                FilledButton.icon(
                  onPressed: takeQuiz,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Start quiz'),
                )
              else
                const Text(
                  'No quiz available. Change your instructions or add more source material.',
                ),
              if (set.attempts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Best score: ${set.bestScore}% · ${set.attempts.length} attempts',
                ),
                for (final attempt in set.attempts.reversed.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${attempt['correct']}/${attempt['total']} correct · ${_date(DateTime.parse(attempt['at']))}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ];
    }
    if (tab == 'Flashcards') {
      final cards = set.items('cards');
      return [
        if (cards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: FilledButton.icon(
              onPressed: () => widget.onPractice([
                for (var i = 0; i < cards.length; i++)
                  StudyCard(
                    id: '${set.id}-$i',
                    deck: set.title,
                    concept: cards[i]['concept'],
                    question: cards[i]['question'],
                    answer: cards[i]['answer'],
                    prerequisites: List<String>.from(cards[i]['prerequisites']),
                  ),
              ]),
              icon: const Icon(Icons.style_outlined),
              label: const Text('Practice generated flashcards'),
            ),
          ),
        if (cards.isEmpty) panel(const Text('No flashcards were requested.')),
        for (final c in cards)
          panel(
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                c['concept'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(c['question']),
              ),
              children: [
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    c['answer'],
                    style: const TextStyle(height: 1.7),
                  ),
                ),
                citation(c['source']),
              ],
            ),
          ),
      ];
    }
    return [
      for (final p in set.passages)
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Passage ${p.number}',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(p.text, style: const TextStyle(height: 1.7)),
            ],
          ),
        ),
    ];
  }

  Future<void> deleteSet(LearningSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this study set?'),
        content: Text(
          'This removes “${set.title}”, its source, plan, quiz attempts, and generated cards from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(databaseProvider).deleteLearningSet(set.id);
      ref.invalidate(learningSetsProvider);
      ref.invalidate(studyProvider);
      if (mounted) {
        setState(() {
          if (active?.id == set.id) {
            active = null;
            editing = true;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = _message(e));
    }
  }
}

class MaterialQuiz extends StatefulWidget {
  const MaterialQuiz({super.key, required this.set});
  final LearningSet set;
  @override
  State<MaterialQuiz> createState() => _MaterialQuizState();
}

class _MaterialQuizState extends State<MaterialQuiz> {
  final answers = <int, int>{};
  bool submitted = false;
  @override
  Widget build(BuildContext context) {
    final questions = widget.set.items('quiz');
    final correct = [
      for (var i = 0; i < questions.length; i++)
        if (answers[i] == questions[i]['correct']) i,
    ].length;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz from your material')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: !submitted && answers.length != questions.length
                ? null
                : () {
                    if (!submitted) {
                      setState(() => submitted = true);
                    } else {
                      Navigator.pop(context, {
                        'correct': correct,
                        'total': questions.length,
                        'score': (correct / questions.length * 100).round(),
                        'at': DateTime.now().toIso8601String(),
                        'answers': [
                          for (var i = 0; i < questions.length; i++) answers[i],
                        ],
                      });
                    }
                  },
            child: Text(submitted ? 'Save result and return' : 'Submit quiz'),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                widget.set.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                submitted
                    ? '$correct/${questions.length} correct · ${(correct / questions.length * 100).round()}%'
                    : '${answers.length}/${questions.length} answered',
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < questions.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ${questions[i]['question']}',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var j = 0; j < 4; j++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Semantics(
                              selected: answers[i] == j,
                              button: true,
                              child: InkWell(
                                key: ValueKey('answer-$i-$j'),
                                onTap: submitted
                                    ? null
                                    : () => setState(() => answers[i] = j),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        submitted &&
                                            questions[i]['correct'] == j
                                        ? const Color(0xFFDDF2E5)
                                        : answers[i] == j
                                        ? const Color(0xFFE9EFE8)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: answers[i] == j
                                          ? _green
                                          : const Color(0xFFE0E5DE),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${String.fromCharCode(65 + j)}. ${questions[i]['options'][j]}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (submitted) ...[
                          const SizedBox(height: 12),
                          Text(
                            answers[i] == questions[i]['correct']
                                ? 'Correct'
                                : 'Review this answer',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            questions[i]['explanation'],
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          ExpansionTile(
                            title: Text(
                              'Source passage ${questions[i]['source']}',
                            ),
                            children: [
                              SelectableText(
                                widget.set.passage(questions[i]['source']),
                                style: const TextStyle(height: 1.6),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

String _message(Object e) =>
    e.toString().replaceFirst(RegExp(r'^(FormatException|Exception):\s*'), '');
String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
String _export(LearningSet set) {
  final b = StringBuffer('# ${set.title}\n\n${set.request.instructions}\n\n');
  for (final key in ['summary', 'plan', 'quiz', 'cards', 'extras']) {
    if (set.items(key).isEmpty) continue;
    b.writeln('## ${key.toUpperCase()}\n');
    for (final item in set.items(key)) {
      if (key == 'plan') {
        b.writeln(
          'Day ${item['day']}: ${item['title']} (${item['minutes']} min)\n${(item['tasks'] as List).map((t) => '- $t').join('\n')}\n',
        );
      } else if (key == 'quiz') {
        b.writeln(
          '${item['question']}\n${(item['options'] as List).join(' / ')}\nAnswer: ${item['options'][item['correct']]}\n${item['explanation']} [Source ${item['source']}]\n',
        );
      } else {
        b.writeln(
          '${item['title'] ?? item['concept']}\n${item['text'] ?? '${item['question']}\n${item['answer']}'} [Source ${item['source']}]\n',
        );
      }
    }
  }
  return b.toString();
}
