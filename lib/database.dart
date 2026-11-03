import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'domain.dart';

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
  int get schemaVersion => 1;
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
    },
  );
  Future<List<StudyCard>> load() async {
    final rows = await customSelect('SELECT payload FROM cards').get();
    if (rows.isEmpty) {
      await transaction(() async {
        for (final card in seedCards) {
          await save(card);
        }
      });
      return [...seedCards];
    }
    return rows
        .map((r) => StudyCard.fromJson(jsonDecode(r.read<String>('payload'))))
        .toList();
  }

  Future<void> save(StudyCard card) => customStatement(
    'INSERT OR REPLACE INTO cards (id, payload) VALUES (?, ?)',
    [card.id, jsonEncode(card.toJson())],
  );
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
