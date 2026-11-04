import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallmind/ai_service.dart';
import 'package:recallmind/database.dart';
import 'package:recallmind/domain.dart';
import 'package:recallmind/import_service.dart';
import 'package:recallmind/learning_models.dart';
import 'package:recallmind/learning_screen.dart';
import 'package:recallmind/learning_service.dart';
import 'package:recallmind/state.dart';

const notes =
    '''Photosynthesis converts light energy into chemical energy stored in glucose. Chlorophyll absorbs light in the chloroplasts of plant cells. Water molecules supply the electrons used in light-dependent reactions. Oxygen is released when water molecules are split during these reactions.

The Calvin cycle uses carbon dioxide to build carbohydrate molecules. Stomata allow carbon dioxide to enter through the leaf surface. Guard cells regulate stomatal opening to balance gas exchange and water loss. Glucose can be stored as starch or used in cellular respiration.''';

class FixtureAi extends AiService {
  FixtureAi(this.response) {
    key = 'test-key';
  }
  final Map<String, dynamic> response;
  String? received;
  @override
  Future<Map<String, dynamic>> ask(
    String instructions,
    String input, {
    Duration timeout = const Duration(seconds: 40),
  }) async {
    received = input;
    return response;
  }
}

void main() {
  test(
    'Connected AI receives actual instructions and source; bad output is rejected',
    () async {
      final request = LearningRequest.parse(
        'Make 4 flashcards in simple language',
      );
      final local = await LearningService(
        AiService(),
      ).generate('Biology', notes, request);
      final ai = FixtureAi(jsonDecode(jsonEncode(local.generated)));
      final live = await LearningService(
        ai,
      ).generate('Biology', notes, request);
      expect(ai.received, contains('simple language'));
      expect(ai.received, contains('Photosynthesis converts'));
      expect(live.method, contains('OpenAI'));
      ai.response['cards'][0]['source'] = 999;
      await expectLater(
        LearningService(ai).generate('Biology', notes, request),
        throwsFormatException,
      );
    },
  );
  test('Instructions determine output types, counts, days and time', () {
    final r = LearningRequest.parse(
      'Make a five-day plan, six quiz questions, four flashcards and a summary. 20 minutes daily.',
    );
    expect(r.days, 5);
    expect(r.quizCount, 6);
    expect(r.cardCount, 4);
    expect(r.minutes, 20);
    expect(r.outputs, {'plan', 'quiz', 'cards', 'summary'});
    expect(LearningRequest.parse('Make 4 MCQs, no flashcards').outputs, {
      'quiz',
    });
    expect(LearningRequest.parse('Only make three flashcards').outputs, {
      'cards',
    });
    expect(LearningRequest.parse('Make 999 questions over 999 days').days, 30);
  });

  test(
    'TXT and DOCX imports preserve readable text and reject unsupported formats',
    () {
      expect(
        extractDocument('notes.txt', Uint8List.fromList(utf8.encode(notes))),
        notes,
      );
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes(
            'word/document.xml',
            utf8.encode(
              '<w:document xmlns:w="urn:word"><w:body><w:p><w:r><w:t>Hello </w:t></w:r><w:r><w:t>biology</w:t></w:r></w:p><w:p><w:r><w:t>Next paragraph</w:t></w:r></w:p></w:body></w:document>',
            ),
          ),
        );
      expect(
        extractDocument(
          'notes.docx',
          Uint8List.fromList(ZipEncoder().encode(archive)),
        ),
        'Hello biology\n\nNext paragraph',
      );
      expect(
        () => extractDocument('scan.pdf', Uint8List(5)),
        throwsFormatException,
      );
      expect(
        () => extractDocument('empty.txt', Uint8List(0)),
        throwsFormatException,
      );
      expect(
        () => extractDocument('bad.docx', Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
    },
  );

  test(
    'Generated output is derived from source and honors requested counts',
    () async {
      final request = LearningRequest.parse(
        'Create a 3-day plan, 4 questions, 5 flashcards and a summary. 15 minutes each day.',
      );
      final set = await LearningService(
        AiService(),
      ).generate('Plant biology', notes, request);
      expect(set.items('plan').length, 3);
      expect(set.items('quiz').length, 4);
      expect(set.items('cards').length, 5);
      expect(set.items('plan').every((p) => p['minutes'] == 15), isTrue);
      for (final q in set.items('quiz')) {
        expect(set.passage(q['source']), contains(q['explanation']));
        expect(q['explanation'], contains(q['options'][q['correct']]));
        expect((q['options'] as List).toSet().length, 4);
      }
      expect(
        jsonEncode(set.generated).toLowerCase(),
        isNot(contains('binary search')),
      );
      final only = await LearningService(AiService()).generate(
        'Biology',
        notes,
        LearningRequest.parse('Make only two flashcards'),
      );
      expect(only.items('quiz'), isEmpty);
      expect(only.items('plan'), isEmpty);
      expect(only.items('cards').length, 2);
      final invalid =
          jsonDecode(jsonEncode(set.generated)) as Map<String, dynamic>;
      invalid['quiz'][0]['source'] = 999;
      expect(
        () => validateGenerated(invalid, request, set.passages.length),
        throwsFormatException,
      );
      await expectLater(
        LearningService(AiService()).generate('Empty', 'Too short', request),
        throwsFormatException,
      );
    },
  );

  test(
    'Study sets, generated cards, quiz attempts and plan progress survive reopening',
    () async {
      final dir = await Directory.systemTemp.createTemp('recallmind-learning-');
      final file = File('${dir.path}/study.sqlite');
      var db = StudyDatabase.withExecutor(NativeDatabase(file));
      expect(await db.load(), isEmpty);
      final set = await LearningService(AiService()).generate(
        'My plants',
        notes,
        LearningRequest.parse('3-day plan, 4 questions and 4 flashcards'),
      );
      set.completedDays.add(1);
      set.attempts.add({
        'score': 75,
        'correct': 3,
        'total': 4,
        'at': DateTime.now().toIso8601String(),
        'answers': [0, 1, 2, 3],
      });
      await db.saveLearningSet(set, addCards: true);
      await db.close();
      db = StudyDatabase.withExecutor(NativeDatabase(file));
      final restored = (await db.learningSets()).single;
      expect(restored.completedDays, {1});
      expect(restored.bestScore, 75);
      expect(restored.sourceText, notes);
      expect((await db.load()).length, 4);
      await db.deleteLearningSet(set.id);
      expect(await db.learningSets(), isEmpty);
      expect(await db.load(), isEmpty);
      await db.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'Version 1 migration removes untouched examples and preserves user edits',
    () async {
      final dir = await Directory.systemTemp.createTemp('recallmind-migrate-');
      final file = File('${dir.path}/study.sqlite');
      var db = StudyDatabase.withExecutor(NativeDatabase(file));
      await db.load();
      for (final c in seedCards) {
        await db.save(c);
      }
      await db.save(
        StudyCard(
          id: '2',
          deck: 'My deck',
          concept: 'My own concept',
          question: 'My question',
          answer: 'My answer',
        ),
      );
      await db.customStatement('DROP TABLE learning_sets');
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();
      db = StudyDatabase.withExecutor(NativeDatabase(file));
      expect((await db.load()).single.concept, 'My own concept');
      expect(await db.learningSets(), isEmpty);
      await db.close();
      await dir.delete(recursive: true);
    },
  );

  testWidgets('Paste notes, generate a set, take quiz and save score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = StudyDatabase.withExecutor(NativeDatabase.memory());
    await db.load();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LearningWorkspace(onSettings: () {}, onPractice: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('source-input')), notes);
    await tester.enterText(
      find.byKey(const ValueKey('instructions-input')),
      'Make 4 quiz questions and 3 flashcards.',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('generate-study-set')),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('generate-study-set')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('My study notes'), findsWidgets);
    await tester.ensureVisible(find.text('Start quiz'));
    await tester.tap(find.text('Start quiz'));
    await tester.pumpAndSettle();
    final set = (await db.learningSets()).single;
    final quizScroll = find
        .descendant(
          of: find.byType(MaterialQuiz),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 4; i++) {
      final finder = find.byKey(
        ValueKey('answer-$i-${set.items('quiz')[i]['correct']}'),
      );
      await tester.scrollUntilVisible(finder, 350, scrollable: quizScroll);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Submit quiz'));
    await tester.tap(find.text('Submit quiz'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save result and return'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Save result and return'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect((await db.learningSets()).single.bestScore, 100);
    expect(tester.takeException(), isNull);
  });
}
