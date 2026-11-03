import 'dart:math';

class StudyCard {
  final String id, deck, concept, question, answer;
  final List<String> prerequisites;
  final int repetitions, interval, lapses;
  final double ease;
  final DateTime due;
  StudyCard({
    required this.id,
    required this.deck,
    required this.concept,
    required this.question,
    required this.answer,
    this.prerequisites = const [],
    this.repetitions = 0,
    this.interval = 0,
    this.lapses = 0,
    this.ease = 2.5,
    DateTime? due,
  }) : due = due ?? DateTime.now();
  StudyCard review(int quality, {DateTime? now}) {
    if (quality < 0 || quality > 5) throw RangeError.range(quality, 0, 5);
    final success = quality >= 3;
    final nextInterval = !success
        ? 1
        : repetitions == 0
        ? 1
        : repetitions == 1
        ? 6
        : max(1, (interval * ease).round());
    return StudyCard(
      id: id,
      deck: deck,
      concept: concept,
      question: question,
      answer: answer,
      prerequisites: prerequisites,
      repetitions: success ? repetitions + 1 : 0,
      interval: nextInterval,
      lapses: lapses + (success ? 0 : 1),
      ease: max(1.3, ease + .1 - (5 - quality) * (.08 + (5 - quality) * .02)),
      due: (now ?? DateTime.now()).add(Duration(days: nextInterval)),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deck': deck,
    'concept': concept,
    'question': question,
    'answer': answer,
    'prerequisites': prerequisites,
    'repetitions': repetitions,
    'interval': interval,
    'lapses': lapses,
    'ease': ease,
    'due': due.toIso8601String(),
  };
  factory StudyCard.fromJson(Map<String, dynamic> j) => StudyCard(
    id: j['id'],
    deck: j['deck'],
    concept: j['concept'],
    question: j['question'],
    answer: j['answer'],
    prerequisites: List<String>.from(j['prerequisites']),
    repetitions: j['repetitions'],
    interval: j['interval'],
    lapses: j['lapses'],
    ease: (j['ease'] as num).toDouble(),
    due: DateTime.parse(j['due']),
  );
}

final seedCards = <StudyCard>[
  StudyCard(
    id: '1',
    deck: 'Biology',
    concept: 'Cellular respiration',
    question: 'Why does a cell need oxygen to produce energy efficiently?',
    answer:
        'Oxygen is the final electron acceptor in the electron transport chain. This maintains the proton gradient that powers ATP synthase.',
    prerequisites: ['ATP & energy', 'Electron transport chain'],
  ),
  StudyCard(
    id: '2',
    deck: 'Biology',
    concept: 'ATP & energy',
    question: 'How does ATP transfer usable energy to a cellular process?',
    answer:
        'ATP hydrolysis can be coupled to an energy-requiring reaction, often by transferring a phosphate group.',
  ),
  StudyCard(
    id: '3',
    deck: 'Biology',
    concept: 'Electron transport chain',
    question: 'What does the electron transport chain create?',
    answer:
        'It uses energy released by electron transfer to pump protons across the inner mitochondrial membrane, creating an electrochemical gradient.',
    prerequisites: ['ATP & energy'],
  ),
  StudyCard(
    id: '4',
    deck: 'Computer Science',
    concept: 'Time complexity',
    question: 'Why is binary search O(log n)?',
    answer:
        'Each comparison halves the remaining search space, so the number of comparisons grows logarithmically.',
    prerequisites: ['Logarithms'],
  ),
  StudyCard(
    id: '5',
    deck: 'Mathematics',
    concept: 'Logarithms',
    question: 'What does log₂(8) = 3 mean?',
    answer:
        'It means 2 raised to the power of 3 equals 8. A logarithm asks which exponent produces a number.',
  ),
  StudyCard(
    id: '6',
    deck: 'Computer Science',
    concept: 'Recursion',
    question: 'Why does a recursive function need a base case?',
    answer:
        'A base case stops recursive calls when the simplest instance is reached, preventing infinite recursion.',
  ),
  StudyCard(
    id: '7',
    deck: 'Mathematics',
    concept: 'Derivatives',
    question: 'What does a derivative tell you at a point?',
    answer:
        'The instantaneous rate of change of a function, represented by the slope of its tangent line.',
  ),
  StudyCard(
    id: '8',
    deck: 'Biology',
    concept: 'Photosynthesis',
    question: 'Where does the oxygen released in photosynthesis come from?',
    answer:
        'It comes from splitting water during the light-dependent reactions, rather than from carbon dioxide.',
  ),
];
