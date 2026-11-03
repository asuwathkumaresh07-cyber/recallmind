import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'database.dart';
import 'ai_service.dart';

final aiProvider = Provider((ref) => AiService());
final databaseProvider = Provider((ref) {
  final db = StudyDatabase();
  ref.onDispose(db.close);
  return db;
});
final studyProvider = AsyncNotifierProvider<StudyController, List<StudyCard>>(
  StudyController.new,
);
final historyProvider = FutureProvider((ref) async {
  ref.watch(studyProvider);
  return ref.read(databaseProvider).history();
});

class StudyController extends AsyncNotifier<List<StudyCard>> {
  @override
  Future<List<StudyCard>> build() => ref.read(databaseProvider).load();
  Future<StudyCard> review(
    StudyCard card,
    int quality, {
    StudyCard? repair,
  }) async {
    final next = card.review(quality);
    await ref.read(databaseProvider).record(next, quality, repair: repair);
    state = AsyncData([
      for (final c in state.requireValue)
        if (c.id == card.id) next else c,
      ?repair,
    ]);
    return next;
  }

  Future<void> add(StudyCard card) async {
    await ref.read(databaseProvider).save(card);
    state = AsyncData([...state.requireValue, card]);
  }
}
