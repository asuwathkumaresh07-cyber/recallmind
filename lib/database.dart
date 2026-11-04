import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'domain.dart';
import 'learning_models.dart';

// SQL is kept explicit so the persistence layer is easy to follow in interviews.
class StudyDatabase extends GeneratedDatabase {
  StudyDatabase.withExecutor(super.executor);
  StudyDatabase()
    : super(
        driftDatabase(
          name: 'recallmind',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
        ),
      );
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE cards (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE reviews (id INTEGER PRIMARY KEY, card_id TEXT NOT NULL, quality INTEGER NOT NULL, reviewed_at TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE learning_sets (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'CREATE TABLE IF NOT EXISTS learning_sets (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        // Remove only untouched starter cards, preserving reviews and user edits.
        final reviewed = await customSelect(
          'SELECT COUNT(*) AS n FROM reviews',
        ).getSingle();
        if (reviewed.read<int>('n') == 0) {
          for (final seed in seedCards) {
            final rows = await customSelect(
              'SELECT payload FROM cards WHERE id = ?',
              variables: [Variable(seed.id)],
            ).get();
            if (rows.isEmpty) continue;
            final old = StudyCard.fromJson(
              jsonDecode(rows.single.read<String>('payload')),
            );
            if (old.concept == seed.concept &&
                old.deck == seed.deck &&
                old.question == seed.question &&
                old.answer == seed.answer &&
                old.repetitions == 0 &&
                old.lapses == 0 &&
                old.prerequisites.join('|') == seed.prerequisites.join('|')) {
              await customStatement('DELETE FROM cards WHERE id = ?', [old.id]);
            }
          }
        }
      }
    },
  );
  Future<List<StudyCard>> load() async {
    final rows = await customSelect('SELECT payload FROM cards').get();
    return rows
        .map((r) => StudyCard.fromJson(jsonDecode(r.read<String>('payload'))))
        .toList();
  }

  Future<void> save(StudyCard card) => customStatement(
    'INSERT OR REPLACE INTO cards (id, payload) VALUES (?, ?)',
    [card.id, jsonEncode(card.toJson())],
  );
  Future<List<LearningSet>> learningSets() async =>
      (await customSelect(
            'SELECT payload FROM learning_sets ORDER BY id DESC',
          ).get())
          .map(
            (r) => LearningSet.fromJson(jsonDecode(r.read<String>('payload'))),
          )
          .toList();

  Future<void> saveLearningSet(LearningSet set, {bool addCards = false}) =>
      transaction(() async {
        await customStatement(
          'INSERT OR REPLACE INTO learning_sets (id, payload) VALUES (?, ?)',
          [set.id, jsonEncode(set.toJson())],
        );
        if (addCards) {
          final cards = set.items('cards');
          for (var i = 0; i < cards.length; i++) {
            final c = cards[i];
            await save(
              StudyCard(
                id: '${set.id}-$i',
                deck: set.title,
                concept: c['concept'],
                question: c['question'],
                answer: c['answer'],
                prerequisites: List<String>.from(c['prerequisites']),
              ),
            );
          }
        }
      });

  Future<void> deleteLearningSet(String id) => transaction(() async {
    await customStatement('DELETE FROM learning_sets WHERE id = ?', [id]);
    await customStatement('DELETE FROM cards WHERE id LIKE ?', ['$id-%']);
  });
  Future<void> record(
    StudyCard card,
    int quality, {
    StudyCard? repair,
  }) => transaction(() async {
    await save(card);
    if (repair != null) {
      await save(repair);
    }
    await customStatement(
      'INSERT INTO reviews (card_id, quality, reviewed_at) VALUES (?, ?, ?)',
      [card.id, quality, DateTime.now().toIso8601String()],
    );
  });
  Future<List<Map<String, dynamic>>> history() async => (await customSelect(
    'SELECT * FROM reviews ORDER BY reviewed_at',
  ).get()).map((r) => r.data).toList();
}
