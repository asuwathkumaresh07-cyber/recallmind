import 'dart:math' as math;

const maxSourceCharacters = 60000;

class SourcePassage {
  const SourcePassage(this.number, this.text);
  final int number;
  final String text;
  Map<String, dynamic> toJson() => {'number': number, 'text': text};
}

List<SourcePassage> sourcePassages(String text) {
  final paragraphs = text
      .replaceAll('\r\n', '\n')
      .trim()
      .split(RegExp(r'\n\s*\n'));
  final result = <SourcePassage>[];
  for (final paragraph in paragraphs) {
    // Bound each reference so learners can find the exact supporting passage.
    final lines = paragraph.trim().split(
      RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9])|\n'),
    );
    var buffer = '';
    for (final line in lines) {
      if (buffer.length + line.length > 850 && buffer.isNotEmpty) {
        result.add(SourcePassage(result.length + 1, buffer.trim()));
        buffer = '';
      }
      buffer += '$line ';
    }
    if (buffer.trim().isNotEmpty) {
      result.add(SourcePassage(result.length + 1, buffer.trim()));
    }
  }
  return result;
}

class LearningRequest {
  const LearningRequest({
    required this.instructions,
    required this.days,
    required this.minutes,
    required this.quizCount,
    required this.cardCount,
    required this.outputs,
  });
  final String instructions;
  final int days, minutes, quizCount, cardCount;
  final Set<String> outputs;

  factory LearningRequest.parse(
    String instructions, {
    int days = 7,
    int minutes = 30,
    int quizCount = 10,
    int cardCount = 10,
    Set<String>? outputs,
  }) {
    var normalized = instructions.toLowerCase();
    const numbers = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
      'twenty',
    ];
    for (var i = numbers.length - 1; i >= 1; i--) {
      normalized = normalized.replaceAll(RegExp('\\b${numbers[i]}\\b'), '$i');
    }
    int count(String expression, int fallback, int max) {
      final match = RegExp(expression).firstMatch(normalized);
      return (int.tryParse(match?.group(1) ?? '') ?? fallback).clamp(1, max);
    }

    final requested = <String>{};
    final excluded = <String>{};
    for (final entry in {
      'plan': r'\b(plan|schedule|timetable)\b',
      'quiz': r'\b(quiz|quizzes|questions|mcqs?|test)\b',
      'cards': r'\b(flashcards?|flash cards?|cards)\b',
      'summary': r'\b(summary|summaries|summari[sz]e|notes|key points)\b',
    }.entries) {
      final pattern = entry.value.replaceFirst(r'\b', '');
      final negative = RegExp(
        r"\b(?:no|without|skip|exclude|don't make|do not make|0)\s+(?:any\s+)?" +
            pattern,
      );
      if (negative.hasMatch(normalized)) excluded.add(entry.key);
      if (RegExp(entry.value).hasMatch(normalized.replaceAll(negative, ''))) {
        requested.add(entry.key);
      }
    }
    return LearningRequest(
      instructions: instructions.trim(),
      days: count(r'(\d+)[ -]*days?\b', days, 30),
      minutes: count(r'(\d+)[ -]*(?:minutes?|mins?)\b', minutes, 180),
      quizCount: count(
        r'(\d+)\s*(?:quiz\s*)?(?:questions?|mcqs?|quizzes)\b',
        quizCount,
        40,
      ),
      cardCount: count(r'(\d+)\s*(?:flash\s*cards?|cards)\b', cardCount, 40),
      outputs:
          outputs ??
          (requested.isEmpty ? {'plan', 'quiz', 'cards', 'summary'} : requested)
              .difference(excluded),
    );
  }
  Map<String, dynamic> toJson() => {
    'instructions': instructions,
    'days': days,
    'minutes': minutes,
    'quizCount': quizCount,
    'cardCount': cardCount,
    'outputs': outputs.toList(),
  };
  factory LearningRequest.fromJson(Map<String, dynamic> j) => LearningRequest(
    instructions: j['instructions'],
    days: j['days'],
    minutes: j['minutes'],
    quizCount: j['quizCount'],
    cardCount: j['cardCount'],
    outputs: Set<String>.from(j['outputs']),
  );
}

class LearningSet {
  LearningSet({
    required this.id,
    required this.title,
    required this.sourceName,
    required this.sourceText,
    required this.request,
    required this.method,
    required this.generated,
    DateTime? created,
    Set<int>? completedDays,
    List<Map<String, dynamic>>? attempts,
  }) : created = created ?? DateTime.now(),
       completedDays = completedDays ?? {},
       attempts = attempts ?? [];
  final String id, title, sourceName, sourceText, method;
  final LearningRequest request;
  final Map<String, dynamic> generated;
  final DateTime created;
  final Set<int> completedDays;
  final List<Map<String, dynamic>> attempts;
  List<SourcePassage> get passages => sourcePassages(sourceText);
  List<Map<String, dynamic>> items(String key) =>
      (generated[key] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  String passage(int number) =>
      passages.where((p) => p.number == number).firstOrNull?.text ??
      'Source passage unavailable.';
  int get bestScore =>
      attempts.fold(0, (score, a) => math.max(score, a['score'] as int));
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sourceName': sourceName,
    'sourceText': sourceText,
    'request': request.toJson(),
    'method': method,
    'generated': generated,
    'created': created.toIso8601String(),
    'completedDays': completedDays.toList(),
    'attempts': attempts,
  };
  factory LearningSet.fromJson(Map<String, dynamic> j) => LearningSet(
    id: j['id'],
    title: j['title'],
    sourceName: j['sourceName'],
    sourceText: j['sourceText'],
    request: LearningRequest.fromJson(Map<String, dynamic>.from(j['request'])),
    method: j['method'],
    generated: Map<String, dynamic>.from(j['generated']),
    created: DateTime.parse(j['created']),
    completedDays: Set<int>.from(j['completedDays']),
    attempts: (j['attempts'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
  );
}
