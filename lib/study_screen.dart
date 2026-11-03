import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'state.dart';
import 'main.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final List<StudyCard> cards;
  final bool teach;
  const StudyScreen({super.key, required this.cards, this.teach = false});
  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  late List<StudyCard> queue;
  int index = 0, completed = 0;
  bool revealed = false, busy = false, mastered = false;
  bool diagnosisOpen = false;
  String? error;
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <Map<String, String>>[];
  StudyCard get card => queue[index];
  @override
  void initState() {
    super.initState();
    queue = [...widget.cards];
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> grade(int quality) async {
    if (busy || index >= queue.length) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(studyProvider.future);
      final next = card.review(quality);
      if (!mounted) return;
      if (quality < 3 && next.lapses >= 2 && next.prerequisites.isNotEmpty) {
        final diagnosis = await ref
            .read(aiProvider)
            .diagnose(next, ref.read(studyProvider).requireValue);
        final repair = StudyCard(
          id: 'repair-${DateTime.now().microsecondsSinceEpoch}',
          deck: next.deck,
          concept: diagnosis['root'],
          question: diagnosis['question'],
          answer: diagnosis['answer'],
        );
        await ref
            .read(studyProvider.notifier)
            .review(card, quality, repair: repair);
        if (!mounted) return;
        setState(() => diagnosisOpen = true);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text('Let’s strengthen the foundation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BadgeLabel(
                  ref.read(aiProvider).isLive
                      ? 'AI KNOWLEDGE-GAP HYPOTHESIS'
                      : 'OFFLINE PREREQUISITE CHECK',
                ),
                const SizedBox(height: 20),
                Text(diagnosis['reason'], style: const TextStyle(height: 1.7)),
                const SizedBox(height: 15),
                Text(
                  'Next: ${repair.concept}; then retry ${next.concept}',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Rebuild & retry'),
              ),
            ],
          ),
        );
        queue.insert(index + 1, repair);
        queue.insert(index + 2, next);
      } else {
        await ref.read(studyProvider.notifier).review(card, quality);
        if (quality < 3) {
          queue.add(next);
        }
      }
      if (mounted) {
        setState(() {
          index++;
          completed++;
          revealed = false;
          busy = false;
          diagnosisOpen = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
          diagnosisOpen = false;
        });
      }
    }
  }

  Future<void> send() async {
    final value = input.text.trim();
    if (value.isEmpty || busy) return;
    setState(() {
      messages.add({'role': 'user', 'content': value});
      busy = true;
      error = null;
    });
    input.clear();
    try {
      final response = await ref.read(aiProvider).teach(card, messages);
      if (response['reply'] is! String ||
          (response['reply'] as String).trim().isEmpty ||
          response['mastered'] is! bool ||
          response['score'] is! num ||
          !(response['score'] as num).isFinite ||
          (response['score'] as num) < 0 ||
          (response['score'] as num) > 100) {
        throw Exception('Incomplete AI response. Try again.');
      }
      final userTurns = messages.where((m) => m['role'] == 'user').length;
      final passed =
          ref.read(aiProvider).isLive &&
          userTurns >= 3 &&
          response['mastered'] == true &&
          (response['score'] as num) >= 75;
      if (passed && !mastered) {
        await ref.read(studyProvider.future);
        await ref.read(studyProvider.notifier).review(card, 4);
      }
      if (mounted) {
        setState(() {
          messages.add({'role': 'assistant', 'content': response['reply']});
          mastered = passed || mastered;
          busy = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
          input.text = value;
          messages.removeLast();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = index >= queue.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: paper,
        title: Text(
          widget.teach ? 'Teach it back' : 'A moment to learn',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: BadgeLabel(
                ref.read(aiProvider).isLive ? 'LIVE AI' : 'OFFLINE DEMO',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: done
                  ? completion()
                  : widget.teach
                  ? conversation()
                  : review(),
            ),
          ),
        ),
      ),
    );
  }

  Widget review() => SingleChildScrollView(
    child: Column(
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(card.deck, style: const TextStyle(color: muted, fontSize: 12)),
            const Spacer(),
            Text(
              '${index + 1} / ${queue.length}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: index / queue.length,
          backgroundColor: line,
          color: green,
          minHeight: 4,
        ),
        const SizedBox(height: 35),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            if (!revealed || busy) return;
            if ((d.primaryVelocity ?? 0) > 200) {
              grade(4);
            } else if ((d.primaryVelocity ?? 0) < -200) {
              grade(1);
            }
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey('${card.id}-$revealed'),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 330),
              padding: const EdgeInsets.all(34),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: line),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ink.withValues(alpha: .03),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  BadgeLabel(card.concept.toUpperCase()),
                  const SizedBox(height: 35),
                  Text(
                    card.question,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      letterSpacing: -.5,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (revealed) ...[
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      card.answer,
                      style: const TextStyle(
                        fontSize: 16,
                        color: green,
                        height: 1.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else
                    const Text(
                      'Take a breath. Think it through.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (busy && !diagnosisOpen)
          const CircularProgressIndicator()
        else if (busy)
          const SizedBox(height: 40)
        else if (!revealed)
          FilledButton.icon(
            onPressed: () => setState(() => revealed = true),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Reveal explanation'),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => grade(1),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Again'),
              ),
              OutlinedButton(
                onPressed: () => grade(3),
                child: const Text('Hard'),
              ),
              FilledButton.icon(
                onPressed: () => grade(4),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Got it'),
              ),
              OutlinedButton(
                onPressed: () => grade(5),
                child: const Text('Easy'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        const Text(
          'Swipe left to revisit · Swipe right when it clicks',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(error!, style: const TextStyle(color: green)),
          ),
      ],
    ),
  );
  Widget conversation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButton<String>(
        isExpanded: true,
        value: card.id,
        items: queue
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.concept)))
            .toList(),
        onChanged: busy
            ? null
            : (id) => setState(() {
                index = queue.indexWhere((c) => c.id == id);
                messages.clear();
                mastered = false;
                error = null;
              }),
      ),
      const SizedBox(height: 10),
      if (!ref.read(aiProvider).isLive)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Practice demo · Connect AI in Settings for adaptive follow-ups and mastery assessment.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ),
      Expanded(
        child: ListView(
          controller: scroll,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: chatBubble(
                'Hey, I’m your curious study partner. Can you explain ${card.concept} to me as if I’m learning it for the first time?',
                false,
              ),
            ),
            for (final m in messages)
              Align(
                alignment: m['role'] == 'user'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: chatBubble(m['content']!, m['role'] == 'user'),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Thinking of a follow-up…',
                  style: TextStyle(color: muted),
                ),
              ),
            if (mastered)
              const Padding(
                padding: EdgeInsets.all(16),
                child: BadgeLabel('UNDERSTANDING DEMONSTRATED · REVIEW SAVED'),
              ),
          ],
        ),
      ),
      if (error != null)
        Padding(padding: const EdgeInsets.all(10), child: Text(error!)),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: input,
              enabled: !busy,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Explain it in your own words…',
              ),
              onSubmitted: (_) => send(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: busy ? null : send,
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const Text(
        'A good explanation makes room for another question.',
        style: TextStyle(color: muted, fontSize: 10),
      ),
    ],
  );
  Widget chatBubble(String text, bool user) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(20),
    constraints: const BoxConstraints(maxWidth: 580),
    decoration: BoxDecoration(
      color: user ? const Color(0xFFE9F1E8) : Colors.white,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user ? 'YOU' : 'YOUR CURIOUS STUDENT',
          style: const TextStyle(
            fontSize: 9,
            color: green,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(height: 1.7)),
      ],
    ),
  );
  Widget completion() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.check_circle_outline, size: 60, color: green),
      const SizedBox(height: 25),
      const Text(
        'A little stronger than before.',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 15),
      Text(
        '$completed reviews completed. Your next reviews are scheduled.',
        style: const TextStyle(color: muted),
      ),
      const SizedBox(height: 30),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to your workspace'),
      ),
    ],
  );
}
