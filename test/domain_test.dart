import 'package:flutter_test/flutter_test.dart';
import 'package:recallmind/domain.dart';
import 'package:recallmind/ai_service.dart';

void main() {
  test('SM-2 uses first day, sixth day, then previous ease', () {
    final now = DateTime(2026, 11, 3);
    var c = seedCards.first.review(4, now: now);
    expect(c.interval, 1);
    expect(c.due, now.add(const Duration(days: 1)));
    c = c.review(4, now: now);
    expect(c.interval, 6);
    expect(c.review(4, now: now).interval, 15);
  });
  test('Failure resets repetition count and bounds ease', () {
    var c = seedCards.first.review(5).review(5).review(0);
    expect(c.repetitions, 0);
    expect(c.lapses, 1);
    expect(c.interval, 1);
    for (var i = 0; i < 20; i++) {
      c = c.review(0);
    }
    expect(c.ease, 1.3);
    expect(() => c.review(6), throwsArgumentError);
  });
  test('Cards round-trip without losing review evidence', () {
    final card = seedCards.first.review(1);
    expect(StudyCard.fromJson(card.toJson()).toJson(), card.toJson());
  });
  test(
    'Offline diagnosis follows prerequisites and favors weak evidence',
    () async {
      final failed = seedCards.first.review(1).review(1);
      final cards = [...seedCards];
      cards[1] = cards[1].review(0).review(0).review(0);
      final result = await AiService().diagnose(failed, cards);
      expect(result['root'], 'ATP & energy');
      expect(result['question'], cards[1].question);
    },
  );
  test('Offline roleplay never claims mastery', () async {
    final result = await AiService().teach(seedCards.first, [
      {'role': 'user', 'content': 'Oxygen accepts electrons.'},
      {'role': 'user', 'content': 'It maintains the gradient.'},
      {'role': 'user', 'content': 'ATP synthase uses this gradient.'},
    ]);
    expect(result['mastered'], false);
    expect(result['reply'], contains('synthase'));
  });
}
