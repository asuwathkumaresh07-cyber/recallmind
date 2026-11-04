import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallmind/database.dart';
import 'package:recallmind/domain.dart';
import 'package:recallmind/main.dart';
import 'package:recallmind/state.dart';
import 'package:recallmind/study_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Recall Sans',
    )..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))).load();
  });
  test(
    'SQLite retains cards, schedule, and review history after reopening',
    () async {
      final dir = await Directory.systemTemp.createTemp('recallmind-test-');
      final file = File('${dir.path}/study.sqlite');
      var db = StudyDatabase.withExecutor(NativeDatabase(file));
      await db.load();
      for (final card in seedCards) {
        await db.save(card);
      }
      final cards = await db.load();
      final reviewed = cards.first.review(4);
      await db.record(reviewed, 4);
      await db.close();
      db = StudyDatabase.withExecutor(NativeDatabase(file));
      expect(
        (await db.load()).firstWhere((c) => c.id == reviewed.id).toJson(),
        reviewed.toJson(),
      );
      expect((await db.history()).single['quality'], 4);
      await db.close();
      await dir.delete(recursive: true);
    },
  );

  testWidgets('Desktop and mobile dashboard fit, including open drawer', (
    tester,
  ) async {
    final db = StudyDatabase.withExecutor(NativeDatabase.memory());
    await db.load();
    addTearDown(db.close);
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const RecallMindApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your material. Your study plan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(390, 667);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Two failed reviews insert a prerequisite before retrying the original',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudyDatabase.withExecutor(NativeDatabase.memory());
      await db.load();
      for (final card in seedCards) {
        await db.save(card);
      }
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Recall Sans'),
            home: StudyScreen(cards: [seedCards.first]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyScreen)),
      );
      await tester.runAsync(() => container.read(studyProvider.future));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Reveal explanation'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Again'));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
      }
      expect(find.text('Rebuild & retry'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Rebuild & retry'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(
        find.text('How does ATP transfer usable energy to a cellular process?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reveal explanation'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Got it'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text(seedCards.first.question), findsOneWidget);
      expect((await db.history()).length, 3);
      expect((await db.load()).length, seedCards.length + 1);
      expect(tester.takeException(), isNull);
    },
  );
}
